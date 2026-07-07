import 'dart:convert';
import 'dart:typed_data';

import 'package:el_race/core/site_management/face_recognition/face_recognition_config.dart';

abstract final class EmbeddingCodec {
  static List<double> decodeBase64Embedding(String b64) {
    final expected = FaceRecognitionModel.embeddingDim * 4;
    var raw = base64.decode(b64.trim());
    if (raw.length != expected) {
      // Odoo sometimes double-wraps: Binary field holds base64(float32) bytes (~2732).
      try {
        final inner = base64.decode(String.fromCharCodes(raw));
        if (inner.length == expected) {
          raw = inner;
        }
      } catch (_) {
        // fall through to error below
      }
    }
    if (raw.length != expected) {
      throw FormatException(
        'expected $expected bytes, got ${raw.length}',
      );
    }
    return _float32ListFromBytes(raw);
  }

  static Uint8List encodeToBlob(List<double> vec) {
    final out = Float32List(vec.length);
    for (var i = 0; i < vec.length; i++) {
      out[i] = vec[i];
    }
    return Uint8List.view(out.buffer, 0, vec.length * 4);
  }

  static List<double> decodeBlob(Uint8List blob) {
    final expected = FaceRecognitionModel.embeddingDim * 4;
    if (blob.length != expected) {
      throw FormatException('invalid embedding blob length ${blob.length}');
    }
    return _float32ListFromBytes(blob).toList();
  }

  /// SQLite [Uint8List] views may use a byte offset that is not 4-byte aligned.
  static Float32List _float32ListFromBytes(Uint8List bytes) {
    final dim = FaceRecognitionModel.embeddingDim;
    final out = Float32List(dim);
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i < dim; i++) {
      out[i] = data.getFloat32(i * 4, Endian.little);
    }
    return out;
  }
}
