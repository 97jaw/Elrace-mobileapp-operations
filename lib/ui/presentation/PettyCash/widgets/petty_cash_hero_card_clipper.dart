import 'package:flutter/material.dart';

/// Clipper that cuts a pill-shaped pocket in the bottom-right of the card.
///
/// The button is a separate widget placed in the pocket; [notchPadding] is the
/// gap where the parent background shows through.
class CardWithButtonNotchClipper extends CustomClipper<Path> {
  const CardWithButtonNotchClipper({
    required this.cardRadius,
    required this.buttonWidth,
    required this.buttonHeight,
    required this.notchPadding,
  });

  final double cardRadius;
  final double buttonWidth;
  final double buttonHeight;
  final double notchPadding;

  double get notchWidth => buttonWidth + notchPadding * 2;

  double get notchHeight => buttonHeight + notchPadding * 2;

  double get notchRadius => notchHeight / 2;

  /// Where the button should be placed inside the card stack (top-left).
  Offset buttonOffset(Size cardSize) {
    final gap = notchPadding;
    return Offset(
      cardSize.width - notchWidth + gap,
      cardSize.height - notchHeight + gap,
    );
  }

  Path pathFor(Size size) => getClip(size);

  @override
  Path getClip(Size size) {
    final path = Path();
    final r = cardRadius;
    final w = size.width;
    final h = size.height;
    final nw = notchWidth;
    final nh = notchHeight;
    final nr = notchRadius;
    final notchTop = h - nh;
    final notchLeftCapX = w - nw + nr;

    // Clockwise from top-left — only one pocket cut (bottom-right pill).
    path.moveTo(r, 0);
    path.lineTo(w - r, 0);
    path.arcToPoint(Offset(w, r), radius: Radius.circular(r));

    // Straight right edge — no secondary inward arc (that caused the ghost cut).
    path.lineTo(w, notchTop);

    // Along the top of the notch pocket.
    path.lineTo(notchLeftCapX, notchTop);

    // Single half-pill arc around the button's left cap.
    path.arcToPoint(
      Offset(notchLeftCapX, h),
      radius: Radius.circular(nr),
      clockwise: false,
    );

    path.lineTo(r, h);
    path.arcToPoint(Offset(0, h - r), radius: Radius.circular(r));
    path.lineTo(0, r);
    path.arcToPoint(Offset(r, 0), radius: Radius.circular(r));
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CardWithButtonNotchClipper oldClipper) {
    return oldClipper.cardRadius != cardRadius ||
        oldClipper.buttonWidth != buttonWidth ||
        oldClipper.buttonHeight != buttonHeight ||
        oldClipper.notchPadding != notchPadding;
  }
}

/// Shadow + thin white stroke + clipped card content.
class PettyCashHeroCardShell extends StatelessWidget {
  const PettyCashHeroCardShell({
    super.key,
    required this.clipper,
    required this.child,
    this.borderColor,
    this.borderWidth = 1.1,
  });

  final CardWithButtonNotchClipper clipper;
  final Widget child;
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final stroke = borderColor ?? Colors.white.withValues(alpha: 0.38);

    return RepaintBoundary(
      child: CustomPaint(
        painter: _NotchedShadowPainter(clipper: clipper),
        foregroundPainter: _NotchedBorderPainter(
          clipper: clipper,
          color: stroke,
          strokeWidth: borderWidth,
        ),
        child: ClipPath(
          clipper: clipper,
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    );
  }
}

class _NotchedShadowPainter extends CustomPainter {
  _NotchedShadowPainter({required this.clipper});

  final CardWithButtonNotchClipper clipper;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawShadow(
      clipper.pathFor(size),
      Colors.black.withValues(alpha: 0.38),
      22,
      false,
    );
  }

  @override
  bool shouldRepaint(covariant _NotchedShadowPainter oldDelegate) {
    return oldDelegate.clipper.cardRadius != clipper.cardRadius ||
        oldDelegate.clipper.buttonWidth != clipper.buttonWidth;
  }
}

class _NotchedBorderPainter extends CustomPainter {
  _NotchedBorderPainter({
    required this.clipper,
    required this.color,
    required this.strokeWidth,
  });

  final CardWithButtonNotchClipper clipper;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color
      ..isAntiAlias = true
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(clipper.pathFor(size), paint);
  }

  @override
  bool shouldRepaint(covariant _NotchedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.clipper.cardRadius != clipper.cardRadius;
  }
}

// Keep alias for any legacy imports.
typedef PettyCashHeroCardShadow = PettyCashHeroCardShell;
