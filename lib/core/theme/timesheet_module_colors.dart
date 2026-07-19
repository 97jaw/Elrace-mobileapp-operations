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

  // Legacy shared canvas (used by Site Report + other modules — keep original).
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

  // ---------------------------------------------------------------------------
  // Warm parchment theme (foreman Timesheet screens + draggers only).
  // Site Report and other modules must NOT use these tokens.
  // ---------------------------------------------------------------------------
  static const Color warmGradientStart = Color(0xFFE9E9E7);
  static const Color warmGradientMid = Color(0xFFECDABC);
  static const Color warmGradientEnd = Color(0xFFEBE6DE);

  /// Glassy faded tile/box background used on top of the warm canvas.
  static const Color glassSurface = Color(0xFFF7F2E8);

  /// Subtle warm border around glass tiles.
  static const Color glassBorder = Color(0xFFE4DCCB);

  /// White circular icon-badge background (per warm theme spec).
  static const Color iconSurface = Color(0xFFFFFFFF);

  /// Dark ink text for the warm theme.
  static const Color ink = Color(0xFF2A2A2A);

  /// Muted warm text for secondary labels.
  static const Color warmMuted = Color(0xFF7A7062);

  /// Warm accent (vibrant orange) for numbers, icons, active states.
  static const Color accent = Color(0xFFF97316);

  /// Light orange wash for selected/tinted warm surfaces.
  static const Color accentTint = Color(0xFFFDEBDD);

  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [warmGradientStart, warmGradientMid, warmGradientEnd],
    stops: [0.0, 0.5, 1.0],
  );

  /// Primary action gradient for the warm theme: orange -> charcoal (diagonal).
  static const LinearGradient warmButtonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, Color(0xFF33302B)],
  );
}
