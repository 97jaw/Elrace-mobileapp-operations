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
  });

  final Layer1Verdict verdict;
  final MinifasnetFusedScores? fused;
  final String message;

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
  }) async {
    try {
      final fused = await _engine.scoreImageFile(
        imagePath: imagePath,
        faceBox: faceBox,
      );
      if (fused == null) {
        return const Layer1Result(
          verdict: Layer1Verdict.error,
          fused: null,
          message: 'Could not analyze face for liveness.',
        );
      }

      _logScores(fused);

      final liveProb = fused.probabilities[AntispoofConfig.liveClassIndex];
      final attackSum = _attackProbabilitySum(fused);
      if (attackSum >= AntispoofConfig.spoofAttackSumThreshold) {
        return Layer1Result(
          verdict: Layer1Verdict.spoof,
          fused: fused,
          message:
              'Replay or print attack detected. Use your real face at the camera.',
        );
      }
      if (fused.label != AntispoofClassLabel.live) {
        return Layer1Result(
          verdict: Layer1Verdict.spoof,
          fused: fused,
          message: 'Spoofing detected. Use your real face, not a photo or screen.',
        );
      }
      if (liveProb >= AntispoofConfig.liveConfidenceThreshold) {
        return Layer1Result(
          verdict: Layer1Verdict.live,
          fused: fused,
          message: 'Live face confirmed.',
        );
      }
      if (liveProb >= AntispoofConfig.liveUncertainFloor) {
        return Layer1Result(
          verdict: Layer1Verdict.uncertain,
          fused: fused,
          message: 'Live face uncertain — AWS liveness required.',
        );
      }
      return Layer1Result(
        verdict: Layer1Verdict.spoof,
        fused: fused,
        message: 'Spoofing detected. Use your real face, not a photo or screen.',
      );
    } catch (e, st) {
      debugPrint('AntispoofLayer1 error: $e\n$st');
      return Layer1Result(
        verdict: Layer1Verdict.error,
        fused: null,
        message: 'Liveness check failed. Try again.',
      );
    }
  }

  Future<Layer1Result> evaluateImage({
    required img.Image source,
    required Rect faceBox,
  }) async {
    try {
      final fused = await _engine.scoreFace(source: source, faceBox: faceBox);
      if (fused == null) {
        return const Layer1Result(
          verdict: Layer1Verdict.error,
          fused: null,
          message: 'Could not analyze face for liveness.',
        );
      }
      _logScores(fused);
      final liveProb = fused.probabilities[AntispoofConfig.liveClassIndex];
      final attackSum = _attackProbabilitySum(fused);
      if (attackSum >= AntispoofConfig.spoofAttackSumThreshold) {
        return Layer1Result(
          verdict: Layer1Verdict.spoof,
          fused: fused,
          message:
              'Replay or print attack detected. Use your real face at the camera.',
        );
      }
      if (fused.label != AntispoofClassLabel.live) {
        return Layer1Result(
          verdict: Layer1Verdict.spoof,
          fused: fused,
          message: 'Spoofing detected. Use your real face, not a photo or screen.',
        );
      }
      if (liveProb >= AntispoofConfig.liveConfidenceThreshold) {
        return Layer1Result(
          verdict: Layer1Verdict.live,
          fused: fused,
          message: 'Live face confirmed.',
        );
      }
      if (liveProb >= AntispoofConfig.liveUncertainFloor) {
        return Layer1Result(
          verdict: Layer1Verdict.uncertain,
          fused: fused,
          message: 'Live face uncertain — AWS liveness required.',
        );
      }
      return Layer1Result(
        verdict: Layer1Verdict.spoof,
        fused: fused,
        message: 'Spoofing detected. Use your real face, not a photo or screen.',
      );
    } catch (e, st) {
      debugPrint('AntispoofLayer1 error: $e\n$st');
      return Layer1Result(
        verdict: Layer1Verdict.error,
        fused: null,
        message: 'Liveness check failed. Try again.',
      );
    }
  }

  double _attackProbabilitySum(MinifasnetFusedScores fused) {
    final p = fused.probabilities;
    if (p.length < 3) return 0;
    return p[AntispoofConfig.printAttackClassIndex] +
        p[AntispoofConfig.replayAttackClassIndex];
  }

  void _logScores(MinifasnetFusedScores fused) {
    final p = fused.probabilities
        .map((v) => v.toStringAsFixed(3))
        .join(', ');
    debugPrint(
      'AntiSpoof L1: fused=[$p] label=${fused.label.name} '
      'conf=${fused.confidence.toStringAsFixed(3)} '
      'v2=${fused.modelV2.map((v) => v.toStringAsFixed(2)).join(',')} '
      'v1se=${fused.modelV1Se.map((v) => v.toStringAsFixed(2)).join(',')}',
    );
  }
}
