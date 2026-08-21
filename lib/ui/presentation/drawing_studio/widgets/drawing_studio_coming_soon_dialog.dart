import 'dart:ui';

import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centered glass “Coming soon” dialog for hub options not wired yet.
Future<void> showDrawingStudioComingSoonDialog({
  required BuildContext context,
  required String title,
  String message =
      'This option will be available soon. Stay tuned.',
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierLabel: 'drawing_studio_coming_soon',
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) {
      return SafeArea(
        child: Center(
          child: _ComingSoonDialog(title: title, message: message),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _ComingSoonDialog extends StatelessWidget {
  const _ComingSoonDialog({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 28.w),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.ur),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20.w, 22.uh, 20.w, 18.uh),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(20.ur),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1A2A4F).withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52.w,
                    height: 52.w,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14.ur),
                      color: const Color(0xFFEEF2FF),
                    ),
                    child: Icon(
                      Icons.hourglass_top_rounded,
                      color: const Color(0xFF3E7BFA),
                      size: 26.usp,
                    ),
                  ),
                  SizedBox(height: 14.uh),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 16.usp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A2A4F),
                    ),
                  ),
                  SizedBox(height: 6.uh),
                  Text(
                    'Coming soon',
                    style: GoogleFonts.poppins(
                      fontSize: 12.usp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF3E7BFA),
                    ),
                  ),
                  SizedBox(height: 10.uh),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5.usp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF5A6A82),
                      height: 1.35,
                    ),
                  ),
                  SizedBox(height: 18.uh),
                  SizedBox(
                    width: double.infinity,
                    height: 46.uh,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A2A4F),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.ur),
                        ),
                      ),
                      child: Text(
                        'OK',
                        style: GoogleFonts.poppins(
                          fontSize: 14.usp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
