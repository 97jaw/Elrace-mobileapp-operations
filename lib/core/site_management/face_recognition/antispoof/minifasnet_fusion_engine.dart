import 'dart:math' as math;
import 'dart:ui';

import 'package:el_race/core/site_management/face_recognition/antispoof/antispoof_config.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/minifasnet_preprocessor.dart';
import 'package:el_race/core/site_management/face_recognition/tflite_interpreter_factory.dart';
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

/// Dual MiniFASNet — interpreters created once, tensors pinned.
///
/// Same rule as [FaceEmbedder]: never feed nested Lists through [Interpreter.run]
/// (that can resize + re-allocateTensors + re-apply XNNPACK every call).
class MinifasnetFusionEngine {
  MinifasnetFusionEngine._();
  static final MinifasnetFusionEngine instance = MinifasnetFusionEngine._();

  final MinifasnetPreprocessor _preprocessor = const MinifasnetPreprocessor();
  Interpreter? _v2;
  Interpreter? _v1Se;
  Future<void>? _loadFuture;
  int _loadCount = 0;
  int _inferenceCount = 0;

  Future<void> ensureLoaded() {
    _loadFuture ??= _load();
    return _loadFuture!;
  }

  Future<void> _load() async {
    if (_v2 != null && _v1Se != null) return;
    // Task 0 finish — never rebuild mid-session (causes Replacing 65… again).
    if (_loadCount > 0) {
      debugPrint(
        'MinifasnetFusionEngine: refusing reload (already load#$_loadCount)',
      );
      return;
    }

    // Separate creates via factory (CPU default; XNNPACK only if safe).
    const fasShape = [1, AntispoofConfig.inputSize, AntispoofConfig.inputSize, 3];
    _v2 = await TfliteInterpreterFactory.fromAsset(
      AntispoofConfig.modelV2Asset,
      fixedInputShape: fasShape,
      preferXnnpack: false,
    );
    _v1Se = await TfliteInterpreterFactory.fromAsset(
      AntispoofConfig.modelV1SeAsset,
      fixedInputShape: fasShape,
      preferXnnpack: false,
    );
    _loadCount += 1;
    debugPrint(
      'MinifasnetFusionEngine: INTERPRETER_CACHED load#$_loadCount '
      'backend=${TfliteInterpreterFactory.backendLabel} '
      'v2=${AntispoofConfig.modelV2Asset} '
      'v1se=${AntispoofConfig.modelV1SeAsset}',
    );
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

    _inferenceCount += 1;
    if (_inferenceCount == 1 || _inferenceCount % 50 == 0) {
      debugPrint(
        'MinifasnetFusionEngine: invoke ok pair#$_inferenceCount '
        '(load#$_loadCount — must stay 1)',
      );
    }

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
    final inputBytes = nhwc.buffer.asUint8List(
      nhwc.offsetInBytes,
      nhwc.lengthInBytes,
    );
    interpreter.getInputTensor(0).data = inputBytes;
    interpreter.invoke();
    final outBytes = interpreter.getOutputTensor(0).data;
    final outFloats = outBytes.buffer.asFloat32List(
      outBytes.offsetInBytes,
      AntispoofConfig.numClasses,
    );
    return _softmax(
      List<double>.generate(
        AntispoofConfig.numClasses,
        (i) => outFloats[i].toDouble(),
      ),
    );
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

  /// Prefer process-lifetime reuse. Closing mid-session re-applies XNNPACK.
  void dispose() {
    debugPrint(
      'MinifasnetFusionEngine: dispose ignored — keep load#$_loadCount cached',
    );
  }
}
