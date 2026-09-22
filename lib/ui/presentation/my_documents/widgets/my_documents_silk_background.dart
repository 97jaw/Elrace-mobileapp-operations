import 'dart:math' as math;

import 'package:flutter/material.dart';

/// My Documents wash — reference diamond tiles, not a 4-corner mirror.
///
/// Layout (matches the screenshot):
/// - Top-left: almost empty
/// - Top-right: large, faint overlapping tiles
/// - Bottom-right: densest cluster + one solid pop
/// - Bottom-left: fewer, bigger, paler tiles
/// Colors: sky blue + light maroon (not a 1:1 copy of each side).
class MyDocumentsSilkBackground extends StatelessWidget {
  const MyDocumentsSilkBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFFFFFFFF)),
        const Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _DiamondClusterPainter()),
          ),
        ),
        child,
      ],
    );
  }
}

class _DiamondSpec {
  const _DiamondSpec({
    required this.ax,
    required this.ay,
    required this.size,
    required this.color,
    this.alpha = 0.22,
    this.solid = false,
  });

  final double ax;
  final double ay;
  final double size;
  final Color color;
  final double alpha;
  final bool solid;
}

class _DiamondClusterPainter extends CustomPainter {
  const _DiamondClusterPainter();

  static const _sky = Color(0xFF6EA8DC);
  static const _skyMid = Color(0xFFA8CFF0);
  static const _skySoft = Color(0xFFD6ECFA);
  static const _maroon = Color(0xFFC98996);
  static const _maroonMid = Color(0xFFD9A8B2);
  static const _maroonSoft = Color(0xFFF0DCE0);

  /// Asymmetric — different count / size / opacity per corner.
  static const _diamonds = <_DiamondSpec>[
    // Top-left — almost empty; one faint maroon wash only.
    _DiamondSpec(
      ax: -0.14,
      ay: -0.10,
      size: 380,
      color: _maroonSoft,
      alpha: 0.26,
    ),

    // Top-right — large pale sky cluster (reference).
    _DiamondSpec(ax: 0.88, ay: -0.14, size: 520, color: _skySoft, alpha: 0.36),
    _DiamondSpec(ax: 1.10, ay: 0.06, size: 420, color: _skySoft, alpha: 0.30),
    _DiamondSpec(ax: 0.68, ay: 0.00, size: 330, color: _skyMid, alpha: 0.32),
    _DiamondSpec(ax: 0.98, ay: 0.20, size: 250, color: _skySoft, alpha: 0.38),
    _DiamondSpec(ax: 0.80, ay: 0.16, size: 190, color: _skyMid, alpha: 0.34),
    _DiamondSpec(ax: 1.14, ay: 0.24, size: 160, color: _maroonSoft, alpha: 0.28),

    // Bottom-left — fewer, bigger, paler maroon (not a copy of other sides).
    _DiamondSpec(ax: -0.16, ay: 1.00, size: 500, color: _maroonSoft, alpha: 0.32),
    _DiamondSpec(ax: 0.14, ay: 1.10, size: 350, color: _maroonMid, alpha: 0.30),
    _DiamondSpec(ax: 0.30, ay: 0.86, size: 220, color: _maroonSoft, alpha: 0.34),

    // Bottom-right — densest + one solid sky pop (reference).
    _DiamondSpec(ax: 1.06, ay: 1.02, size: 440, color: _skySoft, alpha: 0.34),
    _DiamondSpec(ax: 0.80, ay: 1.10, size: 310, color: _skyMid, alpha: 0.32),
    _DiamondSpec(ax: 0.58, ay: 0.90, size: 220, color: _skySoft, alpha: 0.36),
    _DiamondSpec(ax: 0.96, ay: 0.76, size: 180, color: _maroonSoft, alpha: 0.30),
    _DiamondSpec(ax: 0.74, ay: 0.78, size: 150, color: _skyMid, alpha: 0.38),
    _DiamondSpec(ax: 1.12, ay: 0.70, size: 120, color: _skySoft, alpha: 0.32),
    _DiamondSpec(
      ax: 0.70,
      ay: 0.74,
      size: 124,
      color: _sky,
      alpha: 0.92,
      solid: true,
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final spec in _diamonds) {
      _drawDiamond(canvas, size, spec);
    }
  }

  void _drawDiamond(Canvas canvas, Size size, _DiamondSpec spec) {
    final cx = spec.ax * size.width;
    final cy = spec.ay * size.height;
    final radius = spec.size * 0.24;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(math.pi / 4);

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: spec.size, height: spec.size),
      Radius.circular(radius),
    );

    if (spec.solid) {
      canvas.drawRRect(
        rect.shift(const Offset(2.5, 4.5)),
        Paint()
          ..color = const Color(0x18000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = spec.color.withValues(alpha: spec.alpha),
      );
    } else {
      canvas.drawRRect(
        rect,
        Paint()..color = spec.color.withValues(alpha: spec.alpha),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
