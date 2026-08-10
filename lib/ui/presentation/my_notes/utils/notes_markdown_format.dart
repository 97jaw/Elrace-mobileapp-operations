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

  static void bold(TextEditingController c) =>
      wrapSelection(c, left: '**', right: '**');

  static void italic(TextEditingController c) =>
      wrapSelection(c, left: '*', right: '*');

  /// Prefix the current line with `- ` (bullet list).
  static void bulletList(TextEditingController controller) {
    _prefixCurrentLine(controller, '- ');
  }

  /// Prefix the current line with a checklist item.
  static void checklist(TextEditingController controller) {
    _prefixCurrentLine(controller, '- [ ] ');
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
