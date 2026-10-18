import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:el_race/core/site_management/face_recognition/face_recognition_config.dart';
import 'package:el_race/core/site_management/face_recognition/tflite_bytebuffer_worker.dart';
import 'package:el_race/core/site_management/face_recognition/tflite_interpreter_factory.dart';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

enum EmbInvokeBackend {
  isolateInterpreter,
  workerByteBuffer,
  mainByteBuffer,
}

/// MobileFaceNet embedding — interpreter is created once and reused forever.
///
/// Critical: never pass nested [List] inputs via [Interpreter.run] on the
/// main-isolate path. That can call [Interpreter.resizeInputTensor] →
/// [Interpreter.allocateTensors] which re-applies XNNPACK every frame.
/// Feed a fixed [ByteBuffer]/[Uint8List] into the pinned input tensor.
///
/// Android: starts on [EmbInvokeBackend.isolateInterpreter] (last known-good),
/// optionally A/B's faster paths, falls back to IsolateInterpreter on failure.
/// iOS: ByteBuffer + invoke (untouched).
class FaceEmbedder {
  FaceEmbedder._();
  static final FaceEmbedder instance = FaceEmbedder._();

  Interpreter? _interpreter;
  IsolateInterpreter? _isolate;
  TfliteByteBufferWorker? _worker;
  EmbInvokeBackend _backend = EmbInvokeBackend.mainByteBuffer;
  Future<void>? _loadFuture;
  int _loadCount = 0;
  int _inferenceCount = 0;
  bool _loggedBackendOnce = false;
  bool _fellBackToIsolate = false;

  /// Last embedding invoke time (ms); for BestFrame perf logs.
  int lastInferenceMs = 0;

  EmbInvokeBackend get invokeBackend => _backend;
  bool get usedFallback => _fellBackToIsolate;

  /// Preallocated output scratch (512 floats).
  late Float32List _outputScratch;

  /// Reused nested output for IsolateInterpreter.run.
  List<List<double>>? _isolateOutput;

  Future<void> ensureLoaded() {
    _loadFuture ??= _load().catchError((Object e, StackTrace st) {
      _loadFuture = null;
      Error.throwWithStackTrace(e, st);
    });
    return _loadFuture!;
  }

  Future<void> _load() async {
    if (_interpreter != null) return;
    if (_loadCount > 0) {
      debugPrint('FaceEmbedder: refusing reload (already load#$_loadCount)');
      return;
    }

    final android = Platform.isAndroid;
    _interpreter = await TfliteInterpreterFactory.fromAsset(
      FaceRecognitionModel.assetPath,
      fixedInputShape: const [
        1,
        FaceRecognitionPreprocess.inputHeight,
        FaceRecognitionPreprocess.inputWidth,
        FaceRecognitionPreprocess.inputChannels,
      ],
      preferXnnpack: false,
      numThreads: android ? 4 : null,
    );
    _outputScratch = Float32List(FaceRecognitionModel.embeddingDim);
    _loadCount += 1;

    if (android) {
      await _ensureIsolateInterpreter();
      _backend = EmbInvokeBackend.isolateInterpreter;
      try {
        await _androidPickFastestBackend();
      } catch (e, st) {
        debugPrint('FaceEmbedder: A/B failed ($e) — keeping IsolateInterpreter');
        debugPrint('$st');
        await _forceIsolateInterpreterFallback(reason: 'ab_error');
      }
    } else {
      _backend = EmbInvokeBackend.mainByteBuffer;
    }

    final inShape = _interpreter!.getInputTensor(0).shape;
    final outShape = _interpreter!.getOutputTensor(0).shape;
    final factoryBackend =
        TfliteInterpreterFactory.backendFor(FaceRecognitionModel.assetPath);
    debugPrint(
      'FaceEmbedder: INTERPRETER_CACHED load#$_loadCount '
      'backend=$factoryBackend invoke=${_backend.name} '
      'threads=${android ? 4 : "default"} '
      'asset=${FaceRecognitionModel.assetPath} '
      'in=$inShape out=$outShape',
    );
  }

  Future<void> _ensureIsolateInterpreter() async {
    if (_isolate != null) return;
    _isolate = await IsolateInterpreter.create(
      address: _interpreter!.address,
      debugName: 'FaceEmbedderIsolate',
    );
    _isolateOutput = [
      List<double>.filled(FaceRecognitionModel.embeddingDim, 0.0),
    ];
  }

  /// Drop optional workers and keep the known-good IsolateInterpreter path.
  /// Never closes [_interpreter].
  Future<void> _forceIsolateInterpreterFallback({required String reason}) async {
    final worker = _worker;
    _worker = null;
    if (worker != null) {
      try {
        await worker.close();
      } catch (_) {}
    }
    await _ensureIsolateInterpreter();
    _backend = EmbInvokeBackend.isolateInterpreter;
    _fellBackToIsolate = true;
    debugPrint(
      'FaceEmbedder: fallback invoke=isolateInterpreter reason=$reason',
    );
  }

  Future<void> _androidPickFastestBackend() async {
    final probe = Float32List(
      FaceRecognitionPreprocess.inputHeight *
          FaceRecognitionPreprocess.inputWidth *
          FaceRecognitionPreprocess.inputChannels,
    );
    final timings = <EmbInvokeBackend, int>{};

    // 1) IsolateInterpreter (baseline — already created).
    await _ensureIsolateInterpreter();
    final iso = _isolate!;
    final isoOut = _isolateOutput!;
    await _timeOnce(() async {
      final shaped = probe.reshape([
        1,
        FaceRecognitionPreprocess.inputHeight,
        FaceRecognitionPreprocess.inputWidth,
        FaceRecognitionPreprocess.inputChannels,
      ]);
      await iso.run(shaped, isoOut);
    });
    timings[EmbInvokeBackend.isolateInterpreter] = await _timeOnce(() async {
      final shaped = probe.reshape([
        1,
        FaceRecognitionPreprocess.inputHeight,
        FaceRecognitionPreprocess.inputWidth,
        FaceRecognitionPreprocess.inputChannels,
      ]);
      await iso.run(shaped, isoOut);
    });
    debugPrint(
      'FaceEmbedder: A/B isolateInterpreter_ms='
      '${timings[EmbInvokeBackend.isolateInterpreter]}',
    );

    // 2) ByteBuffer worker (allocated: true — see TfliteByteBufferWorker).
    TfliteByteBufferWorker? worker;
    try {
      worker = await TfliteByteBufferWorker.create(
        interpreterAddress: _interpreter!.address,
        inputFloatCount: probe.length,
        outputFloatCount: FaceRecognitionModel.embeddingDim,
        debugName: 'FaceEmbedderWorkerAB',
      );
      await _timeOnce(() => worker!.run(probe));
      timings[EmbInvokeBackend.workerByteBuffer] =
          await _timeOnce(() => worker!.run(probe));
      debugPrint(
        'FaceEmbedder: A/B workerByteBuffer_ms='
        '${timings[EmbInvokeBackend.workerByteBuffer]}',
      );
    } catch (e) {
      debugPrint('FaceEmbedder: A/B workerByteBuffer failed: $e');
      if (worker != null) {
        try {
          await worker.close();
        } catch (_) {}
        worker = null;
      }
    }

    // 3) Main-isolate ByteBuffer.
    try {
      await _timeOnce(() => _invokeMainByteBuffer(probe));
      timings[EmbInvokeBackend.mainByteBuffer] =
          await _timeOnce(() => _invokeMainByteBuffer(probe));
      debugPrint(
        'FaceEmbedder: A/B mainByteBuffer_ms='
        '${timings[EmbInvokeBackend.mainByteBuffer]}',
      );
    } catch (e) {
      debugPrint('FaceEmbedder: A/B mainByteBuffer failed: $e');
    }

    if (timings.isEmpty) {
      await _forceIsolateInterpreterFallback(reason: 'ab_no_timings');
      return;
    }

    var best = EmbInvokeBackend.isolateInterpreter;
    var bestMs = timings[best] ?? 1 << 30;
    for (final e in timings.entries) {
      if (e.value < bestMs) {
        best = e.key;
        bestMs = e.value;
      }
    }
    debugPrint(
      'FaceEmbedder: A/B keep=${best.name} ms=$bestMs '
      '(isolate=${timings[EmbInvokeBackend.isolateInterpreter]} '
      'worker=${timings[EmbInvokeBackend.workerByteBuffer]} '
      'main=${timings[EmbInvokeBackend.mainByteBuffer]})',
    );

    // Apply winner without closing the shared Interpreter.
    switch (best) {
      case EmbInvokeBackend.isolateInterpreter:
        if (worker != null) {
          try {
            await worker.close();
          } catch (_) {}
        }
        _worker = null;
        _backend = EmbInvokeBackend.isolateInterpreter;
      case EmbInvokeBackend.workerByteBuffer:
        if (worker == null) {
          await _forceIsolateInterpreterFallback(reason: 'worker_missing');
          return;
        }
        // Keep IsolateInterpreter around as instant fallback; stop using it.
        _worker = worker;
        _backend = EmbInvokeBackend.workerByteBuffer;
      case EmbInvokeBackend.mainByteBuffer:
        if (worker != null) {
          try {
            await worker.close();
          } catch (_) {}
        }
        _worker = null;
        _backend = EmbInvokeBackend.mainByteBuffer;
    }
  }

  Future<int> _timeOnce(Future<void> Function() fn) async {
    final sw = Stopwatch()..start();
    await fn();
    return sw.elapsedMilliseconds;
  }

  Future<void> _invokeMainByteBuffer(Float32List inputNhwc) async {
    final interpreter = _interpreter!;
    final inputBytes = inputNhwc.buffer.asUint8List(
      inputNhwc.offsetInBytes,
      inputNhwc.lengthInBytes,
    );
    interpreter.getInputTensor(0).data = inputBytes;
    interpreter.invoke();
    final outBytes = interpreter.getOutputTensor(0).data;
    final outFloats = outBytes.buffer.asFloat32List(
      outBytes.offsetInBytes,
      FaceRecognitionModel.embeddingDim,
    );
    _outputScratch.setAll(0, outFloats);
  }

  Future<void> _invokeIsolate(Float32List inputNhwc) async {
    final isolate = _isolate!;
    while (isolate.state == IsolateInterpreterState.loading) {
      await isolate.stateChanges
          .firstWhere((s) => s == IsolateInterpreterState.idle);
    }
    final shapedIn = inputNhwc.reshape([
      1,
      FaceRecognitionPreprocess.inputHeight,
      FaceRecognitionPreprocess.inputWidth,
      FaceRecognitionPreprocess.inputChannels,
    ]);
    final out = _isolateOutput!;
    await isolate.run(shapedIn, out);
    for (var i = 0; i < FaceRecognitionModel.embeddingDim; i++) {
      _outputScratch[i] = out[0][i];
    }
  }

  Future<List<double>> generateEmbedding(Float32List inputNhwc) async {
    await ensureLoaded();
    const expected = FaceRecognitionPreprocess.inputHeight *
        FaceRecognitionPreprocess.inputWidth *
        FaceRecognitionPreprocess.inputChannels;
    if (inputNhwc.length != expected) {
      throw ArgumentError('input length ${inputNhwc.length}, expected $expected');
    }

    final sw = Stopwatch()..start();
    try {
      switch (_backend) {
        case EmbInvokeBackend.isolateInterpreter:
          await _invokeIsolate(inputNhwc);
        case EmbInvokeBackend.workerByteBuffer:
          final out = await _worker!.run(inputNhwc);
          _outputScratch.setAll(0, out);
        case EmbInvokeBackend.mainByteBuffer:
          await _invokeMainByteBuffer(inputNhwc);
      }
    } catch (e, st) {
      if (_backend != EmbInvokeBackend.isolateInterpreter) {
        debugPrint('FaceEmbedder: invoke failed ($e) — fallback');
        debugPrint('$st');
        await _forceIsolateInterpreterFallback(reason: 'invoke_error');
        await _invokeIsolate(inputNhwc);
      } else {
        rethrow;
      }
    }
    lastInferenceMs = sw.elapsedMilliseconds;

    _inferenceCount += 1;
    if (_inferenceCount == 1) {
      await TfliteInterpreterFactory.notifyFirstInvokeOk(
        FaceRecognitionModel.assetPath,
      );
    }
    if (!_loggedBackendOnce) {
      _loggedBackendOnce = true;
      final factoryBackend =
          TfliteInterpreterFactory.backendFor(FaceRecognitionModel.assetPath);
      debugPrint(
        'FaceEmbedder: model=${FaceRecognitionModel.assetPath} '
        'backend=$factoryBackend threads=${Platform.isAndroid ? 4 : "default"} '
        'isolate=${_backend != EmbInvokeBackend.mainByteBuffer} '
        'invoke=${_backend.name} first_invoke_ms=$lastInferenceMs',
      );
    }
    if (_inferenceCount == 1 || _inferenceCount % 50 == 0) {
      debugPrint(
        'FaceEmbedder: invoke ok inference#$_inferenceCount '
        'ms=$lastInferenceMs (load#$_loadCount — must stay 1)',
      );
    }

    return _l2Normalize(_outputScratch);
  }

  /// Android camera-open self-test: one dummy inference; falls back on failure.
  Future<({bool ok, int ms, String backend})> runSelfTest() async {
    await ensureLoaded();
    final probe = Float32List(
      FaceRecognitionPreprocess.inputHeight *
          FaceRecognitionPreprocess.inputWidth *
          FaceRecognitionPreprocess.inputChannels,
    );
    final sw = Stopwatch()..start();
    try {
      await generateEmbedding(probe);
      final ms = sw.elapsedMilliseconds;
      debugPrint(
        'FaceEmbedder: selftest ok backend=${_backend.name} '
        'ms=$ms fallback=$_fellBackToIsolate',
      );
      return (ok: true, ms: ms, backend: _backend.name);
    } catch (e, st) {
      debugPrint('FaceEmbedder: selftest failed: $e\n$st');
      try {
        await _forceIsolateInterpreterFallback(reason: 'selftest');
        final sw2 = Stopwatch()..start();
        await _invokeIsolate(probe);
        lastInferenceMs = sw2.elapsedMilliseconds;
        debugPrint(
          'FaceEmbedder: selftest fallback ok invoke=isolateInterpreter '
          'ms=$lastInferenceMs',
        );
        return (
          ok: true,
          ms: lastInferenceMs,
          backend: EmbInvokeBackend.isolateInterpreter.name,
        );
      } catch (e2, st2) {
        debugPrint('FaceEmbedder: selftest fallback failed: $e2\n$st2');
        return (ok: false, ms: sw.elapsedMilliseconds, backend: _backend.name);
      }
    }
  }

  List<double> _l2Normalize(Float32List vec) {
    var sum = 0.0;
    for (var i = 0; i < vec.length; i++) {
      sum += vec[i] * vec[i];
    }
    final n = math.sqrt(sum);
    if (n < 1e-9) {
      return List<double>.generate(vec.length, (i) => vec[i].toDouble());
    }
    final out = List<double>.filled(vec.length, 0.0);
    final inv = 1.0 / n;
    for (var i = 0; i < vec.length; i++) {
      out[i] = vec[i] * inv;
    }
    return out;
  }

  /// E.3 debug — first values of normalized 512-d embedding.
  void debugPrintEmbeddingHead(List<double> embedding, {String label = 'probe'}) {
    if (!kDebugMode) return;
    final head = embedding.take(8).map((v) => v.toStringAsFixed(4)).join(', ');
    debugPrint('FaceEmbedder: $label dim=${embedding.length} head=[$head]');
  }

  /// Prefer process-lifetime reuse. Closing mid-session re-applies XNNPACK.
  void dispose() {
    debugPrint(
      'FaceEmbedder: dispose ignored — keep load#$_loadCount cached',
    );
  }
}
