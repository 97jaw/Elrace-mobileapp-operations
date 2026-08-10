import 'package:el_race/ui/presentation/my_notes/theme/notes_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Compact AI picker for the note composer (all-in-one tools).
Future<void> showNotesComposerAiSheet(
  BuildContext context, {
  required Future<void> Function(String mode, {String? lang}) onRun,
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
                'AI tools',
                style: GoogleFonts.poppins(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: NotesTheme.textPrimary,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Transcribe only when you tap Transcribe. Summarize / bullets use existing text or transcript — they never start Whisper.',
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  color: NotesTheme.textPrimary.withValues(alpha: 0.5),
                ),
              ),
              SizedBox(height: 16.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: [
                  _AiChip(
                    label: 'Transcribe',
                    icon: Icons.mic_none_rounded,
                    onTap: () {
                      Navigator.pop(ctx);
                      onRun('transcribe');
                    },
                  ),
                  _AiChip(
                    label: 'Summarize',
                    icon: Icons.summarize_outlined,
                    onTap: () {
                      Navigator.pop(ctx);
                      onRun('summarize');
                    },
                  ),
                  _AiChip(
                    label: 'Bullets',
                    icon: Icons.format_list_bulleted,
                    onTap: () {
                      Navigator.pop(ctx);
                      onRun('bullets');
                    },
                  ),
                  _AiChip(
                    label: 'Actions',
                    icon: Icons.checklist_rounded,
                    onTap: () {
                      Navigator.pop(ctx);
                      onRun('actions');
                    },
                  ),
                  _AiChip(
                    label: 'Smart tags',
                    icon: Icons.label_outline,
                    onTap: () {
                      Navigator.pop(ctx);
                      onRun('tags');
                    },
                  ),
                  _AiChip(
                    label: 'To EN',
                    icon: Icons.translate,
                    onTap: () {
                      Navigator.pop(ctx);
                      onRun('translate', lang: 'en');
                    },
                  ),
                  _AiChip(
                    label: 'To AR',
                    icon: Icons.translate,
                    onTap: () {
                      Navigator.pop(ctx);
                      onRun('translate', lang: 'ar');
                    },
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

class _AiChip extends StatelessWidget {
  const _AiChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: NotesTheme.bronze.withValues(alpha: 0.15),
          border: Border.all(color: NotesTheme.bronze.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16.sp, color: NotesTheme.bronze),
            SizedBox(width: 6.w),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: NotesTheme.bronze,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
