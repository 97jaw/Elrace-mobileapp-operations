import 'package:el_race/ui/presentation/productivity/theme/productivity_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

void showProductivityComingSoonSnackBar(
  BuildContext context, {
  required String featureLabel,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ProductivityTheme.textPrimary,
      margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 24.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
      content: Row(
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ProductivityTheme.accentBlue.withValues(alpha: 0.25),
            ),
            child: Icon(
              Icons.hourglass_top_rounded,
              color: Colors.white,
              size: 18.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              '$featureLabel — Coming soon',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}
