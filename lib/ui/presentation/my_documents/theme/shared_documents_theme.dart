import 'package:flutter/material.dart';

/// Light blush / white glass design for Shared Documents inner screens.
/// Maroon is accent-only; home widget half-card stays rich maroon separately.
abstract final class SharedDocumentsTheme {
  static const accent = Color(0xFF8B1A2B);
  static const accentSoft = Color(0xFFA8324A);
  static const accentMuted = Color(0xFFB86B7A);
  static const textPrimary = Color(0xFF3A1A22);
  static const textSecondary = Color(0xFF6B4A52);
  static const textMuted = Color(0xFF9A7A82);
  static const border = Color(0xFFE8D4D8);
  static const danger = Color(0xFFBA1719);
  static const cardFill = Color(0xFFFFFFF8);
  static const hubBackground = Color(0xFFFFF5F6);

  static const hubBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFFFF8F9),
      Color(0xFFFCE8EC),
      Color(0xFFF5D0D6),
    ],
    stops: [0.0, 0.35, 0.7, 1.0],
  );

  static BoxDecoration glassCard({
    double radius = 20,
    Color? tint,
  }) =>
      BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (tint ?? Colors.white).withValues(alpha: 0.92),
            (tint ?? const Color(0xFFFFF0F2)).withValues(alpha: 0.72),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      );

  static BoxDecoration sheetDecoration({double radius = 22}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      );

  static ButtonStyle softFilledButton({
    EdgeInsetsGeometry? padding,
  }) =>
      ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: accentMuted.withValues(alpha: 0.45),
        elevation: 0,
        padding: padding ??
            const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      );

  static ButtonStyle softOutlinedButton({
    EdgeInsetsGeometry? padding,
  }) =>
      OutlinedButton.styleFrom(
        foregroundColor: accent,
        side: const BorderSide(color: accent, width: 1.2),
        padding: padding ??
            const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      );
}
