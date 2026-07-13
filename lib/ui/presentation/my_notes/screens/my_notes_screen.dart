import 'package:el_race/ui/presentation/productivity/theme/productivity_theme.dart';
import 'package:el_race/ui/presentation/productivity/widgets/productivity_screen_shell.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_ai_coming_soon_section.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';

/// Notes is preview-only until backend + AI features ship.
class MyNotesScreen extends StatelessWidget {
  const MyNotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ProductivityScreenShell(
      title: translate('home.my_notes'),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16.w,
          8.h,
          16.w,
          context.systemBottomInset + 20.h,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const NotesAiComingSoonSection(),
            SizedBox(height: 12.h),
            _PreviewTile(
              icon: Icons.edit_note_rounded,
              title: 'Quick capture',
              subtitle: 'Jot ideas in seconds — synced across devices.',
            ),
            SizedBox(height: 8.h),
            _PreviewTile(
              icon: Icons.folder_special_outlined,
              title: 'Smart folders',
              subtitle: 'Auto-group notes by project, date, and tags.',
            ),
            SizedBox(height: 8.h),
            _PreviewTile(
              icon: Icons.lock_outline_rounded,
              title: 'Private & secure',
              subtitle: 'Your notes stay encrypted and role-scoped.',
            ),
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              decoration: ProductivityTheme.glassCard(radius: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18.sp,
                    color: ProductivityTheme.accentDeep,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      'Notes will launch soon with AI writing, voice capture, and summaries.',
                      style: GoogleFonts.poppins(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                        color: ProductivityTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: ProductivityTheme.glassCard(radius: 16),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ProductivityTheme.accentBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, size: 20.sp, color: ProductivityTheme.accentDeep),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: ProductivityTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: ProductivityTheme.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
