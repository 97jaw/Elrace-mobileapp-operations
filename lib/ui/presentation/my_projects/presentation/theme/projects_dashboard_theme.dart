import 'package:flutter/material.dart';

/// Projects dashboard palette: maroon, grey, navy, white only.
abstract final class ProjectsDashboardTheme {
  static const Color maroon = Color(0xFF7A1F32);
  static const Color maroonLight = Color(0xFFA04A5E);
  static const Color maroonSoft = Color(0xFFB86B7A);
  static const Color maroonDark = Color(0xFF5A1828);
  static const Color navy = Color(0xFF1E2365);
  static const Color grey = Color(0xFF6B7280);
  static const Color greyLight = Color(0xFF8B939E);
  static const Color greyDark = Color(0xFF454D5A);
  static const Color greyDeep = Color(0xFF353A44);
  static const Color greyPanel = Color(0xFFD8DCE3);
  static const Color white = Color(0xFFFFFFFF);

  /// Full-screen background — lighter maroon and grey blend.
  static const LinearGradient screenGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      maroonSoft,
      maroonLight,
      maroon,
      greyLight,
      greyDark,
      greyDeep,
    ],
    stops: [0.0, 0.18, 0.38, 0.58, 0.78, 1.0],
  );

  /// Frosted grey glass for KPI, chart, agreement cards.
  static const Color glassFill = Color(0x4D8B939E);
  static const Color glassFillStrong = Color(0x66A8B0BC);
  static const Color glassHighlight = Color(0x33FFFFFF);

  /// Dark metallic tile (toolbar icons).
  static const LinearGradient iconTileGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x66454D5A), Color(0x99353A44)],
  );

  static const LinearGradient iconTileActiveGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x99A04A5E), Color(0xCC7A1F32)],
  );

  static const LinearGradient maroonAccentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xCCB86B7A), Color(0xCC7A1F32)],
  );

  static const LinearGradient cardHeaderGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0x99454D5A), Color(0x997A1F32)],
  );

  static BoxDecoration frostedPanel({double radius = 18}) => BoxDecoration(
        color: glassFill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: glassHighlight,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  static BoxDecoration frostedChip({double radius = 20}) => BoxDecoration(
        color: glassFillStrong,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: glassHighlight,
          width: 1,
        ),
      );

  /// Year chip + sheet list tiles — light grey with maroon fade for contrast.
  static BoxDecoration dropdownChipDecoration({double radius = 20}) =>
      BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            greyPanel.withValues(alpha: 0.52),
            maroonSoft.withValues(alpha: 0.38),
            greyLight.withValues(alpha: 0.42),
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: white.withValues(alpha: 0.4),
          width: 1,
        ),
      );

  static BoxDecoration pickerSheetTileDecoration({
    required bool selected,
    double radius = 12,
  }) =>
      BoxDecoration(
        gradient: selected
            ? LinearGradient(
                colors: [
                  maroon.withValues(alpha: 0.55),
                  maroonDark.withValues(alpha: 0.7),
                ],
              )
            : LinearGradient(
                colors: [
                  greyPanel.withValues(alpha: 0.28),
                  maroon.withValues(alpha: 0.18),
                ],
              ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: selected
              ? white.withValues(alpha: 0.45)
              : white.withValues(alpha: 0.22),
        ),
      );

  static const LinearGradient pickerSheetGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xCC8B939E),
      Color(0xE6454D5A),
      Color(0xF05A1828),
    ],
    stops: [0.0, 0.45, 1.0],
  );

  /// Slide-up sheets (year picker, project list). Uniform border only — required for borderRadius.
  static BoxDecoration glassSheetDecoration({double topRadius = 24}) =>
      BoxDecoration(
        color: greyDeep.withValues(alpha: 0.96),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(topRadius),
        ),
        border: Border.all(
          color: glassHighlight,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      );

  static BoxShadow cardShadow = BoxShadow(
    color: Colors.black.withValues(alpha: 0.15),
    blurRadius: 10,
    offset: const Offset(0, 3),
  );
}
