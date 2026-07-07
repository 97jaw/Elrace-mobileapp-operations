import 'package:el_race/ui/presentation/timesheet/widgets/face_recognition/tm_face_mesh_painter.dart';
import 'package:flutter/material.dart';

/// iPhone-style face oval with dimmed surround.
class FmFaceEnrollOvalOverlay extends StatelessWidget {
  const FmFaceEnrollOvalOverlay({
    super.key,
    required this.frameColor,
    this.instruction,
  });

  final Color frameColor;
  final String? instruction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final ovalW = w * 0.72;
        final ovalH = h * 0.48;
        final left = (w - ovalW) / 2;
        final top = h * 0.22;

        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _OvalCutoutPainter(
                rect: Rect.fromLTWH(left, top, ovalW, ovalH),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: ovalW,
              height: ovalH,
              child: CustomPaint(
                painter: _EnrollMeshPainter(color: frameColor),
              ),
            ),
            if (instruction != null)
              Positioned(
                left: 24,
                right: 24,
                top: top + ovalH + 20,
                child: Text(
                  instruction!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OvalCutoutPainter extends CustomPainter {
  _OvalCutoutPainter({required this.rect});

  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    final overlay = Path()..addRect(Offset.zero & size);
    final hole = Path()
      ..addOval(Rect.fromCenter(
        center: rect.center,
        width: rect.width,
        height: rect.height,
      ));
    final cut = Path.combine(PathOperation.difference, overlay, hole);
    canvas.drawPath(
      cut,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(covariant _OvalCutoutPainter oldDelegate) =>
      oldDelegate.rect != rect;
}

class _EnrollMeshPainter extends CustomPainter {
  const _EnrollMeshPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final box = Offset.zero & size;
    TmFaceMeshPainter.paintFaceMesh(
      canvas: canvas,
      faceBox: box,
      color: color,
    );
  }

  @override
  bool shouldRepaint(covariant _EnrollMeshPainter oldDelegate) =>
      oldDelegate.color != color;
}
