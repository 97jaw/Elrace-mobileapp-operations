import 'package:el_race/ui/presentation/my_notes/theme/notes_theme.dart';
import 'package:el_race/ui/presentation/my_notes/utils/notes_markdown_format.dart';
import 'package:el_race/ui/presentation/my_notes/utils/notes_styled_text_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Renders note body with tappable checklist lines (`- [ ]` / `- [x]`).
class NotesChecklistContent extends StatelessWidget {
  const NotesChecklistContent({
    super.key,
    required this.content,
    this.readOnly = false,
    this.onContentChanged,
  });

  final String content;
  final bool readOnly;
  final ValueChanged<String>? onContentChanged;

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < lines.length; i++) _buildLine(lines, i),
      ],
    );
  }

  Widget _buildLine(List<String> lines, int index) {
    final line = lines[index];
    final open = RegExp(r'^(\s*)-\s\[\s\]\s?(.*)$');
    final done = RegExp(r'^(\s*)-\s\[[xX]\]\s?(.*)$');

    final openMatch = open.firstMatch(line);
    if (openMatch != null) {
      return _checkRow(
        lines: lines,
        index: index,
        checked: false,
        text: openMatch.group(2) ?? '',
      );
    }
    final doneMatch = done.firstMatch(line);
    if (doneMatch != null) {
      return _checkRow(
        lines: lines,
        index: index,
        checked: true,
        text: doneMatch.group(2) ?? '',
      );
    }

    if (line.isEmpty) {
      return SizedBox(height: 8.h);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: _styledText(line),
    );
  }

  Widget _styledText(String raw, {TextDecoration? extraDecoration}) {
    final parsed = NotesStyleCodec.decode(raw);
    final base = GoogleFonts.poppins(
      fontSize: 15.sp,
      color: NotesTheme.textPrimary.withValues(alpha: 0.9),
      height: 1.7,
      decoration: extraDecoration,
    );
    return Text.rich(
      NotesStyleCodec.buildTextSpan(
        text: parsed.text,
        styles: parsed.styles,
        style: base,
      ),
    );
  }

  Widget _checkRow({
    required List<String> lines,
    required int index,
    required bool checked,
    required String text,
  }) {
    return InkWell(
      onTap: readOnly || onContentChanged == null
          ? null
          : () {
              final next = NotesMarkdownFormat.toggleChecklistAtLine(
                lines.join('\n'),
                index,
              );
              if (next != null) onContentChanged!(next);
            },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              checked
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 22.sp,
              color: checked
                  ? NotesTheme.bronze
                  : NotesTheme.textPrimary.withValues(alpha: 0.45),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _styledText(
                text.isEmpty ? ' ' : text,
                extraDecoration:
                    checked ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
