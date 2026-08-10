import 'package:el_race/ui/presentation/my_notes/theme/notes_theme.dart';
import 'package:el_race/ui/presentation/my_notes/utils/notes_markdown_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> showNotesFormatSheet(
  BuildContext context, {
  required TextEditingController contentController,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: NotesTheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: NotesTheme.textPrimary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'Format',
                style: GoogleFonts.poppins(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: NotesTheme.textPrimary,
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _FmtBtn(
                    label: 'B',
                    tooltip: 'Bold',
                    onTap: () {
                      NotesMarkdownFormat.bold(contentController);
                      Navigator.pop(ctx);
                    },
                    child: Text(
                      'B',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w800,
                        fontSize: 18.sp,
                        color: NotesTheme.textPrimary,
                      ),
                    ),
                  ),
                  _FmtBtn(
                    label: 'I',
                    tooltip: 'Italic',
                    onTap: () {
                      NotesMarkdownFormat.italic(contentController);
                      Navigator.pop(ctx);
                    },
                    child: Text(
                      'I',
                      style: GoogleFonts.poppins(
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                        fontSize: 18.sp,
                        color: NotesTheme.textPrimary,
                      ),
                    ),
                  ),
                  _FmtBtn(
                    label: 'List',
                    tooltip: 'Bullet list',
                    onTap: () {
                      NotesMarkdownFormat.bulletList(contentController);
                      Navigator.pop(ctx);
                    },
                    child: Icon(
                      Icons.format_list_bulleted,
                      color: NotesTheme.textPrimary,
                      size: 22.sp,
                    ),
                  ),
                  _FmtBtn(
                    label: 'Check',
                    tooltip: 'Checklist',
                    onTap: () {
                      NotesMarkdownFormat.checklist(contentController);
                      Navigator.pop(ctx);
                    },
                    child: Icon(
                      Icons.checklist_rounded,
                      color: NotesTheme.textPrimary,
                      size: 22.sp,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _FmtBtn extends StatelessWidget {
  const _FmtBtn({
    required this.label,
    required this.tooltip,
    required this.onTap,
    required this.child,
  });

  final String label;
  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          width: 64.w,
          height: 56.h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: NotesTheme.glassFill,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: NotesTheme.glassBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}
