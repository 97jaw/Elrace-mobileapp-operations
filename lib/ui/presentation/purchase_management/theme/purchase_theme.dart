import 'dart:ui';

import 'package:flutter/material.dart';

/// Light sky-blue glass design system for Purchase Management.
abstract final class PurchaseTheme {
  static const accentBlue = Color(0xFF4A9FD4);
  static const accentDeep = Color(0xFF2B6CB0);
  static const urgentOrange = Color(0xFFFFB869);
  static const pendingBadge = Color(0xFFE09A3E);
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

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xCCFFFFFF),
      Color(0xB3E8F4FC),
    ],
  );

  static const mrHeroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xD9FFFFFF),
      Color(0xCCE8F0FF),
    ],
  );

  static const urgentAccentGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0x33FFB869), Color(0x00FFB869)],
  );

  static const mrBorderColor = Color(0x664A9FD4);

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

  static BoxDecoration glassPanel({double radius = 16}) => BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: Colors.white.withValues(alpha: 0.58),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: accentBlue.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  static Widget frosted({
    required Widget child,
    double sigma = 12,
    BorderRadius? borderRadius,
  }) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: child,
      ),
    );
  }
}
