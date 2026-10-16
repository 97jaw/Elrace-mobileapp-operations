import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:el_race/core/site_management/face_recognition/domain/face_alignment.dart';
import 'package:el_race/core/site_management/face_recognition/domain/face_preprocessor.dart';
import 'package:el_race/core/timesheet/services/face_capture_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

const _ref = FaceAlignment.reference;

/// Known similarity placing the reference face somewhere in a camera frame.
FaceSimilarityTransform _place(double deg, double scale, double tx, double ty) {
  final r = deg * math.pi / 180;
  return FaceSimilarityTransform(
    scale * math.cos(r),
    scale * math.sin(r),
    tx,
    ty,
  );
}

double _dist(Offset a, Offset b) => (a - b).distance;

img.Image _noise(int w, int h, int seed) {
  final rnd = math.Random(seed);
  final out = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      out.setPixelRgb(
          x, y, rnd.nextInt(256), rnd.nextInt(256), rnd.nextInt(256));
    }
  }
  return out;
}

void main() {
  group('estimate', () {
    test('reference landmarks give the identity transform', () {
      final t = FaceAlignment.estimate(_ref, _ref)!;
      expect(t.a, closeTo(1, 1e-9));
      expect(t.b, closeTo(0, 1e-9));
      expect(t.tx, closeTo(0, 1e-6));
      expect(t.ty, closeTo(0, 1e-6));
    });

    test('identity warp leaves a 112×112 image unchanged', () {
      final src = _noise(112, 112, 1);
      final t = FaceAlignment.estimate(_ref, _ref)!;
      final out = FaceAlignment.warp(src, t);
      var maxDiff = 0;
      for (var y = 0; y < 112; y++) {
        for (var x = 0; x < 112; x++) {
          final a = src.getPixel(x, y);
          final b = out.getPixel(x, y);
          maxDiff = math.max(maxDiff, (a.r - b.r).abs().toInt());
          maxDiff = math.max(maxDiff, (a.g - b.g).abs().toInt());
          maxDiff = math.max(maxDiff, (a.b - b.b).abs().toInt());
        }
      }
      expect(maxDiff, lessThanOrEqualTo(1));
    });

    for (final c in [
      (deg: 0.0, scale: 1.0, tx: 40.0, ty: -12.0),
      (deg: 17.0, scale: 2.4, tx: 210.0, ty: 140.0),
      (deg: -32.0, scale: 0.6, tx: 15.0, ty: 300.0),
      (deg: 90.0, scale: 3.1, tx: 500.0, ty: 60.0),
    ]) {
      test(
          'rotated ${c.deg}° scaled ${c.scale} translated '
          '(${c.tx}, ${c.ty}) lands within 1 px', () {
        final placed = _place(c.deg, c.scale, c.tx, c.ty);
        final src = [for (final p in _ref) placed.apply(p)];
        final t = FaceAlignment.estimate(src, _ref)!;
        for (var i = 0; i < 5; i++) {
          expect(_dist(t.apply(src[i]), _ref[i]), lessThan(1.0));
        }
        expect(t.scale, closeTo(1 / c.scale, 1e-6));
      });
    }

    test('collapsed landmarks are degenerate', () {
      const p = Offset(100, 100);
      expect(FaceAlignment.estimate([p, p, p, p, p], _ref), isNull);
    });

    test('warped image puts landmark dots on the reference', () {
      final placed = _place(21, 3.0, 260, 120);
      final src = [for (final p in _ref) placed.apply(p)];
      final frame = img.Image(width: 720, height: 640);
      for (final p in src) {
        for (var dy = -4; dy <= 4; dy++) {
          for (var dx = -4; dx <= 4; dx++) {
            frame.setPixelRgb(
                p.dx.round() + dx, p.dy.round() + dy, 255, 255, 255);
          }
        }
      }
      final t = FaceAlignment.estimate(src, _ref)!;
      final chip = FaceAlignment.warp(frame, t);
      for (final r in _ref) {
        final p = chip.getPixel(r.dx.round(), r.dy.round());
        expect(p.r, greaterThan(200), reason: 'dot at $r');
      }
    });

    test('pixels outside the source are black', () {
      final src = img.Image(width: 50, height: 50);
      img.fill(src, color: img.ColorRgb8(255, 255, 255));
      final chip =
          FaceAlignment.warp(src, const FaceSimilarityTransform(1, 0, 0, 0));
      expect(chip.getPixel(10, 10).r, 255);
      expect(chip.getPixel(100, 100).r, 0);
    });
  });

  group('sourcePoints', () {
    test('orders eyes and mouth by x, not by ML Kit name', () {
      // ML Kit "left" = subject's left = image-right.
      final pts = FaceAlignment.sourcePoints(
        eyeA: const Offset(300, 200),
        eyeB: const Offset(200, 205),
        nose: const Offset(250, 250),
        mouthA: const Offset(290, 300),
        mouthB: const Offset(210, 302),
      )!;
      expect(pts, const [
        Offset(200, 205),
        Offset(300, 200),
        Offset(250, 250),
        Offset(210, 302),
        Offset(290, 300),
      ]);
    });

    test('same result when labels are not swapped', () {
      final a = FaceAlignment.sourcePoints(
        eyeA: const Offset(200, 205),
        eyeB: const Offset(300, 200),
        nose: const Offset(250, 250),
        mouthA: const Offset(210, 302),
        mouthB: const Offset(290, 300),
      );
      final b = FaceAlignment.sourcePoints(
        eyeA: const Offset(300, 200),
        eyeB: const Offset(200, 205),
        nose: const Offset(250, 250),
        mouthA: const Offset(290, 300),
        mouthB: const Offset(210, 302),
      );
      expect(a, b);
    });

    test('missing landmark gives null', () {
      expect(
        FaceAlignment.sourcePoints(
          eyeA: const Offset(200, 205),
          eyeB: const Offset(300, 200),
          nose: null,
          mouthA: const Offset(210, 302),
          mouthB: const Offset(290, 300),
        ),
        isNull,
      );
    });
  });

  group('preprocessor', () {
    const pre = FacePreprocessor();
    final placed = _place(-8, 2.2, 180, 90);
    final src = [for (final p in _ref) placed.apply(p)];
    final box = Rect.fromLTRB(
        src[0].dx - 60, src[0].dy - 90, src[1].dx + 60, src[3].dy + 50);
    // ML Kit labels: subject's left eye is image-right.
    final landmarks = TimesheetFaceLandmarkSnapshot(
      boundingBox: box,
      leftEye: src[1],
      rightEye: src[0],
      nose: src[2],
      mouthLeft: src[4],
      mouthRight: src[3],
    );
    final frame = _noise(640, 480, 7);

    test('5-point crop is used when all landmarks exist', () {
      final r = pre.buildChip112FromImage(frame, box,
          landmarks: landmarks, crop: FaceChipCrop.fivePoint)!;
      expect(r.align, FaceChipAlign.fivePoint);
      expect(r.chip.width, 112);
      expect(r.chip.height, 112);
    });

    test('legacy crop when asked for legacy', () {
      final r = pre.buildChip112FromImage(frame, box,
          landmarks: landmarks, crop: FaceChipCrop.legacy)!;
      expect(r.align, FaceChipAlign.legacy);
    });

    test('missing landmark falls back to the legacy crop', () {
      final partial = TimesheetFaceLandmarkSnapshot(
        boundingBox: box,
        leftEye: src[1],
        rightEye: src[0],
      );
      final r = pre.buildChip112FromImage(frame, box,
          landmarks: partial, crop: FaceChipCrop.fivePoint)!;
      expect(r.align, FaceChipAlign.fallback);
      final legacy = pre.buildChip112FromImage(frame, box,
          landmarks: partial, crop: FaceChipCrop.legacy)!;
      expect(
        pre.buildInputTensorFromRgbChip(r.chip),
        pre.buildInputTensorFromRgbChip(legacy.chip),
      );
    });

    test('same image twice gives the same tensor (cosine ≥ 0.99)', () {
      final a = pre.buildInputTensorFromImage(
          source: frame,
          faceBox: box,
          landmarks: landmarks,
          crop: FaceChipCrop.fivePoint)!;
      final b = pre.buildInputTensorFromImage(
          source: frame,
          faceBox: box,
          landmarks: landmarks,
          crop: FaceChipCrop.fivePoint)!;
      var dot = 0.0, na = 0.0, nb = 0.0;
      for (var i = 0; i < a.tensor.length; i++) {
        dot += a.tensor[i] * b.tensor[i];
        na += a.tensor[i] * a.tensor[i];
        nb += b.tensor[i] * b.tensor[i];
      }
      expect(dot / math.sqrt(na * nb), greaterThanOrEqualTo(0.99));
    });
  });
}
