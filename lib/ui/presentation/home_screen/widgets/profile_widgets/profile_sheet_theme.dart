import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/core/ui/adaptive_glass.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Light palette aligned with Elrace brand (navy + maroon + silver grey).
abstract final class ProfileSheetTheme {
  static const Color navy = Color(0xFF1B2A4A);
  static const Color navySoft = Color(0xFF3D5F85);
  static const Color maroon = Color(0xFF8B1A2B);
  static const Color maroonPale = Color(0xFFE8D5DA);
  static const Color maroonLight = Color(0xFFF0E4E7);
  static const Color silver = Color(0xFFD6D6D6);
  static const Color silverPale = Color(0xFFF4F6F9);
  static const Color textPrimary = Color(0xFF1B2A4A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color activeGreen = Color(0xFF2D6B52);
  static const Color inactiveText = Color(0xFF8B95A5);
  static const Color accentRed = Color(0xFFE31937);

  static const Color messengerOnline = Color(0xFF31A24C);
  static const Color messengerOffline = Color(0xFFB0B3B8);

  /// Whole sheet — metallic faded base around #BFC9D1.
  static const LinearGradient sheetBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFC9D2D9),
      Color(0xFFBFC9D1),
      Color(0xFFB5C0C8),
      Color(0xFFC4CED6),
    ],
    stops: [0.0, 0.35, 0.72, 1.0],
  );

  /// Top header band — darker navy.
  static const LinearGradient profileHeaderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF152038),
      Color(0xFF1B2A4A),
      Color(0xFF243657),
    ],
  );

  /// Mid section around QR — faded #4B1426 maroon gradient.
  static const LinearGradient profileCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xCC4B1426),
      Color(0xB34B1426),
      Color(0xA63F1020),
      Color(0x99542235),
    ],
    stops: [0.0, 0.35, 0.7, 1.0],
  );

  /// Settings / bottom section — faded same family as main background.
  static const LinearGradient settingsSectionGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xA6D4DCE3),
      Color(0x8CBFC9D1),
      Color(0x73B5C0C8),
    ],
  );

  /// Metallic fade overlay across the sheet.
  static const LinearGradient metallicOverlay = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x66FFFFFF),
      Color(0x26FFFFFF),
      Color(0x00000000),
      Color(0x15000000),
    ],
    stops: [0.0, 0.25, 0.7, 1.0],
  );

  /// Overlay on QR frame to keep company themed sheen.
  static const LinearGradient qrOverlay = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x22FFFFFF),
      Color(0x168B1A2B),
      Color(0x121B2A4A),
    ],
  );

  /// Separate footer panel below QR (dept/section + leave).
  static const LinearGradient maroonInfoSection = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x66B88490),
      Color(0x66A4747F),
      Color(0x66C4959F),
    ],
  );

  static Widget glassCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    BorderRadius? borderRadius,
  }) {
    final radius = borderRadius ?? BorderRadius.circular(22.tr);
    return ClipRRect(
      borderRadius: radius,
      child: AdaptiveGlassLayer(
        borderRadius: radius,
        sigma: 16,
        fallbackColor: const Color(0xFFBFC9D1).withValues(alpha: 0.55),
        fallbackBorder: Border.all(
          color: Colors.white.withValues(alpha: 0.65),
          width: 1,
        ),
        child: HomeGlassTheme.frostInsetHighlight(
          radius: radius,
          child: Container(
            padding: padding ?? EdgeInsets.all(18.tw),
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: settingsSectionGradient,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.55),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: navy.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
