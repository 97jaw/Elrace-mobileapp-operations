import 'dart:ui';

import 'package:el_race/core/site_management/face_recognition/antispoof/antispoof_config.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/minifasnet_fusion_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

enum Layer1Verdict {
  live,
  uncertain,
  spoof,
  error,
}

class Layer1Result {
  const Layer1Result({
    required this.verdict,
    required this.fused,
    required this.message,
    this.reason,
  });

  final Layer1Verdict verdict;
  final MinifasnetFusedScores? fused;
  final String message;

  /// Short machine reason for logs (e.g. model_disagree, fused_mid_band).
  final String? reason;

  bool get allowsProceed =>
      verdict == Layer1Verdict.live || verdict == Layer1Verdict.uncertain;

  @Deprecated('Use allowsProceed')
  bool get allowsChallenge => allowsProceed;
}

class AntispoofLayer1 {
  AntispoofLayer1({MinifasnetFusionEngine? engine})
      : _engine = engine ?? MinifasnetFusionEngine.instance;

  final MinifasnetFusionEngine _engine;

  Future<Layer1Result> evaluate({
    required String imagePath,
    required Rect faceBox,
    double? yawDeg,
  }) async {
    try {
      final fused = await _engine.scoreImageFile(
        imagePath: imagePath,
        faceBox: faceBox,
        yawDeg: yawDeg,
      );
      if (fused == null) {
        return const Layer1Result(
          verdict: Layer1Verdict.error,
          fused: null,
          message: 'Could not analyze face for liveness.',
          reason: 'score_null',
        );
      }
      return _verdictFromFused(fused);
    } catch (e, st) {
      debugPrint('AntispoofLayer1 error: $e\n$st');
      return const Layer1Result(
        verdict: Layer1Verdict.error,
        fused: null,
        message: 'Liveness check failed. Try again.',
        reason: 'exception',
      );
    }
  }

  Future<Layer1Result> evaluateImage({
    required img.Image source,
    required Rect faceBox,
    double? yawDeg,
  }) async {
    try {
      final fused = await _engine.scoreFace(
        source: source,
        faceBox: faceBox,
        yawDeg: yawDeg,
      );
      if (fused == null) {
        return const Layer1Result(
          verdict: Layer1Verdict.error,
          fused: null,
          message: 'Could not analyze face for liveness.',
          reason: 'score_null',
        );
      }
      return _verdictFromFused(fused);
    } catch (e, st) {
      debugPrint('AntispoofLayer1 error: $e\n$st');
      return const Layer1Result(
        verdict: Layer1Verdict.error,
        fused: null,
        message: 'Liveness check failed. Try again.',
        reason: 'exception',
      );
    }
  }

  /// Best-frame / burst verdict bands (live threshold 0.70 unchanged):
  /// - live: fused live >= 0.70 and print+replay < [maxLiveAttackSum]
  /// - spoof: both models' live < 0.50, OR fused live < 0.50
  /// - uncertain: anything else (model disagree, mid band) — no window reset
  Layer1Result _verdictFromFused(MinifasnetFusedScores fused) {
    final p = fused.probabilities;
    if (p.length < 3) {
      return const Layer1Result(
        verdict: Layer1Verdict.error,
        fused: null,
        message: 'Could not analyze face for liveness.',
        reason: 'bad_probs',
      );
    }

    final liveProb = p[AntispoofConfig.liveClassIndex];
    final attackSum = _attackProbabilitySum(fused);
    final v2Live = _modelLive(fused.modelV2);
    final v1Live = _modelLive(fused.modelV1Se);

    // Live (unchanged threshold): only these count toward min live frames.
    if (liveProb >= AntispoofConfig.liveConfidenceThreshold &&
        attackSum < AntispoofConfig.maxLiveAttackSum &&
        fused.label == AntispoofClassLabel.live) {
      _logScores(fused, verdict: Layer1Verdict.live, reason: 'live');
      return Layer1Result(
        verdict: Layer1Verdict.live,
        fused: fused,
        message: 'Live face confirmed.',
        reason: 'live',
      );
    }

    // Spoof band → zero-spoof reset / attack message.
    final bothModelsSpoof =
        v2Live < AntispoofConfig.modelLiveSpoofBand &&
            v1Live < AntispoofConfig.modelLiveSpoofBand;
    final fusedSpoof = liveProb < AntispoofConfig.fusedLiveSpoofBand;
    if (bothModelsSpoof || fusedSpoof) {
      final reason = bothModelsSpoof ? 'both_models_spoof' : 'fused_live_low';
      _logScores(fused, verdict: Layer1Verdict.spoof, reason: reason);
      return Layer1Result(
        verdict: Layer1Verdict.spoof,
        fused: fused,
        message:
            'Presentation attack detected — use live face',
        reason: reason,
      );
    }

    // Uncertain: model disagree / mid band — do not reset window.
    final reason = _uncertainReason(
      liveProb: liveProb,
      v2Live: v2Live,
      v1Live: v1Live,
      attackSum: attackSum,
    );
    _logScores(fused, verdict: Layer1Verdict.uncertain, reason: reason);
    return Layer1Result(
      verdict: Layer1Verdict.uncertain,
      fused: fused,
      message: 'Hold still — checking liveness.',
      reason: reason,
    );
  }

  String _uncertainReason({
    required double liveProb,
    required double v2Live,
    required double v1Live,
    required double attackSum,
  }) {
    final v2LiveVote = v2Live >= AntispoofConfig.liveConfidenceThreshold;
    final v1LiveVote = v1Live >= AntispoofConfig.liveConfidenceThreshold;
    final v2SpoofVote = v2Live < AntispoofConfig.modelLiveSpoofBand;
    final v1SpoofVote = v1Live < AntispoofConfig.modelLiveSpoofBand;
    if ((v2LiveVote && v1SpoofVote) || (v1LiveVote && v2SpoofVote)) {
      return 'model_disagree';
    }
    if (attackSum >= AntispoofConfig.maxLiveAttackSum) {
      return 'attack_sum_mid';
    }
    if (liveProb >= AntispoofConfig.fusedLiveSpoofBand &&
        liveProb < AntispoofConfig.liveConfidenceThreshold) {
      return 'fused_mid_band';
    }
    return 'uncertain';
  }

  double _modelLive(List<double> probs) {
    if (probs.length <= AntispoofConfig.liveClassIndex) return 0;
    return probs[AntispoofConfig.liveClassIndex];
  }

  double _attackProbabilitySum(MinifasnetFusedScores fused) {
    final p = fused.probabilities;
    if (p.length < 3) return 0;
    return p[AntispoofConfig.printAttackClassIndex] +
        p[AntispoofConfig.replayAttackClassIndex];
  }

  void _logScores(
    MinifasnetFusedScores fused, {
    required Layer1Verdict verdict,
    required String reason,
  }) {
    final p = fused.probabilities
        .map((v) => v.toStringAsFixed(3))
        .join(', ');
    final v2 = fused.modelV2.isEmpty
        ? '-'
        : fused.modelV2.map((v) => v.toStringAsFixed(2)).join(',');
    final v1 = fused.modelV1Se.isEmpty
        ? '-'
        : fused.modelV1Se.map((v) => v.toStringAsFixed(2)).join(',');
    debugPrint(
      'AntiSpoof L1: fused=[$p] label=${fused.label.name} '
      'conf=${fused.confidence.toStringAsFixed(3)} '
      'v2=$v2 v1se=$v1 verdict=${verdict.name} reason=$reason',
    );
  }
}
