import 'package:el_race/ui/presentation/my_notes/theme/notes_theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// My Notes — Royal Bronze palette (Dark default + Light variant).
///
/// Colors resolve from [NotesThemeController]. Rebuild notes UI via
/// [NotesRoyalBronzeBackground] (listens to the controller).
abstract final class NotesTheme {
  static NotesBrightness get _b {
    NotesThemeController.instance.ensureLoaded();
    return NotesThemeController.instance.brightness;
  }

  static bool get isLight => _b == NotesBrightness.light;

  /// Canvas under the animated wash.
  static Color get pureBlack =>
      isLight ? const Color(0xFFF7F4EF) : const Color(0xFF000000);

  /// Alias for canvas (prefer this in new code).
  static Color get canvas => pureBlack;

  /// Secondary wash / sheet surface.
  static Color get charcoal =>
      isLight ? const Color(0xFFE8E2D8) : const Color(0xFF2C3E50);

  /// Elevated sheet / modal background.
  static Color get surface =>
      isLight ? const Color(0xFFFFFFFF) : const Color(0xFF2C3E50);

  static const Color bronze = Color(0xFFB08D57);

  static Color get textPrimary =>
      isLight ? const Color(0xFF2C3E50) : const Color(0xFFF5F0E8);

  static Color get textSecondary => bronze;

  static const double cardRadius = 22;
  static const double chipRadius = 999;

  static Color get glassFill => isLight
      ? Colors.black.withValues(alpha: 0.04)
      : Colors.white.withValues(alpha: 0.08);

  static Color get glassFillStrong => isLight
      ? Colors.black.withValues(alpha: 0.07)
      : Colors.white.withValues(alpha: 0.12);

  static Color get glassBorder =>
      bronze.withValues(alpha: isLight ? 0.28 : 0.22);

  static Color get glassBorderSoft => isLight
      ? Colors.black.withValues(alpha: 0.08)
      : Colors.white.withValues(alpha: 0.14);

  static Color get chipSelectedBorder => textPrimary.withValues(alpha: 0.9);

  static Color get chipSelectedText => textPrimary;

  static Color get chipBadgeFill =>
      charcoal.withValues(alpha: isLight ? 0.9 : 0.85);

  static Color get chipUnselectedBorder => isLight
      ? Colors.black.withValues(alpha: 0.18)
      : Colors.white.withValues(alpha: 0.28);

  static Color get chipUnselectedText =>
      textPrimary.withValues(alpha: isLight ? 0.45 : 0.42);

  /// Gradient wash mid opacity for background animation.
  static double get washAlphaTop => isLight ? 0.22 : 0.42;

  static double get washAlphaMid => isLight ? 0.85 : 0.92;

  static double get washAlphaBottom => isLight ? 0.18 : 0.34;

  static BorderRadius get cardBorderRadius => BorderRadius.circular(cardRadius);

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

  static SystemUiOverlayStyle get systemOverlay => isLight
      ? SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: canvas,
          systemNavigationBarIconBrightness: Brightness.dark,
        )
      : SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: const Color(0xFF000000),
          systemNavigationBarIconBrightness: Brightness.light,
        );
}
