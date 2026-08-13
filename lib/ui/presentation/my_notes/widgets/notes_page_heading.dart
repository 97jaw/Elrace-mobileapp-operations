import 'package:el_race/ui/presentation/my_notes/theme/notes_theme.dart';
import 'package:el_race/ui/presentation/my_notes/theme/notes_theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Single-line "Notes" title with theme toggle on the right.
class NotesPageHeading extends StatelessWidget {
  const NotesPageHeading({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NotesThemeController.instance,
      builder: (context, _) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Notes',
                  style: GoogleFonts.poppins(
                    fontSize: 40.sp,
                    fontWeight: FontWeight.w700,
                    color: NotesTheme.textPrimary,
                    height: 1.05,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => NotesThemeController.instance.toggle(),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 44.w,
                    height: 44.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: NotesTheme.textPrimary.withValues(alpha: 0.08),
                      border: Border.all(
                        color: NotesTheme.textPrimary.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Icon(
                      NotesTheme.isLight
                          ? Icons.dark_mode_outlined
                          : Icons.light_mode_outlined,
                      size: 22.sp,
                      color: NotesTheme.textPrimary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
