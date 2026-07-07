import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dark cinematic theme for Media landing redesign.
abstract final class MediaTheme {
  static const Color black = Color(0xFF0A0A0A);
  static const Color sheetBg = Color(0xFF121212);
  static const Color white = Color(0xFFFFFFFF);

  static const double peekSheetSize = 0.30;
  static const double expandedSheetSize = 0.65;

  static const Color burgundyStart = Color(0xFF8B2635);
  static const Color burgundyEnd = Color(0xFF4A1721);
  static const Color blueStart = Color(0xFF1F3A5F);
  static const Color blueEnd = Color(0xFF4A6B8A);

  static const LinearGradient heroBottomScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0xCC000000)],
    stops: [0.35, 1.0],
  );

  /// Unified sheet gradient — no BackdropFilter (it blurs the hero video behind).
  static const LinearGradient sheetBackgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xE68B2635),
      Color(0xF24A1721),
      Color(0xF21F3A5F),
      Color(0xFF4A6B8A),
    ],
    stops: [0.0, 0.35, 0.72, 1.0],
  );

  static Color get glassFill => white.withValues(alpha: 0.14);
  static Color get glassBorder => white.withValues(alpha: 0.22);
  static Color get textSecondary => white.withValues(alpha: 0.72);
  static Color get textMuted => white.withValues(alpha: 0.48);

  static const SystemUiOverlayStyle lightStatusBar = SystemUiOverlayStyle(
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
    statusBarColor: Colors.transparent,
  );

  static double get gridRadius => 18.r;
  static double get tileRadius => 16.r;
  static double get heroCardRadius => 28.r;

  static TextStyle titleLg = GoogleFonts.poppins(
    fontSize: 18.sp,
    fontWeight: FontWeight.w700,
    color: white,
  );

  static TextStyle labelSm = GoogleFonts.poppins(
    fontSize: 11.sp,
    fontWeight: FontWeight.w500,
    color: textMuted,
  );

  /// Opaque gradient sheet — does NOT blur content behind the sheet.
  static Widget glassSheetBackground({required Widget child}) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: sheetBackgroundGradient,
      ),
      child: child,
    );
  }

  static Widget backButton({required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 40.w,
          height: 40.w,
          decoration: BoxDecoration(
            color: glassFill,
            shape: BoxShape.circle,
            border: Border.all(color: glassBorder),
          ),
          child: Icon(Icons.arrow_back_ios_new_rounded, color: white, size: 18.sp),
        ),
      ),
    );
  }

  static Widget moreButton({required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 40.w,
          height: 40.w,
          decoration: BoxDecoration(
            color: glassFill,
            shape: BoxShape.circle,
            border: Border.all(color: glassBorder),
          ),
          child: Icon(Icons.more_horiz_rounded, color: white, size: 22.sp),
        ),
      ),
    );
  }

  static Widget playButton({required VoidCallback onTap, double size = 56}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: size.w,
          height: size.w,
          decoration: BoxDecoration(
            color: white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: black.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(Icons.play_arrow_rounded, color: black, size: (size * 0.58).sp),
        ),
      ),
    );
  }

  static Widget pillButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: black,
            ),
          ),
        ),
      ),
    );
  }
}
