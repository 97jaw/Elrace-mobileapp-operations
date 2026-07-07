import 'package:el_race/ui/presentation/my_reports/models/my_report_category.dart';
import 'package:flutter/material.dart';

abstract final class MyReportsTheme {
  static const deepNavy = Color(0xFF001D39);
  static const royalBlue = Color(0xFF0A4174);
  static const steelBlue = Color(0xFF49769F);
  static const tealBlue = Color(0xFF4E8EA2);
  static const lightTeal = Color(0xFF6EA2B3);
  static const skyBlue = Color(0xFF7BBDE8);
  static const frostBlue = Color(0xFFBDD8E9);

  static const textPrimary = Color(0xFF001D39);
  static const textSecondary = Color(0xFF0A4174);
  static const textMuted = Color(0xFF49769F);
  static const textOnDark = Color(0xFFFFFFFF);
  static const textMutedOnDark = Color(0xFFBDD8E9);
  static const accent = Color(0xFF0A4174);
  static const labelOnGradient = Color(0xFF001D39);
  static const bodyOnGradient = Color(0xFF0A4174);

  /// Blue-only palette slices — no purple/green/yellow.
  static const _categoryPalettes = <List<Color>>[
    [Color(0xFFBDD8E9), Color(0xFF7BBDE8), Color(0xFF6EA2B3)],
    [Color(0xFF7BBDE8), Color(0xFF6EA2B3), Color(0xFF4E8EA2)],
    [Color(0xFF6EA2B3), Color(0xFF4E8EA2), Color(0xFF49769F)],
    [Color(0xFF4E8EA2), Color(0xFF49769F), Color(0xFF0A4174)],
    [Color(0xFF49769F), Color(0xFF0A4174), Color(0xFF001D39)],
    [Color(0xFFBDD8E9), Color(0xFF4E8EA2), Color(0xFF0A4174)],
    [Color(0xFF7BBDE8), Color(0xFF49769F), Color(0xFF001D39)],
    [Color(0xFF0A4174), Color(0xFF001D39), Color(0xFF49769F)],
  ];

  static LinearGradient gradientForCategory(MyReportCategory category) {
    final index = MyReportCategoryType.values.indexOf(category.type);
    final colors = _categoryPalettes[index % _categoryPalettes.length];
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    );
  }

  static const aiHubGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      frostBlue,
      skyBlue,
      lightTeal,
      royalBlue,
      deepNavy,
    ],
    stops: [0.0, 0.22, 0.5, 0.76, 1.0],
  );

  static BoxDecoration glassCard({double radius = 18, bool elevated = true}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      color: Colors.white.withValues(alpha: 0.88),
      border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
      boxShadow: elevated
          ? [
              BoxShadow(
                color: deepNavy.withValues(alpha: 0.14),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ]
          : null,
    );
  }

  static BoxDecoration iconBadge({double radius = 12}) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
    );
  }

  static BoxDecoration counterBadge({double radius = 10}) {
    return BoxDecoration(
      color: deepNavy.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(radius),
    );
  }
}
