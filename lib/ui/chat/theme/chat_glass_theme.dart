import 'dart:ui';

import 'package:el_race/core/ui/device_ui_capability.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Chat / Discuss water-glass tokens on the blue geometric wallpaper.
abstract final class ChatGlassTheme {
  /// White-only type hierarchy (opacity for secondary/muted).
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xE6FFFFFF);
  static const Color textMuted = Color(0xB3FFFFFF);

  /// Soft water accents (legacy `gold` name kept for existing call sites).
  static const Color gold = Color(0xFFB8D4F0);
  static const Color goldDeep = Color(0xFF5A8FBE);
  static const Color silverLight = Color(0xFFFFFFFF);
  static const Color silverDeep = Color(0xFFD6E8F5);

  /// Water glass — transparent so wallpaper reads through with blur.
  static const Color waterFill = Color(0x14FFFFFF);
  static const Color waterFillStrong = Color(0x22A8D4F0);
  static const Color waterFillBright = Color(0x55FFFFFF);
  static const Color glassFill = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x66FFFFFF);
  static const Color glassActiveFill = Color(0x33FFFFFF);
  static const Color glassHighlight = Color(0x88FFFFFF);

  static const Color avatarRing = Color(0xFFFFFFFF);

  static const LinearGradient goldButtonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xE6FFFFFF),
      Color(0xB3C8E4F8),
    ],
  );

  static const LinearGradient silverButtonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xCCFFFFFF),
      Color(0x99D6E8F5),
    ],
  );

  static const LinearGradient goldGlassGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x66FFFFFF),
      Color(0x334A90C8),
    ],
  );

  static const LinearGradient waterActiveGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x73FFFFFF),
      Color(0x405A9FD4),
    ],
  );

  static ImageFilter get glassBlur {
    final sigma = DeviceUiCapability.adaptiveBlurSigma(16);
    return ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
  }

  static BoxDecoration glassDecoration({
    BorderRadius? borderRadius,
    Color? fillColor,
    double borderOpacity = 0.45,
  }) {
    final radius = borderRadius ?? BorderRadius.circular(24);
    return BoxDecoration(
      borderRadius: radius,
      color: fillColor ?? waterFill,
      border: Border.all(
        color: Colors.white.withValues(alpha: borderOpacity),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0A2848).withValues(alpha: 0.22),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static BoxDecoration waterCardDecoration({
    BorderRadius? borderRadius,
  }) {
    final radius = borderRadius ?? BorderRadius.circular(18);
    return BoxDecoration(
      borderRadius: radius,
      color: waterFill,
      border: Border.all(color: Colors.white.withValues(alpha: 0.38), width: 1),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0A2848).withValues(alpha: 0.1),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  static TextStyle title({double fontSize = 28}) => GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        height: 1.15,
        shadows: const [
          Shadow(
            color: Color(0x33000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      );

  static TextStyle body(
          {double fontSize = 15, FontWeight weight = FontWeight.w500}) =>
      GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: weight,
        color: textPrimary,
      );

  static TextStyle muted({double fontSize = 13}) => GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
        color: textMuted,
      );

  static TextStyle accent({double fontSize = 14}) => GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      );
}
