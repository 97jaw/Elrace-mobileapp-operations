import 'dart:ui';

import 'package:el_race/core/site_management/face_recognition/antispoof/antispoof_layer1.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/on_device_pad_evaluator.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/temporal_pad_heuristics.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/timesheet_face_classification_snapshot.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class BurstFrameSample {
  const BurstFrameSample({
    this.imagePath,
    this.rgbFrame,
    required this.faceBox,
    this.classification,
  }) : assert(
          imagePath != null || rgbFrame != null,
          'BurstFrameSample needs imagePath or rgbFrame',
        );

  /// Still-capture / legacy path (`ts_norm_*.jpg`). Prefer [rgbFrame] live.
  final String? imagePath;

  /// In-memory RGB from the camera stream (Task 1 — no JPEG).
  final img.Image? rgbFrame;
  final Rect faceBox;
  final TimesheetFaceClassificationSnapshot? classification;

  bool get hasTempFile =>
      imagePath != null && imagePath!.contains('ts_stream_');
}

class BurstVerificationResult {
  const BurstVerificationResult({
    required this.passed,
    required this.message,
    this.lastLayer1,
  });

  final bool passed;
  final String message;
  final Layer1Result? lastLayer1;
}

/// Runs multi-frame MiniFASNet + temporal heuristics on a short live burst.
class BurstVerificationPipeline {
  BurstVerificationPipeline({OnDevicePadEvaluator? pad})
      : _pad = pad ?? OnDevicePadEvaluator();

  final OnDevicePadEvaluator _pad;

  Future<BurstVerificationResult> verify(List<BurstFrameSample> frames) {
    return _verifyInternal(
      frames,
      temporal: TemporalPadHeuristics.forBurst(),
      requireTemporal: true,
      requireMultiFramePass: true,
    );
  }

  /// Pre-shutter / shutter integrity (fewer frames, temporal optional).
  Future<BurstVerificationResult> verifyIntegrity(
    List<BurstFrameSample> frames, {
    bool requireTemporal = true,
  }) {
    return _verifyInternal(
      frames,
      temporal: requireTemporal ? TemporalPadHeuristics.forShutter() : null,
      requireTemporal: requireTemporal,
      requireMultiFramePass: false,
    );
  }

  /// Single-frame replay screen check (duplicate vs spoof path).
  Future<BurstVerificationResult> verifySingleFrame(
    BurstFrameSample frame,
  ) async {
    final layer1 = await _evaluateSample(frame);
    if (layer1.verdict == Layer1Verdict.spoof) {
      return BurstVerificationResult(
        passed: false,
        message: layer1.message,
        lastLayer1: layer1,
      );
    }
    return BurstVerificationResult(
      passed: true,
      message: 'Live frame',
      lastLayer1: layer1,
    );
  }

  Future<Layer1Result> _evaluateSample(BurstFrameSample sample) {
    final rgb = sample.rgbFrame;
    if (rgb != null) {
      return _pad.evaluateImage(
        source: rgb,
        faceBox: sample.faceBox,
      );
    }
    return _pad.evaluateShutter(
      imagePath: sample.imagePath!,
      faceBox: sample.faceBox,
    );
  }

  Future<BurstVerificationResult> _verifyInternal(
    List<BurstFrameSample> frames, {
    TemporalPadHeuristics? temporal,
    required bool requireTemporal,
    required bool requireMultiFramePass,
  }) async {
    if (frames.isEmpty) {
      return const BurstVerificationResult(
        passed: false,
        message: 'No frames collected for verification',
      );
    }

    _pad.reset();
    temporal?.reset();
    OnDevicePadFrameResult? lastFrame;

    for (var i = 0; i < frames.length; i++) {
      final sample = frames[i];
      if (sample.classification != null && temporal != null) {
        temporal.addSample(
          face: sample.classification!,
          boundingBox: sample.faceBox,
        );
      }

      lastFrame = await _pad.evaluateFrameSample(
        imagePath: sample.imagePath,
        rgbFrame: sample.rgbFrame,
        faceBox: sample.faceBox,
        classification: sample.classification,
      );

      if (lastFrame.layer1.verdict == Layer1Verdict.spoof) {
        debugPrint('BurstVerification: spoof on frame ${i + 1}/${frames.length}');
        return BurstVerificationResult(
          passed: false,
          message: lastFrame.layer1.message,
          lastLayer1: lastFrame.layer1,
        );
      }
    }

    if (lastFrame == null) {
      return const BurstVerificationResult(
        passed: false,
        message: 'No frames collected for verification',
      );
    }

    if (requireTemporal && temporal != null) {
      final temporalVerdict = temporal.evaluate();
      if (temporalVerdict.ready && !temporalVerdict.passed) {
        debugPrint('BurstVerification: temporal failed — ${temporalVerdict.reason}');
        return BurstVerificationResult(
          passed: false,
          message: temporalVerdict.reason,
          lastLayer1: lastFrame.layer1,
        );
      }
      if (!temporalVerdict.ready) {
        debugPrint(
          'BurstVerification: temporal skipped — insufficient pose data, '
          'relying on PAD (${frames.length} frames)',
        );
      }
    }

    final padPassed = requireMultiFramePass ? lastFrame.passed : true;
    if (padPassed || !requireMultiFramePass) {
      if (!requireMultiFramePass ||
          lastFrame.layer1.verdict != Layer1Verdict.spoof) {
        debugPrint('BurstVerification: passed (${frames.length} frames)');
        return BurstVerificationResult(
          passed: true,
          message: 'Liveness verified',
          lastLayer1: lastFrame.layer1,
        );
      }
    }

    final reason = lastFrame.layer1.message.isNotEmpty
        ? lastFrame.layer1.message
        : 'Liveness check did not pass — retry';
    debugPrint('BurstVerification: failed — $reason');
    return BurstVerificationResult(
      passed: false,
      message: reason,
      lastLayer1: lastFrame.layer1,
    );
  }
}
