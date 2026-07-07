import 'dart:math' as math;
import 'dart:ui';

import 'package:el_race/core/site_management/face_recognition/antispoof/antispoof_config.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/timesheet_face_classification_snapshot.dart';
import 'package:flutter/foundation.dart';

/// Classical temporal cues — catches static photos and paused video clips.
class TemporalPadHeuristics {
  TemporalPadHeuristics({
    int? minSamples,
    double? maxFrameSimilarity,
    double? minYawVariance,
    double? minEyeVariance,
  })  : minSamples = minSamples ?? 8,
        maxFrameSimilarity = maxFrameSimilarity ?? 0.92,
        minYawVariance = minYawVariance ?? 0.35,
        minEyeVariance = minEyeVariance ?? 0.04;

  factory TemporalPadHeuristics.forBurst() => TemporalPadHeuristics(
        minSamples: AntispoofConfig.burstTemporalMinSamples,
        maxFrameSimilarity: AntispoofConfig.burstMaxFrameSimilarity,
        minYawVariance: AntispoofConfig.burstMinHeadMotionVariance,
        minEyeVariance: AntispoofConfig.burstMinEyeVariance,
      );

  factory TemporalPadHeuristics.forShutter() => TemporalPadHeuristics(
        minSamples: AntispoofConfig.preShutterFrameCount,
        maxFrameSimilarity: AntispoofConfig.burstMaxFrameSimilarity,
      );

  final int minSamples;
  final double maxFrameSimilarity;
  final double minYawVariance;
  final double minEyeVariance;

  final List<_FrameSample> _samples = [];

  void reset() => _samples.clear();

  void addSample({
    required TimesheetFaceClassificationSnapshot face,
    required Rect boundingBox,
  }) {
    final left = face.leftEyeOpenProbability;
    final right = face.rightEyeOpenProbability;
    final eyeAvg = (left != null && right != null) ? (left + right) / 2 : null;
    _samples.add(
      _FrameSample(
        box: boundingBox,
        yaw: face.headEulerAngleY ?? 0,
        pitch: face.headEulerAngleX ?? 0,
        eyeAvg: eyeAvg,
      ),
    );
    if (_samples.length > 24) {
      _samples.removeAt(0);
    }
  }

  TemporalPadVerdict evaluate() {
    if (_samples.length < minSamples) {
      return const TemporalPadVerdict(
        passed: false,
        reason: 'Collecting motion…',
        ready: false,
      );
    }

    final similarity = _avgBoxSimilarity();
    final yawVar = _variance(_samples.map((s) => s.yaw));
    final pitchVar = _variance(_samples.map((s) => s.pitch));
    final headMotion = yawVar + pitchVar;
    final eyeValues = _samples
        .map((s) => s.eyeAvg)
        .whereType<double>()
        .toList();
    final eyeVar =
        eyeValues.length >= minSamples ? _variance(eyeValues) : null;

    // High box IoU alone is normal when a live person holds still (~0.95+).
    // Only block when boxes are frozen AND head/eyes show no natural variation.
    final frozenBoxes = similarity > maxFrameSimilarity;
    final noHeadMotion = headMotion < minYawVariance;
    final noEyeMotion =
        eyeVar == null || eyeVar < minEyeVariance;

    if (frozenBoxes && noHeadMotion && noEyeMotion) {
      debugPrint(
        'TemporalPAD: static signature similarity=$similarity '
        'headMotion=$headMotion eyeVar=$eyeVar',
      );
      return const TemporalPadVerdict(
        passed: false,
        reason: 'Face appears static — use a live person at the camera',
        ready: true,
      );
    }

    return const TemporalPadVerdict(
      passed: true,
      reason: 'Motion check passed',
      ready: true,
    );
  }

  double _avgBoxSimilarity() {
    if (_samples.length < 2) return 0;
    var sum = 0.0;
    var count = 0;
    for (var i = 1; i < _samples.length; i++) {
      sum += _iou(_samples[i - 1].box, _samples[i].box);
      count++;
    }
    return count == 0 ? 0 : sum / count;
  }

  double _iou(Rect a, Rect b) {
    final inter = Rect.fromLTRB(
      math.max(a.left, b.left),
      math.max(a.top, b.top),
      math.min(a.right, b.right),
      math.min(a.bottom, b.bottom),
    );
    if (inter.width <= 0 || inter.height <= 0) return 0;
    final interArea = inter.width * inter.height;
    final union = a.width * a.height + b.width * b.height - interArea;
    return union <= 0 ? 0 : interArea / union;
  }

  double _variance(Iterable<double> values) {
    final list = values.toList();
    if (list.isEmpty) return 0;
    final mean = list.reduce((a, b) => a + b) / list.length;
    var sum = 0.0;
    for (final v in list) {
      sum += (v - mean) * (v - mean);
    }
    return sum / list.length;
  }
}

class TemporalPadVerdict {
  const TemporalPadVerdict({
    required this.passed,
    required this.reason,
    required this.ready,
  });

  final bool passed;
  final String reason;
  final bool ready;
}

class _FrameSample {
  _FrameSample({
    required this.box,
    required this.yaw,
    required this.pitch,
    required this.eyeAvg,
  });

  final Rect box;
  final double yaw;
  final double pitch;
  final double? eyeAvg;
}
