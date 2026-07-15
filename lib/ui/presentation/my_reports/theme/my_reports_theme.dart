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
  static const iceBlue = Color(0xFFE8F4FB);
  static const mistWhite = Color(0xFFF5FAFD);

  static const textPrimary = Color(0xFF001D39);
  static const textSecondary = Color(0xFF0A4174);
  static const textMuted = Color(0xFF49769F);
  static const textOnDark = Color(0xFFFFFFFF);
  static const textMutedOnDark = Color(0xFFBDD8E9);
  static const accent = Color(0xFF0A4174);
  /// High-contrast navy on light / frosted cards.
  static const labelOnGradient = Color(0xFF001D39);
  static const bodyOnGradient = Color(0xFF0A4174);

  /// Light blue-only card slices — same family, no dark navy fills.
  static const _categoryPalettes = <List<Color>>[
    [Color(0xFFF5FAFD), Color(0xFFE8F4FB), Color(0xFFBDD8E9)],
    [Color(0xFFE8F4FB), Color(0xFFBDD8E9), Color(0xFF9BCBE8)],
    [Color(0xFFBDD8E9), Color(0xFFA8D4EC), Color(0xFF7BBDE8)],
    [Color(0xFFE3F1F8), Color(0xFFBDD8E9), Color(0xFF8EC4DF)],
    [Color(0xFFEFF7FC), Color(0xFFC9E2F0), Color(0xFF9CCBE5)],
    [Color(0xFFF2F8FC), Color(0xFFBDD8E9), Color(0xFF7BBDE8)],
    [Color(0xFFE8F4FB), Color(0xFFB4D6EA), Color(0xFF6EA2B3)],
    [Color(0xFFF5FAFD), Color(0xFFBDD8E9), Color(0xFF7BBDE8)],
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

  /// Soft light hub wash (same blue palette, no dark navy base).
  static const aiHubGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      mistWhite,
      iceBlue,
      frostBlue,
      Color(0xFFD4EAF6),
      Color(0xFFC5E0F0),
    ],
    stops: [0.0, 0.28, 0.55, 0.82, 1.0],
  );

  static const featuredCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFE8F4FB),
      Color(0xFFBDD8E9),
      Color(0xFF7BBDE8),
    ],
  );

  static const managementCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF0F7FB),
      Color(0xFFC5DFED),
      Color(0xFF6EA2B3),
    ],
  );

  static const siteReportCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFEAF5FB),
      Color(0xFFBDD8E9),
      Color(0xFF7BBDE8),
    ],
  );

  static BoxDecoration glassCard({double radius = 18, bool elevated = true}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      color: Colors.white.withValues(alpha: 0.92),
      border: Border.all(color: Colors.white.withValues(alpha: 0.95)),
      boxShadow: elevated
          ? [
              BoxShadow(
                color: deepNavy.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ]
          : null,
    );
  }

  static BoxDecoration iconBadge({double radius = 12}) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: frostBlue.withValues(alpha: 0.9)),
    );
  }

  static BoxDecoration counterBadge({double radius = 10}) {
    return BoxDecoration(
      color: royalBlue.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(radius),
    );
  }
}
