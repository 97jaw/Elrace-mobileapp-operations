import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:el_race/core/site_management/face_recognition/antispoof/antispoof_config.dart';
import 'package:image/image.dart' as img;

/// Face crop + resize matching Silent-Face-Anti-Spoofing [CropImage] logic.
class MinifasnetPreprocessor {
  const MinifasnetPreprocessor();

  /// Returns NHWC float32 tensor length [1 * 80 * 80 * 3], values 0–255.
  Float32List? buildInput({
    required img.Image source,
    required Rect faceBox,
    required double cropScale,
  }) {
    final bbox = _xywhFromRect(faceBox);
    final cropped = _cropFace(
      source: source,
      bbox: bbox,
      scale: cropScale,
      outW: AntispoofConfig.inputSize,
      outH: AntispoofConfig.inputSize,
    );
    if (cropped == null) return null;

    final size = AntispoofConfig.inputSize;
    final buffer = Float32List(1 * size * size * 3);
    var i = 0;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final pixel = cropped.getPixel(x, y);
        buffer[i++] = pixel.r.toDouble();
        buffer[i++] = pixel.g.toDouble();
        buffer[i++] = pixel.b.toDouble();
      }
    }
    return buffer;
  }

  List<int> _xywhFromRect(Rect box) {
    return [
      box.left.round(),
      box.top.round(),
      box.width.round(),
      box.height.round(),
    ];
  }

  img.Image? _cropFace({
    required img.Image source,
    required List<int> bbox,
    required double scale,
    required int outW,
    required int outH,
  }) {
    final srcW = source.width;
    final srcH = source.height;
    final x = bbox[0];
    final y = bbox[1];
    final boxW = bbox[2];
    final boxH = bbox[3];
    if (boxW <= 0 || boxH <= 0) return null;

    final effectiveScale = math.min(
      (srcH - 1) / boxH,
      math.min((srcW - 1) / boxW, scale),
    );
    final newW = boxW * effectiveScale;
    final newH = boxH * effectiveScale;
    final centerX = x + boxW / 2;
    final centerY = y + boxH / 2;

    var left = (centerX - newW / 2).round();
    var top = (centerY - newH / 2).round();
    var right = (centerX + newW / 2).round();
    var bottom = (centerY + newH / 2).round();

    if (left < 0) {
      right -= left;
      left = 0;
    }
    if (top < 0) {
      bottom -= top;
      top = 0;
    }
    if (right > srcW - 1) {
      left -= right - (srcW - 1);
      right = srcW - 1;
    }
    if (bottom > srcH - 1) {
      top -= bottom - (srcH - 1);
      bottom = srcH - 1;
    }

    final w = (right - left + 1).clamp(1, srcW);
    final h = (bottom - top + 1).clamp(1, srcH);
    final cropped = img.copyCrop(
      source,
      x: left.clamp(0, srcW - 1),
      y: top.clamp(0, srcH - 1),
      width: w,
      height: h,
    );
    return img.copyResize(
      cropped,
      width: outW,
      height: outH,
      interpolation: img.Interpolation.linear,
    );
  }
}
