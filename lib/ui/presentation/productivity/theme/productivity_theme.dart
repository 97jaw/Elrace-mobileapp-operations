import 'package:flutter/material.dart';

/// Light sky-blue glass design for Productivity modules (tasks, tickets, notes).
abstract final class ProductivityTheme {
  static const accentBlue = Color(0xFF2D7FF0);
  static const accentDeep = Color(0xFF1858C0);
  static const textPrimary = Color(0xFF1E3A5F);
  static const textSecondary = Color(0xFF5B7A9A);
  static const textMuted = Color(0xFF8FA8C0);
  static const hubBackground = Color(0xFFEAF6FF);

  static const hubBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFF0F9FF),
      Color(0xFFE0F2FE),
      Color(0xFFD4EBFA),
    ],
    stops: [0.0, 0.35, 0.7, 1.0],
  );

  static const cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xCCFFFFFF),
      Color(0xB3E8F4FC),
    ],
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
            (tint ?? Colors.white).withValues(alpha: 0.72),
            (tint ?? const Color(0xFFE8F4FC)).withValues(alpha: 0.48),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentBlue.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      );
}
