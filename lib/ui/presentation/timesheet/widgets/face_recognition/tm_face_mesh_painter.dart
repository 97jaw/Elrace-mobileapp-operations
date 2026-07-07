import 'dart:math' as math;

import 'package:el_race/core/timesheet/services/face_capture_service.dart';
import 'package:flutter/material.dart';

/// Wireframe face mesh + name badge (attendance + enrollment overlays).
class TmFaceMeshPainter {
  TmFaceMeshPainter._();

  static const Color inTeam = Color(0xFF3DDC84);
  static const Color outOfTeam = Color(0xFFFFB74D);
  static const Color duplicate = Color(0xFF42A5F5);
  static const Color neutral = Colors.white;

  static const double _lineWidth = 0.65;
  static const double _lineAlpha = 0.28;
  static const double _dotRadius = 1.85;
  static const double _dotAlpha = 0.82;

  static void paintFaceMesh({
    required Canvas canvas,
    required Rect faceBox,
    required Color color,
    TimesheetFaceLandmarkSnapshot? landmarks,
  }) {
    final contours = landmarks?.meshContours ?? const <List<Offset>>[];
    final polylines =
        contours.isNotEmpty ? contours : _syntheticFullFaceContours(faceBox);

    _paintLandmarkFrame(canvas, polylines, color);
    _paintSparseStructure(canvas, polylines, color);
  }

  /// Thin faded contour lines + small landmark dots (no filled mask look).
  static void _paintLandmarkFrame(
    Canvas canvas,
    List<List<Offset>> contours,
    Color color,
  ) {
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: _dotAlpha);

    for (var ci = 0; ci < contours.length; ci++) {
      final contour = contours[ci];
      if (contour.length < 2) continue;

      final isOuterFace = ci == 0;
      final outerLine = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _lineWidth
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: isOuterFace ? 0.22 : _lineAlpha);

      for (var i = 0; i < contour.length - 1; i++) {
        canvas.drawLine(contour[i], contour[i + 1], outerLine);
      }

      final dotStep = contour.length > 16 ? 2 : 1;
      for (var i = 0; i < contour.length; i += dotStep) {
        canvas.drawCircle(contour[i], _dotRadius, dotPaint);
      }
    }
  }

  /// A few structural links — subtle, not a dense triangulation mask.
  static void _paintSparseStructure(
    Canvas canvas,
    List<List<Offset>> contours,
    Color color,
  ) {
    if (contours.length < 2) return;

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.55
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.18);

    final face = contours.first;
    if (face.length >= 6) {
      _link(canvas, linePaint, face[face.length ~/ 6], _centroid(contours[1]));
      _link(
        canvas,
        linePaint,
        face[(face.length * 5) ~/ 6],
        _centroid(contours.length > 2 ? contours[2] : contours[1]),
      );
    }

    if (contours.length >= 7) {
      final leftEye = _centroid(contours[5]);
      final rightEye = _centroid(contours[6]);
      final nose = contours.length > 7 ? _centroid(contours[7]) : null;
      _link(canvas, linePaint, leftEye, rightEye);
      if (nose != null) {
        _link(canvas, linePaint, leftEye, nose);
        _link(canvas, linePaint, rightEye, nose);
      }
    }
  }

  static void _link(Canvas canvas, Paint paint, Offset? a, Offset? b) {
    if (a == null || b == null) return;
    canvas.drawLine(a, b, paint);
  }

  static Offset? _centroid(List<Offset> points) {
    if (points.isEmpty) return null;
    var x = 0.0;
    var y = 0.0;
    for (final p in points) {
      x += p.dx;
      y += p.dy;
    }
    return Offset(x / points.length, y / points.length);
  }

  static void paintNameBadge({
    required Canvas canvas,
    required Rect faceBox,
    required Color badgeColor,
    required String name,
    String? fileId,
    double maxWidth = 280,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final idLine = fileId?.trim();
    final spans = <TextSpan>[
      TextSpan(
        text: trimmed,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          height: 1.15,
        ),
      ),
      if (idLine != null && idLine.isNotEmpty)
        TextSpan(
          text: '\n$idLine',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
    ];

    final textPainter = TextPainter(
      text: TextSpan(children: spans),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: maxWidth);

    const padH = 14.0;
    const padV = 8.0;
    final badgeW = textPainter.width + padH * 2;
    final badgeH = textPainter.height + padV * 2;
    final left = faceBox.center.dx - badgeW / 2;
    final top = math.max(8.0, faceBox.top - badgeH - 12);
    final badgeRect = Rect.fromLTWH(left, top, badgeW, badgeH);

    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(999)),
      Paint()
        ..color = badgeColor.withValues(alpha: 0.94)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(999)),
      Paint()..color = badgeColor.withValues(alpha: 0.94),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(999)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.35),
    );

    textPainter.paint(
      canvas,
      Offset(
        badgeRect.left + (badgeRect.width - textPainter.width) / 2,
        badgeRect.top + padV,
      ),
    );
  }

  /// Full-face synthetic contours for enrollment oval / missing ML Kit data.
  static List<List<Offset>> _syntheticFullFaceContours(Rect box) {
    final cx = box.center.dx;
    final cy = box.center.dy;
    final hw = box.width * 0.5;
    final hh = box.height * 0.5;
    Offset p(double rx, double ry) => Offset(cx + hw * rx, cy + hh * ry);

    List<Offset> arc(
      int count,
      double start,
      double sweep,
      double rx,
      double ry,
    ) {
      return List.generate(count, (i) {
        final t = start + (sweep * i / (count - 1));
        return Offset(cx + hw * rx * math.cos(t), cy + hh * ry * math.sin(t));
      });
    }

    return [
      arc(20, -math.pi * 0.92, math.pi * 1.84, 0.96, 1.08),
      arc(6, -math.pi * 0.78, math.pi * 0.22, 0.42, 0.52)
          .map((o) => Offset(o.dx - hw * 0.28, o.dy - hh * 0.18))
          .toList(),
      arc(6, -math.pi * 0.22, math.pi * 0.22, 0.42, 0.52)
          .map((o) => Offset(o.dx + hw * 0.28, o.dy - hh * 0.18))
          .toList(),
      arc(8, 0, math.pi * 2, 0.22, 0.12)
          .map((o) => Offset(o.dx - hw * 0.28, o.dy - hh * 0.08))
          .toList(),
      arc(8, 0, math.pi * 2, 0.22, 0.12)
          .map((o) => Offset(o.dx + hw * 0.28, o.dy - hh * 0.08))
          .toList(),
      [p(0, -0.12), p(0, 0.02), p(0, 0.18), p(-0.08, 0.24), p(0.08, 0.24)],
      arc(8, math.pi * 0.08, math.pi * 0.84, 0.28, 0.14)
          .map((o) => Offset(o.dx, o.dy + hh * 0.28))
          .toList(),
      arc(8, -math.pi * 0.92, math.pi * 0.84, 0.26, 0.1)
          .map((o) => Offset(o.dx, o.dy + hh * 0.34))
          .toList(),
    ];
  }
}

/// Scale image-space landmarks to screen-space [faceBox].
TimesheetFaceLandmarkSnapshot? scaleLandmarks({
  required TimesheetFaceLandmarkSnapshot? source,
  required Rect imageBox,
  required Rect screenBox,
}) {
  if (source == null) return null;
  final sx = screenBox.width / imageBox.width;
  final sy = screenBox.height / imageBox.height;
  Offset? map(Offset? p) {
    if (p == null) return null;
    return Offset(
      screenBox.left + (p.dx - imageBox.left) * sx,
      screenBox.top + (p.dy - imageBox.top) * sy,
    );
  }

  List<List<Offset>> mapContours(List<List<Offset>> contours) {
    return contours
        .map(
          (contour) => contour
              .map(
                (p) => Offset(
                  screenBox.left + (p.dx - imageBox.left) * sx,
                  screenBox.top + (p.dy - imageBox.top) * sy,
                ),
              )
              .toList(growable: false),
        )
        .toList(growable: false);
  }

  return TimesheetFaceLandmarkSnapshot(
    boundingBox: screenBox,
    leftEye: map(source.leftEye),
    rightEye: map(source.rightEye),
    nose: map(source.nose),
    leftCheek: map(source.leftCheek),
    rightCheek: map(source.rightCheek),
    mouthLeft: map(source.mouthLeft),
    mouthRight: map(source.mouthRight),
    mouthBottom: map(source.mouthBottom),
    leftEar: map(source.leftEar),
    rightEar: map(source.rightEar),
    meshContours: mapContours(source.meshContours),
  );
}
