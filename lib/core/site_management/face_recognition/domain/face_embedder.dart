import 'dart:math' as math;
import 'dart:typed_data';

import 'package:el_race/core/site_management/face_recognition/face_recognition_config.dart';
import 'package:el_race/core/site_management/face_recognition/tflite_interpreter_factory.dart';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// MobileFaceNet embedding — interpreter is created once and reused forever.
///
/// Critical: never pass nested [List] inputs via [Interpreter.run]. That path
/// can call [Interpreter.resizeInputTensor] → [Interpreter.allocateTensors]
/// which re-applies XNNPACK every frame (the `Replacing 65 out of 65 nodes`
/// log). Feed a fixed [ByteBuffer]/[Uint8List] into the pinned input tensor.
///
/// XNNPACK is opt-in via [TfliteInterpreterFactory] (crash-loop guard + denylist).
class FaceEmbedder {
  FaceEmbedder._();
  static final FaceEmbedder instance = FaceEmbedder._();

  Interpreter? _interpreter;
  Future<void>? _loadFuture;
  int _loadCount = 0;
  int _inferenceCount = 0;

  /// Preallocated output scratch (512 floats).
  late Float32List _outputScratch;

  Future<void> ensureLoaded() {
    _loadFuture ??= _load();
    return _loadFuture!;
  }

  Future<void> _load() async {
    if (_interpreter != null) return;
    if (_loadCount > 0) {
      debugPrint('FaceEmbedder: refusing reload (already load#$_loadCount)');
      return;
    }

    _interpreter = await TfliteInterpreterFactory.fromAsset(
      FaceRecognitionModel.assetPath,
      fixedInputShape: const [
        1,
        FaceRecognitionPreprocess.inputHeight,
        FaceRecognitionPreprocess.inputWidth,
        FaceRecognitionPreprocess.inputChannels,
      ],
    );
    // fromAsset already allocateTensors()'s once; keep that allocation.
    _outputScratch = Float32List(FaceRecognitionModel.embeddingDim);
    _loadCount += 1;
    final inShape = _interpreter!.getInputTensor(0).shape;
    final outShape = _interpreter!.getOutputTensor(0).shape;
    debugPrint(
      'FaceEmbedder: INTERPRETER_CACHED load#$_loadCount '
      'backend=${TfliteInterpreterFactory.backendLabel} '
      'asset=${FaceRecognitionModel.assetPath} '
      'in=$inShape out=$outShape',
    );
  }

  Future<List<double>> generateEmbedding(Float32List inputNhwc) async {
    await ensureLoaded();
    final interpreter = _interpreter!;
    const expected = FaceRecognitionPreprocess.inputHeight *
        FaceRecognitionPreprocess.inputWidth *
        FaceRecognitionPreprocess.inputChannels;
    if (inputNhwc.length != expected) {
      throw ArgumentError('input length ${inputNhwc.length}, expected $expected');
    }

    // ByteBuffer path → getInputShapeIfDifferent returns null → no resize /
    // no re-allocateTensors / no XNNPACK rebuild.
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

    _inferenceCount += 1;
    if (_inferenceCount == 1 || _inferenceCount % 50 == 0) {
      debugPrint(
        'FaceEmbedder: invoke ok inference#$_inferenceCount '
        '(load#$_loadCount — must stay 1)',
      );
    }

    return _l2Normalize(_outputScratch);
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
