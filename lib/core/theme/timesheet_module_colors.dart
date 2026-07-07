import 'package:flutter/material.dart';

/// Project Site Timesheet palette.
/// Updated per product direction: maroon + navy for Module 6.
abstract final class TimesheetModuleColors {
  static const Color primary = Color(0xFF8B2635);
  static const Color primaryGradientStart = Color(0xFF9E3143);
  static const Color primaryGradientEnd = Color(0xFF5D1522);
  static const Color primaryTint = Color(0xFFF7E8EC);
  static const Color navy = Color(0xFF1F3A5F);
  static const Color navyTint = Color(0xFFE8EEF6);
  static const Color bgGradientStart = Color(0xFFF7F2F4);
  static const Color bgGradientEnd = Color(0xFFEFF2F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF17233A);
  static const Color mutedText = Color(0xFF7A8194);
  static const Color divider = Color(0xFFECEEF3);
  static const Color success = Color(0xFF1F3A5F);
  static const Color warning = Color(0xFFF5B544);
  static const Color danger = Color(0xFFEF5C5C);
  static const Color info = Color(0xFF5B8DEF);

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgGradientStart, bgGradientEnd],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryGradientStart, primaryGradientEnd],
  );
}
