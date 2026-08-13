import 'package:flutter/material.dart';

/// Light Markdown helpers for the iPhone-like notes composer.
abstract final class NotesMarkdownFormat {
  /// Wrap the current selection (or insert markers at the cursor).
  static void wrapSelection(
    TextEditingController controller, {
    required String left,
    required String right,
  }) {
    final text = controller.text;
    final sel = controller.selection;
    final start = sel.start.clamp(0, text.length);
    final end = sel.end.clamp(0, text.length);

    if (start == end) {
      final insert = '$left$right';
      final next = text.replaceRange(start, end, insert);
      controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: start + left.length),
      );
      return;
    }

    final selected = text.substring(start, end);
    final wrapped = '$left$selected$right';
    final next = text.replaceRange(start, end, wrapped);
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection(
        baseOffset: start,
        extentOffset: start + wrapped.length,
      ),
    );
  }

  /// Toggle wrap markers around the selection (or unwrap if already wrapped).
  static void toggleWrap(
    TextEditingController controller, {
    required String left,
    required String right,
  }) {
    final text = controller.text;
    final sel = controller.selection;
    final start = sel.start.clamp(0, text.length);
    final end = sel.end.clamp(0, text.length);

    if (start < end) {
      final selected = text.substring(start, end);
      if (selected.startsWith(left) &&
          selected.endsWith(right) &&
          selected.length >= left.length + right.length) {
        final inner = selected.substring(
          left.length,
          selected.length - right.length,
        );
        final next = text.replaceRange(start, end, inner);
        controller.value = TextEditingValue(
          text: next,
          selection: TextSelection(
            baseOffset: start,
            extentOffset: start + inner.length,
          ),
        );
        return;
      }
      // Also unwrap if markers sit just outside the selection.
      if (start >= left.length &&
          end + right.length <= text.length &&
          text.substring(start - left.length, start) == left &&
          text.substring(end, end + right.length) == right) {
        final inner = text.substring(start, end);
        final next = text.replaceRange(
          start - left.length,
          end + right.length,
          inner,
        );
        controller.value = TextEditingValue(
          text: next,
          selection: TextSelection(
            baseOffset: start - left.length,
            extentOffset: start - left.length + inner.length,
          ),
        );
        return;
      }
    }
    wrapSelection(controller, left: left, right: right);
  }

  static void bold(TextEditingController c) =>
      toggleWrap(c, left: '**', right: '**');

  static void italic(TextEditingController c) =>
      toggleWrap(c, left: '*', right: '*');

  static void underline(TextEditingController c) =>
      toggleWrap(c, left: '<u>', right: '</u>');

  static void strikethrough(TextEditingController c) =>
      toggleWrap(c, left: '~~', right: '~~');

  static void highlight(TextEditingController c) =>
      toggleWrap(c, left: '==', right: '==');

  static void insertLink(
    TextEditingController controller, {
    required String label,
    required String url,
  }) {
    final safeLabel = label.trim().isEmpty ? url.trim() : label.trim();
    final safeUrl = url.trim();
    if (safeUrl.isEmpty) return;
    final markdown = '[$safeLabel]($safeUrl)';
    final text = controller.text;
    final sel = controller.selection;
    final start = sel.start.clamp(0, text.length);
    final end = sel.end.clamp(0, text.length);
    final next = text.replaceRange(start, end, markdown);
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + markdown.length),
    );
  }

  /// Prefix the current line with `- ` (bullet list).
  static void bulletList(TextEditingController controller) {
    _prefixCurrentLine(controller, '- ');
  }

  /// Toggle `- ` on the current line (enable / disable bullets).
  static void toggleBullet(TextEditingController controller) {
    final text = controller.text;
    final sel = controller.selection;
    final cursor = sel.baseOffset.clamp(0, text.length);
    final lineStart = text.lastIndexOf('\n', cursor - 1) + 1;
    var lineEnd = text.indexOf('\n', cursor);
    if (lineEnd < 0) lineEnd = text.length;

    final line = text.substring(lineStart, lineEnd);
    if (line.startsWith('- [ ] ') || line.startsWith('- [x] ') || line.startsWith('- [X] ')) {
      // Downgrade checklist to plain text.
      final stripped = line.replaceFirst(RegExp(r'^- \[[ xX]\] '), '');
      final next = text.replaceRange(lineStart, lineEnd, stripped);
      final delta = stripped.length - line.length;
      controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(
          offset: (cursor + delta).clamp(0, next.length),
        ),
      );
      return;
    }
    if (line.startsWith('- ')) {
      final stripped = line.substring(2);
      final next = text.replaceRange(lineStart, lineEnd, stripped);
      final delta = stripped.length - line.length;
      controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(
          offset: (cursor + delta).clamp(0, next.length),
        ),
      );
      return;
    }
    _prefixCurrentLine(controller, '- ');
  }

  /// True when the current line is a bullet (or checklist).
  static bool isBulletLine(TextEditingController controller) {
    final line = currentLine(controller);
    return line.startsWith('- ');
  }

  /// True when selection or surrounding text is highlighted with ==.
  static bool isHighlightActive(TextEditingController controller) {
    final text = controller.text;
    final sel = controller.selection;
    final start = sel.start.clamp(0, text.length);
    final end = sel.end.clamp(0, text.length);
    if (start < end) {
      final selected = text.substring(start, end);
      if (selected.startsWith('==') && selected.endsWith('==')) return true;
      if (start >= 2 &&
          end + 2 <= text.length &&
          text.substring(start - 2, start) == '==' &&
          text.substring(end, end + 2) == '==') {
        return true;
      }
    }
    return false;
  }

  /// Prefix the current line with a checklist item.
  static void checklist(TextEditingController controller) {
    _prefixCurrentLine(controller, '- [ ] ');
  }

  /// Prefix the current line with `1. ` (simple numbered list).
  static void numberedList(TextEditingController controller) {
    final line = currentLine(controller);
    if (RegExp(r'^\d+\.\s').hasMatch(line)) return;
    // Strip bullet first if present.
    if (line.startsWith('- ')) {
      toggleBullet(controller);
    }
    _prefixCurrentLine(controller, '1. ');
  }

  /// Set heading level on the current line: 1=# `# `, 2=`## `, 3=`### `, 0=body.
  static void headingLevel(TextEditingController controller, int level) {
    final text = controller.text;
    final sel = controller.selection;
    final cursor = sel.baseOffset.clamp(0, text.length);
    final lineStart = text.lastIndexOf('\n', cursor - 1) + 1;
    var lineEnd = text.indexOf('\n', cursor);
    if (lineEnd < 0) lineEnd = text.length;

    var line = text.substring(lineStart, lineEnd);
    // Strip existing heading / leading bullets for clean restyle.
    line = line.replaceFirst(RegExp(r'^#{1,6}\s+'), '');

    final prefix = switch (level) {
      1 => '# ',
      2 => '## ',
      3 => '### ',
      _ => '',
    };
    final nextLine = '$prefix$line';
    final next = text.replaceRange(lineStart, lineEnd, nextLine);
    final delta = nextLine.length - (lineEnd - lineStart);
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(
        offset: (cursor + delta).clamp(0, next.length),
      ),
    );
  }

  /// Detect heading level of current line (0 = body).
  static int currentHeadingLevel(TextEditingController controller) {
    final line = currentLine(controller);
    final m = RegExp(r'^(#{1,6})\s+').firstMatch(line);
    if (m == null) return 0;
    return m.group(1)!.length.clamp(1, 3);
  }

  static String currentLine(TextEditingController controller) {
    final text = controller.text;
    final sel = controller.selection;
    final cursor = sel.baseOffset.clamp(0, text.length);
    final lineStart = text.lastIndexOf('\n', cursor - 1) + 1;
    var lineEnd = text.indexOf('\n', cursor);
    if (lineEnd < 0) lineEnd = text.length;
    return text.substring(lineStart, lineEnd);
  }

  static void _prefixCurrentLine(
    TextEditingController controller,
    String prefix,
  ) {
    final text = controller.text;
    final sel = controller.selection;
    final cursor = sel.baseOffset.clamp(0, text.length);
    final lineStart = text.lastIndexOf('\n', cursor - 1) + 1;
    var lineEnd = text.indexOf('\n', cursor);
    if (lineEnd < 0) lineEnd = text.length;

    final line = text.substring(lineStart, lineEnd);
    if (line.startsWith(prefix)) return;

    // Upgrade plain bullet to checklist when requested.
    String cleaned = line;
    if (prefix.startsWith('- [') && cleaned.startsWith('- ')) {
      cleaned = cleaned.substring(2);
    }

    final nextLine = '$prefix$cleaned';
    final next = text.replaceRange(lineStart, lineEnd, nextLine);
    final delta = nextLine.length - line.length;
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(
        offset: (cursor + delta).clamp(0, next.length),
      ),
    );
  }

  /// Toggle `- [ ]` ↔ `- [x]` on a single line. Returns null if not a checklist.
  static String? toggleChecklistLine(String line) {
    final open = RegExp(r'^(\s*-\s\[\s\])(.*)$');
    final done = RegExp(r'^(\s*-\s\[[xX]\])(.*)$');
    if (open.hasMatch(line)) {
      return line.replaceFirstMapped(
        open,
        (m) => '${m[1]!.replaceFirst('[ ]', '[x]')}${m[2]}',
      );
    }
    if (done.hasMatch(line)) {
      return line.replaceFirstMapped(
        done,
        (m) => '${m[1]!.replaceFirst(RegExp(r'\[[xX]\]'), '[ ]')}${m[2]}',
      );
    }
    return null;
  }

  /// Toggle checklist at [lineIndex] inside full [content].
  static String? toggleChecklistAtLine(String content, int lineIndex) {
    final lines = content.split('\n');
    if (lineIndex < 0 || lineIndex >= lines.length) return null;
    final toggled = toggleChecklistLine(lines[lineIndex]);
    if (toggled == null) return null;
    lines[lineIndex] = toggled;
    return lines.join('\n');
  }
}
