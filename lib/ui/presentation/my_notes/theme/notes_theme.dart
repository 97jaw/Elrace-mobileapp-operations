import 'package:flutter/material.dart';

/// My Notes — Royal Bronze palette on pure black.
abstract final class NotesTheme {
  static const Color pureBlack = Color(0xFF000000);
  static const Color charcoal = Color(0xFF2C3E50);
  static const Color bronze = Color(0xFFB08D57);

  static const Color textPrimary = Color(0xFFF5F0E8);
  static const Color textSecondary = Color(0xFFB08D57);

  static const double cardRadius = 22;
  static const double chipRadius = 999;

  /// Soft glass fill over black / animated gradient.
  static Color get glassFill => Colors.white.withValues(alpha: 0.08);

  static Color get glassFillStrong => Colors.white.withValues(alpha: 0.12);

  static Color get glassBorder => bronze.withValues(alpha: 0.22);

  static Color get glassBorderSoft => Colors.white.withValues(alpha: 0.14);

  /// Selected filter chip.
  static Color get chipSelectedBorder => textPrimary.withValues(alpha: 0.9);

  static Color get chipSelectedText => textPrimary;

  static Color get chipBadgeFill => charcoal.withValues(alpha: 0.85);

  /// Unselected / ghosted filter chip.
  static Color get chipUnselectedBorder => Colors.white.withValues(alpha: 0.28);

  static Color get chipUnselectedText => Colors.white.withValues(alpha: 0.42);

  static BorderRadius get cardBorderRadius =>
      BorderRadius.circular(cardRadius);

  static BoxBorder get glassBoxBorder => Border.all(
        color: glassBorder,
        width: 1,
      );

  static BoxDecoration glassDecoration({
    double radius = cardRadius,
    Color? fill,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: fill ?? glassFill,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? glassBorder,
        width: 1,
      ),
    );
  }
}
