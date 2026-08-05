import 'dart:ui';

import 'package:el_race/core/ui/adaptive_glass.dart';
import 'package:el_race/core/ui/device_ui_capability.dart';
import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

enum MidSectionShell { dual, attendance, prayer }

/// Silver header palette and glassmorphism helpers for the redesigned home screen.
abstract final class HomeGlassTheme {
  static const Color silverLeft = Color(0xFFADB2BD);
  static const Color silverRight = Color(0xFFD6D6D6);
  static const Color textPrimary = Color(0xFF1B2A4A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color accentRed = Color(0xFFE31937);
  static const Color maroon = Color(0xFF8B1A2B);
  static const Color bottleGreen = Color(0xFF2D6B52);

  /// Very light navy accents for the animated header wash.
  static const Color headerNavySoft = Color(0xFFD8E2F0);
  static const Color headerNavyMist = Color(0xFFE8EEF6);
  static const Color headerNavyHint = Color(0xFFC5D2E6);

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [silverLeft, silverRight],
  );

  /// Emphasized swords / brand texture from legacy header art.
  static Widget swordsOverlay({double opacity = 0.55}) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/png/header_bg.png'),
              fit: BoxFit.cover,
              alignment: Alignment.centerRight,
            ),
          ),
        ),
      ),
    );
  }

  static ImageFilter get glassBlur {
    final sigma = DeviceUiCapability.adaptiveBlurSigma(25);
    return ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
  }

  static BoxDecoration glassDecoration({
    BorderRadius? borderRadius,
    Color? fillColor,
  }) {
    final radius = borderRadius ?? BorderRadius.circular(999);
    return BoxDecoration(
      borderRadius: radius,
      // Soft silver-grey frosted fill (matches widgets panel, less chalky white).
      color: fillColor ?? const Color(0xFFB8BFC9).withValues(alpha: 0.55),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.62),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0F1A35).withValues(alpha: 0.08),
          blurRadius: 18,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static Widget frostInsetHighlight({required Widget child, BorderRadius? radius}) {
    final r = radius ?? BorderRadius.circular(999);
    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(top: r.topLeft),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.95),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static const Border midModeHairlineBorder = Border.fromBorderSide(
    BorderSide(color: Color(0xCCE8ECF0), width: 0.6),
  );

  /// Top bar for expanded mid-section modes (attendance / prayer).
  static Widget midModePanelHeader({
    required VoidCallback onBack,
    required Widget title,
    required Color iconColor,
    Widget? trailing,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: 4.h, bottom: 6.h, left: 6.w),
      child: Row(
        children: [
          midGlassCircleButton(
            onTap: onBack,
            icon: Icons.arrow_back_ios_new_rounded,
            iconColor: iconColor,
          ),
          SizedBox(width: 8.w),
          Expanded(child: title),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  /// Attendance: navy → light blue glass wash.
  static const LinearGradient attendanceFillGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1B2A4A),
      Color(0xFF3D5F85),
      Color(0xFF6A8FB8),
      Color(0xFF95CBED),
      Color(0xFFC5E6F8),
    ],
  );

  /// Prayer: #4E3813 → #80672E (reference card).
  static const LinearGradient prayerFillGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4E3813), Color(0xFF65502A), Color(0xFF80672E)],
  );

  /// Mid swipe fill: light maroon-grey → navy (follows thumb).
  static const LinearGradient midSwipeTrackGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFFD8C4C8),
      Color(0xFFC5B8BE),
      Color(0xFF8FA3BC),
      Color(0xFF3D5F85),
      Color(0xFF1B2A4A),
    ],
  );

  static const Color midSwipeThumbColor = Color(0xFF1B2A4A);

  /// Circular glass control (matches news card carousel button).
  static Widget midGlassCircleButton({
    required VoidCallback onTap,
    required IconData icon,
    Color iconColor = Colors.white,
    double size = 32,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        customBorder: const CircleBorder(),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.white.withValues(alpha: 0.14),
        child: SizedBox(
          width: size.w,
          height: size.w,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Icon(icon, color: iconColor, size: 15.sp),
          ),
        ),
      ),
    );
  }

  /// Mid-section shell: dual = original glass; attendance / prayer = themed glass.
  static Widget midSectionShell({
    required MidSectionShell shell,
    required Widget child,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? padding,
  }) {
    final radius = borderRadius ?? BorderRadius.circular(18.ur);
    switch (shell) {
      case MidSectionShell.dual:
        return _dualMidSectionShell(
          padding: padding ?? EdgeInsets.all(12.w),
          child: child,
        );
      case MidSectionShell.attendance:
        return _midThemedGlassShell(
          radius: radius,
          padding: padding,
          backgroundAsset: 'assets/newapp/check_in_background.png',
          gradient: attendanceFillGradient,
          gradientOpacity: 0.68,
          patternOverlay: const _AttendanceFingerprintOverlay(),
          child: child,
        );
      case MidSectionShell.prayer:
        return _midThemedGlassShell(
          radius: radius,
          padding: padding,
          backgroundAsset:
              'assets/newapp/newicon/Prayer_widget_packground.png',
          gradient: prayerFillGradient,
          gradientOpacity: 0.28,
          patternOverlay: const _PrayerPatternOverlay(opacity: 0.45),
          child: child,
        );
    }
  }

  /// Dual strip — same frosted grey theme as the widgets panel.
  static Widget _dualMidSectionShell({
    required EdgeInsetsGeometry padding,
    required Widget child,
  }) {
    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: widgetsStyleSurface(
        borderRadius: BorderRadius.circular(22.ur),
        padding: padding,
        shadowOffset: const Offset(0, 5),
        child: child,
      ),
    );
  }

  /// Shared glass shell for attendance + prayer (blur, hairline, gradient fill).
  static Widget _midThemedGlassShell({
    required BorderRadius radius,
    required EdgeInsetsGeometry? padding,
    required Widget child,
    Gradient? gradient,
    double gradientOpacity = 0.65,
    String? backgroundAsset,
    Widget? patternOverlay,
  }) {
    return ClipRRect(
      borderRadius: radius,
      child: AdaptiveGlassLayer(
        borderRadius: radius,
        sigma: 18,
        fallbackColor: Colors.white.withValues(alpha: 0.78),
        child: _midFillShell(
          radius: radius,
          padding: padding,
          shell: MidSectionShell.attendance,
          gradient: gradient,
          gradientOpacity: gradientOpacity,
          backgroundAsset: backgroundAsset,
          patternOverlay: patternOverlay,
          showHairline: true,
          child: child,
        ),
      ),
    );
  }

  /// Solid gradient / fill — optional thin white hairline.
  static Widget _midFillShell({
    required BorderRadius radius,
    required EdgeInsetsGeometry? padding,
    required MidSectionShell shell,
    required Widget child,
    Gradient? gradient,
    double gradientOpacity = 0.65,
    Color? fillColor,
    String? backgroundAsset,
    Widget? patternOverlay,
    bool showHairline = false,
    bool skipGlassWash = false,
  }) {
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: radius,
          color: gradient == null ? fillColor : null,
          border: showHairline ? midModeHairlineBorder : null,
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            if (backgroundAsset != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipRRect(
                    borderRadius: radius,
                    child: Image.asset(
                      backgroundAsset,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            if (gradient != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: gradientOpacity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        gradient: gradient,
                      ),
                    ),
                  ),
                ),
              ),
            if (!skipGlassWash)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.12),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (patternOverlay != null) patternOverlay,
            child,
          ],
        ),
      ),
    );
  }

  static Widget glassSurface({
    required Widget child,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? padding,
    Color? fillColor,
  }) {
    // fillColor kept for API compatibility; widgets panel theme is the source.
    return widgetsStyleSurface(
      borderRadius: borderRadius ?? BorderRadius.circular(20.r),
      padding: padding,
      shadowOffset: const Offset(0, 4),
      child: child,
    );
  }

  static const LinearGradient widgetsPanelBaseGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFC8CDD5),
      Color(0xFFBCC2CB),
      Color(0xFFB0B7C1),
    ],
  );

  static const LinearGradient widgetsPanelGlassWash = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xB3FFFFFF),
      Color(0x73FFFFFF),
      Color(0x24FFFFFF),
    ],
    stops: [0.0, 0.4, 1.0],
  );

  /// Shared widgets-panel fill layers (base grey + white glass wash).
  static List<Widget> _widgetsPanelBackdropLayers(BorderRadius borderRadius) {
    return [
      const Positioned.fill(
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: widgetsPanelBaseGradient),
          ),
        ),
      ),
      Positioned.fill(
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFA8AFBA).withValues(alpha: 0.22),
            ),
          ),
        ),
      ),
      const Positioned.fill(
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: widgetsPanelGlassWash),
          ),
        ),
      ),
      Positioned.fill(
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.22),
                  Colors.transparent,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ),
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.vertical(top: borderRadius.topLeft),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.95),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ),
    ];
  }

  /// Compact card surface using the same theme as [widgetsPanelShell].
  static Widget widgetsStyleSurface({
    required Widget child,
    required BorderRadius borderRadius,
    EdgeInsetsGeometry? padding,
    Offset shadowOffset = const Offset(0, 4),
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(
          color: Colors.white,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: shadowOffset,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: AdaptiveGlassLayer(
          borderRadius: borderRadius,
          sigma: 24,
          fallbackColor: const Color(0xFFBCC2CB).withValues(alpha: 0.92),
          child: Stack(
            children: [
              ..._widgetsPanelBackdropLayers(borderRadius),
              Padding(
                padding: padding ?? EdgeInsets.zero,
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Frosted grey panel with white-dominant glass wash for the widgets sheet.
  static Widget widgetsPanelShell({
    required Widget child,
    required BorderRadius borderRadius,
    bool merged = false,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: merged
            ? null
            : Border.all(
                color: Colors.white.withValues(alpha: 0.84),
                width: 1,
              ),
        boxShadow: merged
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 20,
                  offset: const Offset(0, -6),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: AdaptiveGlassLayer(
          borderRadius: borderRadius,
          sigma: 24,
          fallbackColor: const Color(0xFFBCC2CB).withValues(alpha: 0.92),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ..._widgetsPanelBackdropLayers(borderRadius),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Faded fingerprint watermark (attendance reference).
class _AttendanceFingerprintOverlay extends StatelessWidget {
  const _AttendanceFingerprintOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: -12.w,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Opacity(
          opacity: 0.16,
          child: Image.asset(
            'assets/newapp/finger-print_svgrepo.com.png',
            width: 130.w,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
          ),
        ),
      ),
    );
  }
}

/// Geometric pattern on the right (full prayer card reference).
class _PrayerPatternOverlay extends StatelessWidget {
  const _PrayerPatternOverlay({this.opacity = 0.18});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: Image.asset(
            'assets/png/pray_decoration.png',
            width: 100.w,
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
          ),
        ),
      ),
    );
  }
}

/// Silver gradient + diagonal line texture for the home screen backdrop.
/// Includes a slow-moving very light navy wash across the top header zone.
class HomeSilverBackground extends StatefulWidget {
  const HomeSilverBackground({super.key, required this.child});

  final Widget child;

  static const _headerLinesAsset = 'assets/png/header_bg.png';
  static const _accentLinesAsset = 'assets/png/lines.png';

  @override
  State<HomeSilverBackground> createState() => _HomeSilverBackgroundState();
}

class _HomeSilverBackgroundState extends State<HomeSilverBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _navyDrift;

  @override
  void initState() {
    super.initState();
    _navyDrift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );
    if (!DeviceUiCapability.isLowEnd) {
      _navyDrift.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _navyDrift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: HomeGlassTheme.headerGradient,
          ),
        ),
        // Slow-moving very light navy wash over the top header band.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 320.h,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _navyDrift,
              builder: (context, _) {
                final t = Curves.easeInOut.transform(_navyDrift.value);
                final begin = Alignment(-1.2 + t * 0.9, -0.85);
                final end = Alignment(1.2 - t * 0.9, 0.65);
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: begin,
                      end: end,
                      colors: [
                        HomeGlassTheme.headerNavyMist.withValues(alpha: 0.55),
                        HomeGlassTheme.headerNavySoft.withValues(alpha: 0.38),
                        HomeGlassTheme.headerNavyHint.withValues(alpha: 0.22),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.28, 0.58, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.95,
              child: Image.asset(
                HomeSilverBackground._headerLinesAsset,
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 280.h,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.16),
                    Colors.white.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: -16.h,
          left: -12.w,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.72,
              child: Image.asset(
                HomeSilverBackground._accentLinesAsset,
                width: 240.w,
                fit: BoxFit.fitWidth,
                alignment: Alignment.topLeft,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: HomeNoiseOverlay(child: widget.child),
        ),
      ],
    );
  }
}

/// Subtle grain overlay for premium header feel.
/// Must wrap content so [CustomPaint] receives bounded dimensions.
class HomeNoiseOverlay extends StatelessWidget {
  const HomeNoiseOverlay({super.key, required this.child, this.opacity = 0.035});

  final Widget child;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    if (DeviceUiCapability.isLowEnd) {
      return child;
    }
    return CustomPaint(
      painter: _NoisePainter(opacity: opacity),
      child: child,
    );
  }
}

class _NoisePainter extends CustomPainter {
  _NoisePainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: opacity);
    const step = 3.0;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        if (((x * 13 + y * 7).toInt() & 3) == 0) {
          canvas.drawCircle(Offset(x, y), 0.45, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Concave scoop curve for the top of the white widgets panel.
class HomeConcaveTopClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const dipDepth = 18.0;
    final path = Path()
      ..moveTo(0, dipDepth)
      ..quadraticBezierTo(size.width * 0.5, -dipDepth, size.width, dipDepth)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
