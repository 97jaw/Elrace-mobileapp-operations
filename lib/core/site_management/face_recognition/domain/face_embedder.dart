import 'dart:math' as math;
import 'package:el_race/core/site_management/face_recognition/face_recognition_config.dart';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class FaceEmbedder {
  FaceEmbedder._();
  static final FaceEmbedder instance = FaceEmbedder._();

  Interpreter? _interpreter;
  Future<void>? _loadFuture;

  Future<void> ensureLoaded() {
    _loadFuture ??= _load();
    return _loadFuture!;
  }

  Future<void> _load() async {
    if (_interpreter != null) return;
    final options = InterpreterOptions()..threads = 2;
    _interpreter = await Interpreter.fromAsset(
      FaceRecognitionModel.assetPath,
      options: options,
    );
    debugPrint('FaceEmbedder: loaded ${FaceRecognitionModel.assetPath}');
  }

  Future<List<double>> generateEmbedding(Float32List inputNhwc) async {
    await ensureLoaded();
    final interpreter = _interpreter!;
    final expected = FaceRecognitionPreprocess.inputHeight *
        FaceRecognitionPreprocess.inputWidth *
        FaceRecognitionPreprocess.inputChannels;
    if (inputNhwc.length != expected) {
      throw ArgumentError('input length ${inputNhwc.length}, expected $expected');
    }

    final input = inputNhwc.reshape([
      1,
      FaceRecognitionPreprocess.inputHeight,
      FaceRecognitionPreprocess.inputWidth,
      FaceRecognitionPreprocess.inputChannels,
    ]);
    final output = List.generate(
      1,
      (_) => List.filled(FaceRecognitionModel.embeddingDim, 0.0),
    );
    interpreter.run(input, output);
    final vec = List<double>.from(output[0]);
    return _l2Normalize(vec);
  }

  List<double> _l2Normalize(List<double> vec) {
    var sum = 0.0;
    for (final v in vec) {
      sum += v * v;
    }
    final n = math.sqrt(sum);
    if (n < 1e-9) return vec;
    return vec.map((v) => v / n).toList();
  }

  /// E.3 debug — first values of normalized 512-d embedding.
  void debugPrintEmbeddingHead(List<double> embedding, {String label = 'probe'}) {
    if (!kDebugMode) return;
    final head = embedding.take(8).map((v) => v.toStringAsFixed(4)).join(', ');
    debugPrint('FaceEmbedder: $label dim=${embedding.length} head=[$head]');
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _loadFuture = null;
  }
}
