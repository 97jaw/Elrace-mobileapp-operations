import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Petty Cash holder UI — black → mint gradient, glass surfaces on dark.
abstract final class PettyCashTheme {
  static const Color mint = Color(0xFF34D399);
  static const Color mintDark = Color(0xFF10B981);
  static const Color mintDeep = Color(0xFF059669);
  static const Color greyDark = Color(0xFF2A2D32);
  static const Color greyMid = Color(0xFF4A4E55);
  static const Color greySoft = Color(0xFF6B7280);
  static const Color black = Color(0xFF000000);
  static const Color greenBlack = Color(0xFF2A2F34);
  static const Color greenMid = Color(0xFF14532D);
  static const Color white = Color(0xFFFFFFFF);
  static const Color expenseRed = Color(0xFFFF6B6B);
  static const Color success = Color(0xFF34D399);
  static const Color denyRed = Color(0xFFFF8A8A);

  /// Full-screen background — light grey → deep green (header through bottom).
  static const LinearGradient screenGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF454A52),
      Color(0xFF4E545C),
      Color(0xFF5C636C),
      Color(0xFF3A5244),
      Color(0xFF0F3D24),
      Color(0xFF0A2E1B),
      Color(0xFF1A7A4E),
    ],
    stops: [0.0, 0.14, 0.32, 0.48, 0.66, 0.84, 1.0],
  );

  static const LinearGradient heroCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [black, Color(0xFF0F172A), Color(0xFF065F46), mint],
    stops: [0.0, 0.4, 0.75, 1.0],
  );

  static const LinearGradient backCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1F2937), Color(0xFF064E3B)],
  );

  static const LinearGradient dialogGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xE6383C42),
      Color(0xF02E3338),
      Color(0xF0144538),
    ],
  );

  static Color get screenBg => greenBlack;

  static BoxDecoration surfaceCard({double radius = 22}) =>
      glassCard(radius: radius);

  static Color get textPrimary => white;
  static Color get textSecondary => white.withValues(alpha: 0.72);
  static Color get textMuted => white.withValues(alpha: 0.48);
  static Color get textFaint => white.withValues(alpha: 0.32);
  static Color get glassFill => white.withValues(alpha: 0.09);
  static Color get glassBorder => white.withValues(alpha: 0.14);
  static Color get iconCircleBg => white.withValues(alpha: 0.12);

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: black.withValues(alpha: 0.45),
          offset: const Offset(23.56, 51.83),
          blurRadius: 76.8,
          spreadRadius: -4.71,
        ),
      ];

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: black.withValues(alpha: 0.28),
          offset: const Offset(0, 10),
          blurRadius: 28,
          spreadRadius: -6,
        ),
      ];

  static BoxDecoration glassCard({double radius = 22}) => BoxDecoration(
        color: glassFill,
        borderRadius: BorderRadius.circular(radius.r),
        border: Border.all(color: glassBorder, width: 1),
        boxShadow: softShadow,
      );

  static BoxDecoration glassPanel({double radius = 24}) => BoxDecoration(
        gradient: dialogGradient,
        borderRadius: BorderRadius.circular(radius.r),
        border: Border.all(color: glassBorder, width: 1.1),
        boxShadow: cardShadow,
      );

  static BoxDecoration mintPillButton = BoxDecoration(
    gradient: const LinearGradient(
      colors: [mint, mintDark],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(999),
    boxShadow: [
      BoxShadow(
        color: mint.withValues(alpha: 0.42),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ],
  );

  static BoxDecoration primaryButton = BoxDecoration(
    gradient: const LinearGradient(
      colors: [Color(0xFF1A1A1A), black],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(999),
    boxShadow: [
      BoxShadow(
        color: black.withValues(alpha: 0.45),
        blurRadius: 14,
        offset: const Offset(0, 6),
      ),
    ],
  );

  static TextStyle titleLg = GoogleFonts.poppins(
    fontSize: 18.sp,
    fontWeight: FontWeight.w700,
    color: white,
  );

  static TextStyle labelSm = GoogleFonts.poppins(
    fontSize: 11.sp,
    fontWeight: FontWeight.w500,
    color: white.withValues(alpha: 0.5),
  );

  static TextStyle amountMd = GoogleFonts.poppins(
    fontSize: 15.sp,
    fontWeight: FontWeight.w700,
    color: white,
  );
}
