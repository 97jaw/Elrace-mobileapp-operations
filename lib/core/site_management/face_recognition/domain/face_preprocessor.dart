import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'package:el_race/core/site_management/face_recognition/domain/face_chip_isolate.dart';
import 'package:el_race/core/site_management/face_recognition/face_recognition_config.dart';
import 'package:el_race/core/timesheet/services/face_capture_service.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Lambda-parity chip: padded bbox → 112×112 RGB → normalized NHWC float tensor.
class FacePreprocessor {
  const FacePreprocessor();

  /// P.1 — tensor from isolate-packed 112×112 RGB bytes.
  Float32List buildInputTensorFromRgbBytes(Uint8List rgb112) {
    final expected = FaceRecognitionPreprocess.inputHeight *
        FaceRecognitionPreprocess.inputWidth *
        FaceRecognitionPreprocess.inputChannels;
    if (rgb112.length != expected) {
      throw ArgumentError('rgb112 length ${rgb112.length}, expected $expected');
    }
    final tensor = Float32List(expected);
    var i = 0;
    for (var j = 0; j < expected; j += 3) {
      tensor[i++] =
          FaceRecognitionPreprocess.normalizePixel(rgb112[j].toDouble());
      tensor[i++] =
          FaceRecognitionPreprocess.normalizePixel(rgb112[j + 1].toDouble());
      tensor[i++] =
          FaceRecognitionPreprocess.normalizePixel(rgb112[j + 2].toDouble());
    }
    return tensor;
  }

  Future<Float32List?> buildInputTensorFromCaptureAsync({
    required String imagePath,
    required Rect faceBox,
    TimesheetFaceLandmarkSnapshot? landmarks,
  }) async {
    final request = FaceChipBuildRequest.fromCapture(
      imagePath: imagePath,
      faceBox: faceBox,
      landmarks: landmarks,
    );
    final rgb = await buildChipRgbBytesOffMainThread(request);
    if (rgb == null) return null;
    return buildInputTensorFromRgbBytes(rgb);
  }

  Float32List buildInputTensorFromRgbChip(img.Image chip112) {
    if (chip112.width != FaceRecognitionPreprocess.inputWidth ||
        chip112.height != FaceRecognitionPreprocess.inputHeight) {
      throw ArgumentError(
        'expected ${FaceRecognitionPreprocess.inputWidth}x'
        '${FaceRecognitionPreprocess.inputHeight}, got ${chip112.width}x${chip112.height}',
      );
    }
    final rgb = _toRgb(chip112);
    final n = FaceRecognitionPreprocess.inputHeight *
        FaceRecognitionPreprocess.inputWidth *
        FaceRecognitionPreprocess.inputChannels;
    final tensor = Float32List(n);
    var i = 0;
    for (var y = 0; y < FaceRecognitionPreprocess.inputHeight; y++) {
      for (var x = 0; x < FaceRecognitionPreprocess.inputWidth; x++) {
        final p = rgb.getPixel(x, y);
        tensor[i++] = FaceRecognitionPreprocess.normalizePixel(p.r.toDouble());
        tensor[i++] = FaceRecognitionPreprocess.normalizePixel(p.g.toDouble());
        tensor[i++] = FaceRecognitionPreprocess.normalizePixel(p.b.toDouble());
      }
    }
    return tensor;
  }

  /// Largest-face bbox with optional P.3 eye alignment → 112×112 RGB.
  img.Image? buildChip112FromImage(
    img.Image source,
    Rect faceBox, {
    TimesheetFaceLandmarkSnapshot? landmarks,
  }) {
    if (FaceRecognitionPreprocess.useLandmarkAlignment &&
        landmarks != null &&
        landmarks.leftEye != null &&
        landmarks.rightEye != null) {
      final aligned = _chipFromEyeAlignment(source, landmarks);
      if (aligned != null) {
        debugPrint('FacePreprocessor: P.3 eye alignment applied');
        return aligned;
      }
      debugPrint('FacePreprocessor: alignment failed — bbox fallback');
    }
    return _chipFromBoundingBox(source, faceBox);
  }

  img.Image? _chipFromBoundingBox(img.Image source, Rect faceBox) {
    final pad = math.max(faceBox.width, faceBox.height) *
        FaceRecognitionPreprocess.lambdaPadFraction;
    final left = math.max(0.0, faceBox.left - pad);
    final top = math.max(0.0, faceBox.top - pad);
    final right = math.min(
      source.width.toDouble(),
      faceBox.right + pad,
    );
    final bottom = math.min(
      source.height.toDouble(),
      faceBox.bottom + pad,
    );
    final w = (right - left).round();
    final h = (bottom - top).round();
    if (w < 8 || h < 8) return null;
    final cropped = img.copyCrop(
      source,
      x: left.round(),
      y: top.round(),
      width: w,
      height: h,
    );
    return img.copyResize(
      cropped,
      width: FaceRecognitionPreprocess.inputWidth,
      height: FaceRecognitionPreprocess.inputHeight,
      interpolation: img.Interpolation.average,
    );
  }

  img.Image? _chipFromEyeAlignment(
    img.Image source,
    TimesheetFaceLandmarkSnapshot landmarks,
  ) {
    final left = landmarks.leftEye!;
    final right = landmarks.rightEye!;
    final box = landmarks.boundingBox;
    final pad = math.max(box.width, box.height) *
        FaceRecognitionPreprocess.lambdaPadFraction;
    final leftX = math.max(0.0, box.left - pad).round();
    final topY = math.max(0.0, box.top - pad).round();
    final rightX = math.min(source.width.toDouble(), box.right + pad).round();
    final bottomY = math.min(source.height.toDouble(), box.bottom + pad).round();
    final w = rightX - leftX;
    final h = bottomY - topY;
    if (w < 8 || h < 8) return null;

    final cropped = img.copyCrop(source, x: leftX, y: topY, width: w, height: h);
    final leftLocal = Offset(left.dx - leftX, left.dy - topY);
    final rightLocal = Offset(right.dx - leftX, right.dy - topY);
    final dx = rightLocal.dx - leftLocal.dx;
    final dy = rightLocal.dy - leftLocal.dy;
    if (dx.abs() < 2) return null;

    final angleRad = math.atan2(dy, dx);
    final angleDeg = angleRad * 180 / math.pi;
    final rotated = img.copyRotate(cropped, angle: -angleDeg);
    return img.copyResize(
      rotated,
      width: FaceRecognitionPreprocess.inputWidth,
      height: FaceRecognitionPreprocess.inputHeight,
      interpolation: img.Interpolation.average,
    );
  }

  Future<img.Image?> buildChip112FromFile(
    String imagePath,
    Rect faceBox, {
    TimesheetFaceLandmarkSnapshot? landmarks,
  }) async {
    final fileBytes = await File(imagePath).readAsBytes();
    final bytes = img.decodeImage(fileBytes);
    if (bytes == null) return null;
    final oriented = img.bakeOrientation(bytes);
    return buildChip112FromImage(oriented, faceBox, landmarks: landmarks);
  }

  img.Image _toRgb(img.Image src) {
    if (src.numChannels == 3) return src;
    final out = img.Image(width: src.width, height: src.height);
    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final p = src.getPixel(x, y);
        out.setPixelRgb(x, y, p.r, p.g, p.b);
      }
    }
    return out;
  }
}
