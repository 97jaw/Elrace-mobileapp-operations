import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:el_race/core/site_management/face_recognition/android_face_capture_perf.dart';
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
/// Android: plain CPU + 4 threads + [IsolateInterpreter] per model
/// (known-good path; ByteBuffer workers removed after allocate-flag crash).
/// iOS: ByteBuffer + invoke (untouched).
class MinifasnetFusionEngine {
  MinifasnetFusionEngine._();
  static final MinifasnetFusionEngine instance = MinifasnetFusionEngine._();

  final MinifasnetPreprocessor _preprocessor = const MinifasnetPreprocessor();
  Interpreter? _v2;
  Interpreter? _v1Se;
  IsolateInterpreter? _v2Isolate;
  IsolateInterpreter? _v1SeIsolate;
  Future<void>? _loadFuture;
  int _loadCount = 0;
  int _inferenceCount = 0;
  bool _loggedBackendOnce = false;

  /// Last fused pair invoke time (ms); for BestFrame perf logs.
  int lastInferenceMs = 0;

  String get invokeMode =>
      Platform.isAndroid ? 'isolateInterpreter' : 'mainByteBuffer';

  final List<List<double>> _v2Out = [
    List<double>.filled(AntispoofConfig.numClasses, 0.0),
  ];
  final List<List<double>> _v1Out = [
    List<double>.filled(AntispoofConfig.numClasses, 0.0),
  ];

  Future<void> ensureLoaded() {
    _loadFuture ??= _load().catchError((Object e, StackTrace st) {
      _loadFuture = null;
      Error.throwWithStackTrace(e, st);
    });
    return _loadFuture!;
  }

  Future<void> _load() async {
    if (_v2 != null && _v1Se != null) return;
    if (_loadCount > 0) {
      debugPrint(
        'MinifasnetFusionEngine: refusing reload (already load#$_loadCount)',
      );
      return;
    }

    final android = Platform.isAndroid;
    final threads = android ? AndroidFaceCapturePerf.tfliteThreads : null;
    const fasShape = [1, AntispoofConfig.inputSize, AntispoofConfig.inputSize, 3];
    _v2 = await TfliteInterpreterFactory.fromAsset(
      AntispoofConfig.modelV2Asset,
      fixedInputShape: fasShape,
      preferXnnpack: false,
      numThreads: threads,
    );
    _v1Se = await TfliteInterpreterFactory.fromAsset(
      AntispoofConfig.modelV1SeAsset,
      fixedInputShape: fasShape,
      preferXnnpack: false,
      numThreads: threads,
    );
    if (android) {
      _v2Isolate = await IsolateInterpreter.create(
        address: _v2!.address,
        debugName: 'MiniFASNetV2Isolate',
      );
      _v1SeIsolate = await IsolateInterpreter.create(
        address: _v1Se!.address,
        debugName: 'MiniFASNetV1SeIsolate',
      );
    }
    _loadCount += 1;
    debugPrint(
      'MinifasnetFusionEngine: INTERPRETER_CACHED load#$_loadCount '
      'v2_backend=${TfliteInterpreterFactory.backendFor(AntispoofConfig.modelV2Asset)} '
      'v1se_backend=${TfliteInterpreterFactory.backendFor(AntispoofConfig.modelV1SeAsset)} '
      'invoke=$invokeMode threads=${threads ?? "default"} '
      'sequentialPad=${AndroidFaceCapturePerf.sequentialPad} '
      'lowEnd=${AndroidFaceCapturePerf.isLowEnd} '
      'v2=${AntispoofConfig.modelV2Asset} '
      'v1se=${AntispoofConfig.modelV1SeAsset}',
    );
  }

  Future<MinifasnetFusedScores?> scoreFace({
    required img.Image source,
    required Rect faceBox,
    double? yawDeg,
  }) async {
    await ensureLoaded();
    final v2Input = _preprocessor.buildInput(
      source: source,
      faceBox: faceBox,
      cropScale: AntispoofConfig.modelV2CropScale,
      model: 'v2',
      yawDeg: yawDeg,
    );
    final v1Input = _preprocessor.buildInput(
      source: source,
      faceBox: faceBox,
      cropScale: AntispoofConfig.modelV1SeCropScale,
      model: 'v1se',
      yawDeg: yawDeg,
    );
    if (v2Input == null || v1Input == null) return null;
    return _scoreFromInputs(v2Input, v1Input);
  }

  Future<MinifasnetFusedScores?> scoreImageFile({
    required String imagePath,
    required Rect faceBox,
    double? yawDeg,
  }) async {
    final bytes = await img.decodeImageFile(imagePath);
    if (bytes == null) return null;
    return scoreFace(source: bytes, faceBox: faceBox, yawDeg: yawDeg);
  }

  Future<MinifasnetFusedScores?> _scoreFromInputs(
    Float32List v2Input,
    Float32List v1Input,
  ) async {
    final sw = Stopwatch()..start();
    late final List<double> v2Probs;
    late final List<double> v1Probs;
    var v2Ms = 0;
    var v1Ms = 0;

    if (_v2Isolate != null && _v1SeIsolate != null) {
      if (AndroidFaceCapturePerf.sequentialPad) {
        // Low-end Android: avoid 2×4-thread PAD fighting the embedder + ML Kit.
        final v2Sw = Stopwatch()..start();
        v2Probs = await _runIsolate(_v2Isolate!, v2Input, _v2Out);
        v2Ms = v2Sw.elapsedMilliseconds;
        final v1Sw = Stopwatch()..start();
        v1Probs = await _runIsolate(_v1SeIsolate!, v1Input, _v1Out);
        v1Ms = v1Sw.elapsedMilliseconds;
      } else {
        final v2Sw = Stopwatch()..start();
        final v1Sw = Stopwatch()..start();
        final pair = await Future.wait([
          _runIsolate(_v2Isolate!, v2Input, _v2Out).then((r) {
            v2Ms = v2Sw.elapsedMilliseconds;
            return r;
          }),
          _runIsolate(_v1SeIsolate!, v1Input, _v1Out).then((r) {
            v1Ms = v1Sw.elapsedMilliseconds;
            return r;
          }),
        ]);
        v2Probs = pair[0];
        v1Probs = pair[1];
      }
    } else {
      final v2Sw = Stopwatch()..start();
      v2Probs = await _runMain(_v2!, v2Input);
      v2Ms = v2Sw.elapsedMilliseconds;
      final v1Sw = Stopwatch()..start();
      v1Probs = await _runMain(_v1Se!, v1Input);
      v1Ms = v1Sw.elapsedMilliseconds;
    }
    lastInferenceMs = sw.elapsedMilliseconds;

    final fused = List<double>.generate(AntispoofConfig.numClasses, (i) {
      return (v2Probs[i] + v1Probs[i]) / 2;
    });
    final labelIndex = _argmax(fused);

    _inferenceCount += 1;
    if (_inferenceCount == 1) {
      await TfliteInterpreterFactory.notifyFirstInvokeOk(
        AntispoofConfig.modelV2Asset,
      );
      await TfliteInterpreterFactory.notifyFirstInvokeOk(
        AntispoofConfig.modelV1SeAsset,
      );
    }
    if (!_loggedBackendOnce) {
      _loggedBackendOnce = true;
      final threads = Platform.isAndroid
          ? AndroidFaceCapturePerf.tfliteThreads
          : 'default';
      debugPrint(
        'MinifasnetFusionEngine: model=${AntispoofConfig.modelV2Asset} '
        'backend=${TfliteInterpreterFactory.backendFor(AntispoofConfig.modelV2Asset)} '
        'threads=$threads isolate=${_v2Isolate != null} '
        'sequential=${AndroidFaceCapturePerf.sequentialPad} '
        'first_invoke_ms=$v2Ms',
      );
      debugPrint(
        'MinifasnetFusionEngine: model=${AntispoofConfig.modelV1SeAsset} '
        'backend=${TfliteInterpreterFactory.backendFor(AntispoofConfig.modelV1SeAsset)} '
        'threads=$threads isolate=${_v1SeIsolate != null} '
        'first_invoke_ms=$v1Ms',
      );
    }
    if (_inferenceCount == 1 || _inferenceCount % 50 == 0) {
      debugPrint(
        'MinifasnetFusionEngine: invoke ok pair#$_inferenceCount '
        'ms=$lastInferenceMs (load#$_loadCount — must stay 1)',
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

  Future<List<double>> _runIsolate(
    IsolateInterpreter isolate,
    Float32List nhwc,
    List<List<double>> isolateOut,
  ) async {
    while (isolate.state == IsolateInterpreterState.loading) {
      await isolate.stateChanges
          .firstWhere((s) => s == IsolateInterpreterState.idle);
    }
    final shaped = nhwc.reshape([
      1,
      AntispoofConfig.inputSize,
      AntispoofConfig.inputSize,
      3,
    ]);
    await isolate.run(shaped, isolateOut);
    return _softmax(
      List<double>.generate(
        AntispoofConfig.numClasses,
        (i) => isolateOut[0][i],
      ),
    );
  }

  Future<List<double>> _runMain(
    Interpreter interpreter,
    Float32List nhwc,
  ) async {
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

  /// Android camera-open self-test: one dummy pair; returns per-model ms.
  Future<
      ({
        bool ok,
        int v2Ms,
        int v1Ms,
        String mode,
      })> runSelfTest() async {
    await ensureLoaded();
    const n = AntispoofConfig.inputSize * AntispoofConfig.inputSize * 3;
    final probe = Float32List(n);
    try {
      final v2Sw = Stopwatch()..start();
      if (_v2Isolate != null) {
        await _runIsolate(_v2Isolate!, probe, _v2Out);
      } else {
        await _runMain(_v2!, probe);
      }
      final v2Ms = v2Sw.elapsedMilliseconds;

      final v1Sw = Stopwatch()..start();
      if (_v1SeIsolate != null) {
        await _runIsolate(_v1SeIsolate!, probe, _v1Out);
      } else {
        await _runMain(_v1Se!, probe);
      }
      final v1Ms = v1Sw.elapsedMilliseconds;

      debugPrint(
        'MinifasnetFusionEngine: selftest ok mode=$invokeMode '
        'v2_ms=$v2Ms v1se_ms=$v1Ms',
      );
      return (ok: true, v2Ms: v2Ms, v1Ms: v1Ms, mode: invokeMode);
    } catch (e, st) {
      debugPrint('MinifasnetFusionEngine: selftest failed: $e\n$st');
      return (ok: false, v2Ms: -1, v1Ms: -1, mode: invokeMode);
    }
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
