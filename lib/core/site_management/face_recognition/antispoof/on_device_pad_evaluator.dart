import 'dart:ui';

import 'package:el_race/core/site_management/face_recognition/antispoof/antispoof_config.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/antispoof_layer1.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/temporal_pad_heuristics.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/timesheet_face_classification_snapshot.dart';
import 'package:flutter/foundation.dart';

class OnDevicePadFrameResult {
  const OnDevicePadFrameResult({
    required this.passed,
    required this.layer1,
  });

  final bool passed;
  final Layer1Result layer1;
}

/// Multi-frame MiniFASNet + temporal heuristics (Tier 1).
class OnDevicePadEvaluator {
  OnDevicePadEvaluator({
    AntispoofLayer1? layer1,
    TemporalPadHeuristics? temporal,
  })  : _layer1 = layer1 ?? AntispoofLayer1(),
        _temporal = temporal ?? TemporalPadHeuristics();

  final AntispoofLayer1 _layer1;
  final TemporalPadHeuristics _temporal;
  final List<bool> _recentPasses = [];

  void reset() {
    _recentPasses.clear();
    _temporal.reset();
  }

  Future<OnDevicePadFrameResult> evaluateFrame({
    required String imagePath,
    required Rect faceBox,
    TimesheetFaceClassificationSnapshot? classification,
  }) async {
    final layer1 = await _layer1.evaluate(imagePath: imagePath, faceBox: faceBox);
    final framePass = layer1.verdict != Layer1Verdict.spoof &&
        layer1.verdict != Layer1Verdict.error;

    _recentPasses.add(framePass);
    if (_recentPasses.length > AntispoofConfig.multiFrameWindow) {
      _recentPasses.removeAt(0);
    }

    if (classification != null) {
      _temporal.addSample(face: classification, boundingBox: faceBox);
    }

    final passCount = _recentPasses.where((p) => p).length;
    final multiOk =
        passCount >= AntispoofConfig.multiFramePassRequired;

    TemporalPadVerdict? temporalVerdict;
    if (classification != null && multiOk) {
      temporalVerdict = _temporal.evaluate();
    }

    if (!framePass) {
      return OnDevicePadFrameResult(passed: false, layer1: layer1);
    }
    if (!multiOk) {
      debugPrint('OnDevicePAD: multi-frame $passCount/${AntispoofConfig.multiFramePassRequired}');
      return OnDevicePadFrameResult(passed: false, layer1: layer1);
    }
    if (temporalVerdict != null &&
        temporalVerdict.ready &&
        !temporalVerdict.passed) {
      return OnDevicePadFrameResult(
        passed: false,
        layer1: Layer1Result(
          verdict: Layer1Verdict.spoof,
          fused: layer1.fused,
          message: temporalVerdict.reason,
        ),
      );
    }

    return OnDevicePadFrameResult(passed: true, layer1: layer1);
  }

  Future<Layer1Result> evaluateShutter({
    required String imagePath,
    required Rect faceBox,
  }) {
    return _layer1.evaluate(imagePath: imagePath, faceBox: faceBox);
  }
}
