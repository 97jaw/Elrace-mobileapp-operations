import 'dart:math' as math;
import 'dart:ui';

import 'package:el_race/core/site_management/face_recognition/antispoof/antispoof_config.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Face crop + resize matching Silent-Face-Anti-Spoofing [CropImage._get_new_box].
class MinifasnetPreprocessor {
  const MinifasnetPreprocessor();

  /// Returns NHWC float32 tensor length [1 * 80 * 80 * 3], values 0–255.
  Float32List? buildInput({
    required img.Image source,
    required Rect faceBox,
    required double cropScale,
    String model = 'pad',
    double? yawDeg,
  }) {
    final cropped = _cropFace(
      source: source,
      faceBox: faceBox,
      scaleReq: cropScale,
      model: model,
      yawDeg: yawDeg,
    );
    if (cropped == null) return null;

    const size = AntispoofConfig.inputSize;
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

  /// Official MiniFASNet box: shrink [scaleReq] until it fits, then shift in.
  /// Never fails for a valid face box inside the frame.
  static ({int left, int top, int right, int bottom, double scaleUsed, bool shifted})
      getNewBox({
    required int srcW,
    required int srcH,
    required Rect faceBox,
    required double scaleReq,
  }) {
    final boxW = math.max(1.0, faceBox.width);
    final boxH = math.max(1.0, faceBox.height);
    final scaleUsed = math.min(
      (srcH - 1) / boxH,
      math.min((srcW - 1) / boxW, scaleReq),
    );
    final newW = boxW * scaleUsed;
    final newH = boxH * scaleUsed;
    final centerX = faceBox.left + boxW / 2;
    final centerY = faceBox.top + boxH / 2;

    var left = (centerX - newW / 2).round();
    var top = (centerY - newH / 2).round();
    var right = (centerX + newW / 2).round();
    var bottom = (centerY + newH / 2).round();
    var shifted = false;

    if (left < 0) {
      right -= left;
      left = 0;
      shifted = true;
    }
    if (top < 0) {
      bottom -= top;
      top = 0;
      shifted = true;
    }
    if (right > srcW - 1) {
      left -= right - (srcW - 1);
      right = srcW - 1;
      shifted = true;
    }
    if (bottom > srcH - 1) {
      top -= bottom - (srcH - 1);
      bottom = srcH - 1;
      shifted = true;
    }

    left = left.clamp(0, srcW - 1);
    top = top.clamp(0, srcH - 1);
    right = right.clamp(left, srcW - 1);
    bottom = bottom.clamp(top, srcH - 1);

    return (
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      scaleUsed: scaleUsed,
      shifted: shifted,
    );
  }

  img.Image? _cropFace({
    required img.Image source,
    required Rect faceBox,
    required double scaleReq,
    required String model,
    double? yawDeg,
  }) {
    final srcW = source.width;
    final srcH = source.height;
    if (faceBox.width <= 0 || faceBox.height <= 0 || srcW < 8 || srcH < 8) {
      return null;
    }

    final box = getNewBox(
      srcW: srcW,
      srcH: srcH,
      faceBox: faceBox,
      scaleReq: scaleReq,
    );
    debugPrint(
      'PadCrop: model=$model scale_req=${scaleReq.toStringAsFixed(1)} '
      'scale_used=${box.scaleUsed.toStringAsFixed(2)} '
      'shifted=${box.shifted}'
      '${yawDeg != null ? ' yaw=${yawDeg.toStringAsFixed(1)}' : ''}',
    );

    final w = box.right - box.left + 1;
    final h = box.bottom - box.top + 1;
    if (w < 1 || h < 1) return null;

    final cropped = img.copyCrop(
      source,
      x: box.left,
      y: box.top,
      width: w,
      height: h,
    );
    return img.copyResize(
      cropped,
      width: AntispoofConfig.inputSize,
      height: AntispoofConfig.inputSize,
      interpolation: img.Interpolation.linear,
    );
  }
}
