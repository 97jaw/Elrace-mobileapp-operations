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
    this.useAlignment = FaceRecognitionPreprocess.useLandmarkAlignment,
    this.leftEyeX,
    this.leftEyeY,
    this.rightEyeX,
    this.rightEyeY,
  });

  final String imagePath;
  final double boxLeft;
  final double boxTop;
  final double boxRight;
  final double boxBottom;
  final bool useAlignment;
  final double? leftEyeX;
  final double? leftEyeY;
  final double? rightEyeX;
  final double? rightEyeY;

  factory FaceChipBuildRequest.fromCapture({
    required String imagePath,
    required Rect faceBox,
    TimesheetFaceLandmarkSnapshot? landmarks,
  }) {
    return FaceChipBuildRequest(
      imagePath: imagePath,
      boxLeft: faceBox.left,
      boxTop: faceBox.top,
      boxRight: faceBox.right,
      boxBottom: faceBox.bottom,
      leftEyeX: landmarks?.leftEye?.dx,
      leftEyeY: landmarks?.leftEye?.dy,
      rightEyeX: landmarks?.rightEye?.dx,
      rightEyeY: landmarks?.rightEye?.dy,
    );
  }

  Rect get faceBox =>
      Rect.fromLTRB(boxLeft, boxTop, boxRight, boxBottom);

  TimesheetFaceLandmarkSnapshot? toLandmarks() {
    if (leftEyeX == null ||
        leftEyeY == null ||
        rightEyeX == null ||
        rightEyeY == null) {
      return null;
    }
    return TimesheetFaceLandmarkSnapshot(
      boundingBox: faceBox,
      leftEye: Offset(leftEyeX!, leftEyeY!),
      rightEye: Offset(rightEyeX!, rightEyeY!),
    );
  }
}

/// 112×112 RGB bytes (row-major), or null on failure.
Future<Uint8List?> buildChipRgbBytesOffMainThread(FaceChipBuildRequest request) {
  if (!FaceRecognitionPerformance.useIsolateForPreprocess) {
    return Future(() => _buildChipRgbBytesSync(request));
  }
  return compute(_buildChipRgbBytesSync, request);
}

Uint8List? _buildChipRgbBytesSync(FaceChipBuildRequest request) {
  final bytes = File(request.imagePath).readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final oriented = img.bakeOrientation(decoded);
  const preprocessor = FacePreprocessor();
  final landmarks = request.useAlignment ? request.toLandmarks() : null;
  final chip = preprocessor.buildChip112FromImage(
    oriented,
    request.faceBox,
    landmarks: landmarks,
  );
  if (chip == null) return null;
  return _packRgb112(chip);
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
