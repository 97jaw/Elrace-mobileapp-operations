import 'package:el_race/ui/presentation/my_notes/data/note_model.dart';
import 'package:el_race/ui/presentation/my_notes/theme/notes_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class NotesAiModeChoice {
  final NoteAiMode mode;

  const NotesAiModeChoice({required this.mode});
}

/// Post-recording chooser. Transcript always runs on upload; pick optional AI.
Future<NotesAiModeChoice?> showNotesAiModeSheet(BuildContext context) {
  return showModalBottomSheet<NotesAiModeChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: NotesTheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
    ),
    builder: (ctx) => const _NotesAiModeSheetBody(),
  );
}

class _NotesAiModeSheetBody extends StatefulWidget {
  const _NotesAiModeSheetBody();

  @override
  State<_NotesAiModeSheetBody> createState() => _NotesAiModeSheetBodyState();
}

class _NotesAiModeSheetBodyState extends State<_NotesAiModeSheetBody> {
  NoteAiMode? _selected = NoteAiMode.none;

  void _confirm() {
    if (_selected == null) return;
    Navigator.of(context).pop(NotesAiModeChoice(mode: _selected!));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, bottom + 24.h),
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
            'Save recording',
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: NotesTheme.textPrimary,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Speech-to-text starts automatically after upload. Optionally request a summary.',
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              color: NotesTheme.textPrimary.withValues(alpha: 0.55),
            ),
          ),
          SizedBox(height: 16.h),
          _option(
            NoteAiMode.none,
            'Save only',
            'Keep the audio — transcript runs in the background',
            Icons.save_alt_rounded,
          ),
          SizedBox(height: 8.h),
          _option(
            NoteAiMode.summarize,
            'Summarize',
            'Runs after auto-transcript is ready',
            Icons.summarize_outlined,
          ),
          SizedBox(height: 8.h),
          _option(
            NoteAiMode.bullets,
            'Bullet points',
            'Runs after auto-transcript is ready',
            Icons.format_list_bulleted_rounded,
          ),
          SizedBox(height: 18.h),
          FilledButton(
            onPressed: _selected == null ? null : _confirm,
            style: FilledButton.styleFrom(
              backgroundColor: NotesTheme.bronze,
              foregroundColor: NotesTheme.pureBlack,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: Text(
              'Continue',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _option(
    NoteAiMode mode,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final selected = _selected == mode;
    return InkWell(
      onTap: () => setState(() => _selected = mode),
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          color: selected
              ? NotesTheme.bronze.withValues(alpha: 0.18)
              : NotesTheme.glassFill,
          border: Border.all(
            color: selected ? NotesTheme.bronze : NotesTheme.glassBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: NotesTheme.bronze, size: 22.sp),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: NotesTheme.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 11.sp,
                      color: NotesTheme.textPrimary.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: selected
                  ? NotesTheme.bronze
                  : NotesTheme.textPrimary.withValues(alpha: 0.35),
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
  }
}
