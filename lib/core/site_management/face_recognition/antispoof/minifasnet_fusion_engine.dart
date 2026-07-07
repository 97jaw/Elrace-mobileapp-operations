import 'dart:math' as math;
import 'dart:ui';

import 'package:el_race/core/site_management/face_recognition/antispoof/antispoof_config.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/minifasnet_preprocessor.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

enum AntispoofClassLabel {
  spoofType0,
  live,
  spoofType2,
}

class MinifasnetFusedScores {
  const MinifasnetFusedScores({
    required this.probabilities,
    required this.label,
    required this.confidence,
    required this.modelV2,
    required this.modelV1Se,
  });

  final List<double> probabilities;
  final AntispoofClassLabel label;
  final double confidence;
  final List<double> modelV2;
  final List<double> modelV1Se;
}

/// Dual MiniFASNet inference with fused softmax (Silent-Face-Anti-Spoofing style).
class MinifasnetFusionEngine {
  MinifasnetFusionEngine._();
  static final MinifasnetFusionEngine instance = MinifasnetFusionEngine._();

  final MinifasnetPreprocessor _preprocessor = const MinifasnetPreprocessor();
  Interpreter? _v2;
  Interpreter? _v1Se;
  Future<void>? _loadFuture;

  Future<void> ensureLoaded() {
    _loadFuture ??= _load();
    return _loadFuture!;
  }

  Future<void> _load() async {
    if (_v2 != null && _v1Se != null) return;
    final options = InterpreterOptions()..threads = 2;
    _v2 = await Interpreter.fromAsset(
      AntispoofConfig.modelV2Asset,
      options: options,
    );
    _v1Se = await Interpreter.fromAsset(
      AntispoofConfig.modelV1SeAsset,
      options: options,
    );
    debugPrint('MinifasnetFusionEngine: models loaded');
  }

  Future<MinifasnetFusedScores?> scoreFace({
    required img.Image source,
    required Rect faceBox,
  }) async {
    await ensureLoaded();
    final v2Input = _preprocessor.buildInput(
      source: source,
      faceBox: faceBox,
      cropScale: AntispoofConfig.modelV2CropScale,
    );
    final v1Input = _preprocessor.buildInput(
      source: source,
      faceBox: faceBox,
      cropScale: AntispoofConfig.modelV1SeCropScale,
    );
    if (v2Input == null || v1Input == null) return null;

    final v2Probs = _runModel(_v2!, v2Input);
    final v1Probs = _runModel(_v1Se!, v1Input);
    final fused = List<double>.generate(AntispoofConfig.numClasses, (i) {
      return (v2Probs[i] + v1Probs[i]) / 2;
    });
    final labelIndex = _argmax(fused);
    return MinifasnetFusedScores(
      probabilities: fused,
      label: _labelFromIndex(labelIndex),
      confidence: fused[labelIndex],
      modelV2: v2Probs,
      modelV1Se: v1Probs,
    );
  }

  Future<MinifasnetFusedScores?> scoreImageFile({
    required String imagePath,
    required Rect faceBox,
  }) async {
    final bytes = await img.decodeImageFile(imagePath);
    if (bytes == null) return null;
    return scoreFace(source: bytes, faceBox: faceBox);
  }

  List<double> _runModel(Interpreter interpreter, Float32List nhwc) {
    final input = nhwc.reshape([
      1,
      AntispoofConfig.inputSize,
      AntispoofConfig.inputSize,
      3,
    ]);
    final output = [List<double>.filled(AntispoofConfig.numClasses, 0.0)];
    interpreter.run(input, output);
    return _softmax(List<double>.from(output[0]));
  }

  List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce(math.max);
    final exps = logits.map((v) => math.exp(v - maxLogit)).toList();
    final sum = exps.fold<double>(0, (a, b) => a + b);
    return exps.map((e) => e / sum).toList();
  }

  int _argmax(List<double> values) {
    var best = 0;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > values[best]) best = i;
    }
    return best;
  }

  AntispoofClassLabel _labelFromIndex(int index) {
    switch (index) {
      case AntispoofConfig.liveClassIndex:
        return AntispoofClassLabel.live;
      case 0:
        return AntispoofClassLabel.spoofType0;
      default:
        return AntispoofClassLabel.spoofType2;
    }
  }

  void dispose() {
    _v2?.close();
    _v1Se?.close();
    _v2 = null;
    _v1Se = null;
    _loadFuture = null;
  }
}
