import 'package:el_race/ui/presentation/my_notes/theme/notes_theme.dart';
import 'package:flutter/material.dart';

/// Per-character style flags for the notes composer (no visible markdown tags).
class NotesCharStyle {
  const NotesCharStyle({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
    this.highlight = false,
  });

  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;
  final bool highlight;

  NotesCharStyle copyWith({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    bool? highlight,
  }) {
    return NotesCharStyle(
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      strikethrough: strikethrough ?? this.strikethrough,
      highlight: highlight ?? this.highlight,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NotesCharStyle &&
      bold == other.bold &&
      italic == other.italic &&
      underline == other.underline &&
      strikethrough == other.strikethrough &&
      highlight == other.highlight;

  @override
  int get hashCode =>
      Object.hash(bold, italic, underline, strikethrough, highlight);
}

/// TextEditingController that styles selections without inserting raw tags.
class NotesStyledTextController extends TextEditingController {
  NotesStyledTextController({String? text}) : super(text: text ?? '') {
    _lastText = this.text;
    _styles = List<NotesCharStyle>.filled(
      this.text.length,
      const NotesCharStyle(),
      growable: true,
    );
    addListener(_syncStylesToText);
  }

  late List<NotesCharStyle> _styles;
  String _lastText = '';
  bool _syncing = false;
  NotesCharStyle? _typingStyle;

  void _syncStylesToText() {
    if (_syncing) return;
    final next = text;
    if (next == _lastText) return;

    final oldText = _lastText;
    final oldStyles = List<NotesCharStyle>.from(_styles);
    _lastText = next;

    if (next.isEmpty) {
      _styles = <NotesCharStyle>[];
      return;
    }

    var prefix = 0;
    final minLen = oldText.length < next.length ? oldText.length : next.length;
    while (prefix < minLen &&
        oldText.codeUnitAt(prefix) == next.codeUnitAt(prefix)) {
      prefix++;
    }

    var oldSuffix = 0;
    while (oldSuffix < oldText.length - prefix &&
        oldSuffix < next.length - prefix &&
        oldText.codeUnitAt(oldText.length - 1 - oldSuffix) ==
            next.codeUnitAt(next.length - 1 - oldSuffix)) {
      oldSuffix++;
    }

    final newStyles = <NotesCharStyle>[
      ...oldStyles.take(prefix),
    ];

    final inserted = next.length - prefix - oldSuffix;
    final styleForInsert = _typingStyle ??
        (prefix > 0 && prefix <= oldStyles.length
            ? oldStyles[prefix - 1]
            : const NotesCharStyle());
    for (var i = 0; i < inserted; i++) {
      newStyles.add(styleForInsert);
    }
    if (oldSuffix > 0) {
      newStyles.addAll(oldStyles.skip(oldStyles.length - oldSuffix));
    }
    while (newStyles.length < next.length) {
      newStyles.add(const NotesCharStyle());
    }
    if (newStyles.length > next.length) {
      newStyles.removeRange(next.length, newStyles.length);
    }
    _styles = newStyles;
  }

  /// Load stored markdown into plain text + styles (hides markers in editor).
  void loadFromStorage(String raw) {
    final parsed = NotesStyleCodec.decode(raw);
    _syncing = true;
    _styles = parsed.styles;
    _lastText = parsed.text;
    _typingStyle = null;
    value = TextEditingValue(
      text: parsed.text,
      selection: TextSelection.collapsed(offset: parsed.text.length),
    );
    _syncing = false;
  }

  /// Serialize plain text + styles to markdown for Firestore.
  String toStorage() => NotesStyleCodec.encode(text, _styles);

  bool selectionHas({
    bool bold = false,
    bool italic = false,
    bool underline = false,
    bool strikethrough = false,
    bool highlight = false,
  }) {
    final range = _selectionRange();
    if (range == null) {
      final s = _typingStyle ?? _baseTypingStyle();
      if (bold && !s.bold) return false;
      if (italic && !s.italic) return false;
      if (underline && !s.underline) return false;
      if (strikethrough && !s.strikethrough) return false;
      if (highlight && !s.highlight) return false;
      return bold || italic || underline || strikethrough || highlight;
    }
    final (start, end) = range;
    if (start >= end) return false;
    for (var i = start; i < end && i < _styles.length; i++) {
      final s = _styles[i];
      if (bold && !s.bold) return false;
      if (italic && !s.italic) return false;
      if (underline && !s.underline) return false;
      if (strikethrough && !s.strikethrough) return false;
      if (highlight && !s.highlight) return false;
    }
    return true;
  }

  bool get boldActive => selectionHas(bold: true);
  bool get italicActive => selectionHas(italic: true);
  bool get underlineActive => selectionHas(underline: true);
  bool get strikethroughActive => selectionHas(strikethrough: true);
  bool get highlightActive => selectionHas(highlight: true);

  void toggleBold() => _toggle(bold: true);
  void toggleItalic() => _toggle(italic: true);
  void toggleUnderline() => _toggle(underline: true);
  void toggleStrikethrough() => _toggle(strikethrough: true);
  void toggleHighlight() => _toggle(highlight: true);

  (int, int)? _selectionRange() {
    final sel = selection;
    if (!sel.isValid) return null;
    var start = sel.start.clamp(0, text.length);
    var end = sel.end.clamp(0, text.length);
    if (start == end) return null;
    if (start > end) {
      final t = start;
      start = end;
      end = t;
    }
    return (start, end);
  }

  NotesCharStyle _baseTypingStyle() {
    if (_typingStyle != null) return _typingStyle!;
    final sel = selection;
    if (sel.isValid) {
      final at = sel.start.clamp(0, text.length);
      if (at > 0 && at - 1 < _styles.length) return _styles[at - 1];
      if (at < _styles.length) return _styles[at];
    }
    return const NotesCharStyle();
  }

  void _toggle({
    bool bold = false,
    bool italic = false,
    bool underline = false,
    bool strikethrough = false,
    bool highlight = false,
  }) {
    final range = _selectionRange();
    if (range == null) {
      final current = _baseTypingStyle();
      final turnOn = !(bold
          ? current.bold
          : italic
              ? current.italic
              : underline
                  ? current.underline
                  : strikethrough
                      ? current.strikethrough
                      : highlight
                          ? current.highlight
                          : false);
      _typingStyle = NotesCharStyle(
        bold: bold ? turnOn : current.bold,
        italic: italic ? turnOn : current.italic,
        underline: underline ? turnOn : current.underline,
        strikethrough: strikethrough ? turnOn : current.strikethrough,
        highlight: highlight ? turnOn : current.highlight,
      );
      notifyListeners();
      return;
    }
    final (start, end) = range;
    final turnOn = !selectionHas(
      bold: bold,
      italic: italic,
      underline: underline,
      strikethrough: strikethrough,
      highlight: highlight,
    );
    for (var i = start; i < end && i < _styles.length; i++) {
      final s = _styles[i];
      _styles[i] = NotesCharStyle(
        bold: bold ? turnOn : s.bold,
        italic: italic ? turnOn : s.italic,
        underline: underline ? turnOn : s.underline,
        strikethrough: strikethrough ? turnOn : s.strikethrough,
        highlight: highlight ? turnOn : s.highlight,
      );
    }
    _typingStyle = null;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (_styles.length != text.length) {
      _styles = List<NotesCharStyle>.generate(
        text.length,
        (i) => i < _styles.length ? _styles[i] : const NotesCharStyle(),
        growable: true,
      );
    }
    return NotesStyleCodec.buildTextSpan(
      text: text,
      styles: _styles,
      style: style,
    );
  }

  @override
  void dispose() {
    removeListener(_syncStylesToText);
    super.dispose();
  }
}

/// Encode/decode styled plain text ↔ lightweight markdown for storage.
abstract final class NotesStyleCodec {
  static TextSpan buildTextSpan({
    required String text,
    required List<NotesCharStyle> styles,
    TextStyle? style,
  }) {
    final base = style ?? const TextStyle();
    if (text.isEmpty) {
      return TextSpan(style: base, text: text);
    }

    final children = <InlineSpan>[];
    var i = 0;
    while (i < text.length) {
      final start = i;
      final attr = i < styles.length ? styles[i] : const NotesCharStyle();
      i++;
      while (i < text.length && i < styles.length && styles[i] == attr) {
        i++;
      }
      final decorations = <TextDecoration>[];
      if (attr.underline) decorations.add(TextDecoration.underline);
      if (attr.strikethrough) decorations.add(TextDecoration.lineThrough);

      children.add(
        TextSpan(
          text: text.substring(start, i),
          style: base.copyWith(
            fontWeight: attr.bold ? FontWeight.w700 : null,
            fontStyle: attr.italic ? FontStyle.italic : null,
            decoration: decorations.isEmpty
                ? null
                : TextDecoration.combine(decorations),
            decorationColor: NotesTheme.textPrimary,
            backgroundColor: attr.highlight
                ? NotesTheme.bronze.withValues(alpha: 0.35)
                : null,
          ),
        ),
      );
    }
    return TextSpan(style: base, children: children);
  }

  static String encode(String plain, List<NotesCharStyle> styles) {
    if (plain.isEmpty) return '';
    final buf = StringBuffer();
    var i = 0;
    while (i < plain.length) {
      final start = i;
      final attr = i < styles.length ? styles[i] : const NotesCharStyle();
      i++;
      while (i < plain.length && i < styles.length && styles[i] == attr) {
        i++;
      }
      var chunk = plain.substring(start, i);
      if (attr.italic) chunk = '*$chunk*';
      if (attr.bold) chunk = '**$chunk**';
      if (attr.underline) chunk = '<u>$chunk</u>';
      if (attr.strikethrough) chunk = '~~$chunk~~';
      if (attr.highlight) chunk = '==$chunk==';
      buf.write(chunk);
    }
    return buf.toString();
  }

  static ({String text, List<NotesCharStyle> styles}) decode(String raw) {
    if (raw.isEmpty) {
      return (text: '', styles: <NotesCharStyle>[]);
    }

    var text = raw;
    var styles = List<NotesCharStyle>.filled(
      text.length,
      const NotesCharStyle(),
      growable: true,
    );

    final h =
        _unwrap(text, styles, '==', '==', (s) => s.copyWith(highlight: true));
    text = h.text;
    styles = h.styles;

    final s = _unwrap(
        text, styles, '~~', '~~', (s) => s.copyWith(strikethrough: true));
    text = s.text;
    styles = s.styles;

    final u = _unwrap(
        text, styles, '<u>', '</u>', (s) => s.copyWith(underline: true));
    text = u.text;
    styles = u.styles;

    final b =
        _unwrap(text, styles, '**', '**', (s) => s.copyWith(bold: true));
    text = b.text;
    styles = b.styles;

    final it = _unwrapItalic(text, styles);
    text = it.text;
    styles = it.styles;

    return (text: text, styles: styles);
  }

  static ({String text, List<NotesCharStyle> styles}) _unwrap(
    String text,
    List<NotesCharStyle> styles,
    String open,
    String close,
    NotesCharStyle Function(NotesCharStyle) apply,
  ) {
    final outText = StringBuffer();
    final outStyles = <NotesCharStyle>[];
    var i = 0;
    while (i < text.length) {
      if (text.startsWith(open, i)) {
        final contentStart = i + open.length;
        final closeAt = text.indexOf(close, contentStart);
        if (closeAt >= contentStart) {
          final inner = text.substring(contentStart, closeAt);
          for (var c = 0; c < inner.length; c++) {
            final srcIndex = contentStart + c;
            final base = srcIndex < styles.length
                ? styles[srcIndex]
                : const NotesCharStyle();
            outStyles.add(apply(base));
            outText.write(inner[c]);
          }
          i = closeAt + close.length;
          continue;
        }
      }
      final base = i < styles.length ? styles[i] : const NotesCharStyle();
      outStyles.add(base);
      outText.write(text[i]);
      i++;
    }
    return (text: outText.toString(), styles: outStyles);
  }

  static ({String text, List<NotesCharStyle> styles}) _unwrapItalic(
    String text,
    List<NotesCharStyle> styles,
  ) {
    final outText = StringBuffer();
    final outStyles = <NotesCharStyle>[];
    var i = 0;
    while (i < text.length) {
      if (text[i] == '*' && !(i + 1 < text.length && text[i + 1] == '*')) {
        final closeAt = text.indexOf('*', i + 1);
        if (closeAt > i + 1 &&
            !(closeAt + 1 < text.length && text[closeAt + 1] == '*')) {
          final inner = text.substring(i + 1, closeAt);
          for (var c = 0; c < inner.length; c++) {
            final srcIndex = i + 1 + c;
            final base = srcIndex < styles.length
                ? styles[srcIndex]
                : const NotesCharStyle();
            outStyles.add(base.copyWith(italic: true));
            outText.write(inner[c]);
          }
          i = closeAt + 1;
          continue;
        }
      }
      final base = i < styles.length ? styles[i] : const NotesCharStyle();
      outStyles.add(base);
      outText.write(text[i]);
      i++;
    }
    return (text: outText.toString(), styles: outStyles);
  }
}
