import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Offset, Rect;

import 'package:el_race/core/site_management/face_recognition/domain/face_preprocessor.dart';
import 'package:el_race/core/site_management/face_recognition/face_recognition_config.dart';
import 'package:el_race/core/timesheet/services/face_capture_service.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Serializable capture geometry for [compute] (P.1 — keep decode/crop off UI thread).
class FaceChipBuildRequest {
  const FaceChipBuildRequest({
    required this.imagePath,
    required this.boxLeft,
    required this.boxTop,
    required this.boxRight,
    required this.boxBottom,
    required this.crop,
    this.leftEye,
    this.rightEye,
    this.nose,
    this.mouthLeft,
    this.mouthRight,
  });

  final String imagePath;
  final double boxLeft;
  final double boxTop;
  final double boxRight;
  final double boxBottom;
  final FaceChipCrop crop;
  final Offset? leftEye;
  final Offset? rightEye;
  final Offset? nose;
  final Offset? mouthLeft;
  final Offset? mouthRight;

  factory FaceChipBuildRequest.fromCapture({
    required String imagePath,
    required Rect faceBox,
    required FaceChipCrop crop,
    TimesheetFaceLandmarkSnapshot? landmarks,
  }) {
    return FaceChipBuildRequest(
      imagePath: imagePath,
      boxLeft: faceBox.left,
      boxTop: faceBox.top,
      boxRight: faceBox.right,
      boxBottom: faceBox.bottom,
      crop: crop,
      leftEye: landmarks?.leftEye,
      rightEye: landmarks?.rightEye,
      nose: landmarks?.nose,
      mouthLeft: landmarks?.mouthLeft,
      mouthRight: landmarks?.mouthRight,
    );
  }

  Rect get faceBox => Rect.fromLTRB(boxLeft, boxTop, boxRight, boxBottom);

  TimesheetFaceLandmarkSnapshot toLandmarks() => TimesheetFaceLandmarkSnapshot(
        boundingBox: faceBox,
        leftEye: leftEye,
        rightEye: rightEye,
        nose: nose,
        mouthLeft: mouthLeft,
        mouthRight: mouthRight,
      );
}

/// 112×112 RGB bytes (row-major) and the crop used.
class FaceChipRgb {
  const FaceChipRgb(this.rgb, this.align);

  final Uint8List rgb;
  final FaceChipAlign align;
}

/// Chip bytes, or null on failure.
Future<FaceChipRgb?> buildChipRgbBytesOffMainThread(
  FaceChipBuildRequest request,
) {
  if (!FaceRecognitionPerformance.useIsolateForPreprocess) {
    return Future(() => _buildChipRgbBytesSync(request));
  }
  return compute(_buildChipRgbBytesSync, request);
}

FaceChipRgb? _buildChipRgbBytesSync(FaceChipBuildRequest request) {
  final bytes = File(request.imagePath).readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final oriented = img.bakeOrientation(decoded);
  const preprocessor = FacePreprocessor();
  final chip = preprocessor.buildChip112FromImage(
    oriented,
    request.faceBox,
    landmarks: request.toLandmarks(),
    crop: request.crop,
  );
  if (chip == null) return null;
  return FaceChipRgb(_packRgb112(chip.chip), chip.align);
}

Uint8List _packRgb112(img.Image chip) {
  final w = FaceRecognitionPreprocess.inputWidth;
  final h = FaceRecognitionPreprocess.inputHeight;
  final out = Uint8List(w * h * 3);
  var i = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = chip.getPixel(x, y);
      out[i++] = p.r.toInt();
      out[i++] = p.g.toInt();
      out[i++] = p.b.toInt();
    }
  }
  return out;
}
