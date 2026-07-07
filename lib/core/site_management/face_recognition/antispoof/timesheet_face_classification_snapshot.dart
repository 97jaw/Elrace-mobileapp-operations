import 'dart:ui';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// ML Kit classification fields needed for active liveness challenges.
class TimesheetFaceClassificationSnapshot {
  const TimesheetFaceClassificationSnapshot({
    required this.boundingBox,
    this.leftEyeOpenProbability,
    this.rightEyeOpenProbability,
    this.headEulerAngleX,
    this.headEulerAngleY,
    this.headEulerAngleZ,
    this.smilingProbability,
    this.trackingId,
  });

  final Rect boundingBox;
  final double? leftEyeOpenProbability;
  final double? rightEyeOpenProbability;
  final double? headEulerAngleX;
  final double? headEulerAngleY;
  final double? headEulerAngleZ;
  final double? smilingProbability;
  final int? trackingId;

  factory TimesheetFaceClassificationSnapshot.fromFace(Face face) {
    return TimesheetFaceClassificationSnapshot(
      boundingBox: face.boundingBox,
      leftEyeOpenProbability: face.leftEyeOpenProbability,
      rightEyeOpenProbability: face.rightEyeOpenProbability,
      headEulerAngleX: face.headEulerAngleX,
      headEulerAngleY: face.headEulerAngleY,
      headEulerAngleZ: face.headEulerAngleZ,
      smilingProbability: face.smilingProbability,
      trackingId: face.trackingId,
    );
  }
}
