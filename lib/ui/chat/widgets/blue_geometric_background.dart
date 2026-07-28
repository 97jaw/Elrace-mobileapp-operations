import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Full-screen gradient wallpaper for the chat / Discuss module.
/// Multi-layered radial/sweep gradient using light + dark blue shades.
class BlueGeometricBackground extends StatelessWidget {
  const BlueGeometricBackground({
    super.key,
    this.child,
    this.opacity = 1.0,
  });

  final Widget? child;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: CustomPaint(
              painter: _SmartGradientPainter(),
              willChange: false,
            ),
          ),
        ),
        if (child != null) Positioned.fill(child: child!),
      ],
    );
  }
}

class _SmartGradientPainter extends CustomPainter {
  // Light / cyan blues
  static const _lightCyan = Color(0xFF8FDEFD);
  static const _skyBlue = Color(0xFF90CAFD);
  static const _midBlue = Color(0xFF629DFB);
  static const _paleAqua = Color(0xFFBEE6FF);
  static const _lightAqua = Color(0xFFAAECFD);
  static const _brightBlue = Color(0xFF4983EE);
  static const _royalBlue = Color(0xFF5D9BFD);
  static const _brightCyan = Color(0xFF92E0FF);
  static const _softBlue = Color(0xFF85B7FC);

  // Darker blues (added for depth)
  static const _deepNavy = Color(0xFF273969);
  static const _steelBlue = Color(0xFF90A3D6);
  static const _slateBlue = Color(0xFF556795);
  static const _indigoBlue = Color(0xFF576EB3);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final w = size.width;
    final h = size.height;

    // Layer 1: Darker base (navy → slate → indigo)
    final baseGradient = ui.Gradient.linear(
      Offset.zero,
      Offset(w, h),
      [_slateBlue, _indigoBlue, _deepNavy, _slateBlue],
      [0.0, 0.3, 0.7, 1.0],
    );
    canvas.drawRect(rect, Paint()..shader = baseGradient);

    // Layer 2: Mid-tone steel wash
    final midWash = ui.Gradient.linear(
      Offset(w, 0),
      Offset(0, h),
      [
        _steelBlue.withValues(alpha: 0.55),
        _indigoBlue.withValues(alpha: 0.35),
        _deepNavy.withValues(alpha: 0.45),
      ],
      [0.0, 0.5, 1.0],
    );
    canvas.drawRect(rect, Paint()..shader = midWash);

    // Layer 3: Top-left light cyan glow
    final radial1 = ui.Gradient.radial(
      Offset(w * 0.12, h * 0.10),
      w * 0.70,
      [
        _lightCyan.withValues(alpha: 0.55),
        _brightCyan.withValues(alpha: 0.30),
        _skyBlue.withValues(alpha: 0.0),
      ],
      [0.0, 0.4, 1.0],
    );
    canvas.drawRect(rect, Paint()..shader = radial1);

    // Layer 4: Upper-right medium blue
    final radial2 = ui.Gradient.radial(
      Offset(w * 0.88, h * 0.28),
      w * 0.58,
      [
        _midBlue.withValues(alpha: 0.55),
        _royalBlue.withValues(alpha: 0.30),
        _indigoBlue.withValues(alpha: 0.0),
      ],
      [0.0, 0.5, 1.0],
    );
    canvas.drawRect(rect, Paint()..shader = radial2);

    // Layer 5: Bottom-left aqua → steel
    final radial3 = ui.Gradient.radial(
      Offset(w * 0.22, h * 0.78),
      w * 0.72,
      [
        _lightAqua.withValues(alpha: 0.40),
        _steelBlue.withValues(alpha: 0.35),
        _slateBlue.withValues(alpha: 0.0),
      ],
      [0.0, 0.45, 1.0],
    );
    canvas.drawRect(rect, Paint()..shader = radial3);

    // Layer 6: Bottom-right deep navy accent
    final radial4 = ui.Gradient.radial(
      Offset(w * 0.92, h * 0.88),
      w * 0.55,
      [
        _deepNavy.withValues(alpha: 0.75),
        _indigoBlue.withValues(alpha: 0.40),
        Colors.transparent,
      ],
      [0.0, 0.5, 1.0],
    );
    canvas.drawRect(rect, Paint()..shader = radial4);

    // Layer 7: Center soft blue glow
    final centerGlow = ui.Gradient.radial(
      Offset(w * 0.48, h * 0.48),
      w * 0.55,
      [
        _softBlue.withValues(alpha: 0.28),
        _brightBlue.withValues(alpha: 0.15),
        Colors.transparent,
      ],
      [0.0, 0.5, 1.0],
    );
    canvas.drawRect(rect, Paint()..shader = centerGlow);

    // Layer 8: Sweep blend across all tones
    final sweep = ui.Gradient.sweep(
      Offset(w * 0.5, h * 0.45),
      [
        _paleAqua.withValues(alpha: 0.18),
        _steelBlue.withValues(alpha: 0.22),
        _royalBlue.withValues(alpha: 0.16),
        _slateBlue.withValues(alpha: 0.20),
        _brightCyan.withValues(alpha: 0.15),
        _indigoBlue.withValues(alpha: 0.18),
        _paleAqua.withValues(alpha: 0.18),
      ],
      [0.0, 0.16, 0.33, 0.5, 0.66, 0.83, 1.0],
      TileMode.clamp,
      0,
      math.pi * 2,
    );
    canvas.drawRect(rect, Paint()..shader = sweep);

    // Layer 9: Soft top highlight (keeps some brightness)
    final topHighlight = ui.Gradient.linear(
      Offset(w * 0.25, 0),
      Offset(w * 0.75, h * 0.35),
      [
        _paleAqua.withValues(alpha: 0.28),
        _skyBlue.withValues(alpha: 0.12),
        Colors.transparent,
      ],
      [0.0, 0.45, 1.0],
    );
    canvas.drawRect(rect, Paint()..shader = topHighlight);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
