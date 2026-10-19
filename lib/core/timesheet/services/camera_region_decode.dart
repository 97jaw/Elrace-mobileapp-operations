import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/antispoof_config.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Synchronous crop of only the face-expanded region from a [CameraImage].
///
/// Used on Android best-frame path so the stream callback can copy a small
/// RGB region and return the [CameraImage] immediately (no full 720p decode).
abstract final class CameraRegionDecode {
  /// Expand face by the larger PAD scale (+ margin) so both MiniFASNet crops
  /// and the 112×112 embed chip fit inside the returned upright RGB.
  static const double regionExpand = AntispoofConfig.modelV1SeCropScale * 1.05;

  /// Returns an upright RGB crop covering [faceBoxUpright] expanded by
  /// [regionExpand], plus the face box / landmarks remapped into crop space.
  ///
  /// [faceBoxUpright] and landmark offsets are in the same space ML Kit uses
  /// after sensor rotation (matching [decodeCameraImageUpright]).
  static CameraRegionCrop? extractUprightFaceRegion({
    required CameraImage image,
    required CameraDescription camera,
    required Rect faceBoxUpright,
    Offset? leftEye,
    Offset? rightEye,
    Offset? nose,
    Offset? mouthLeft,
    Offset? mouthRight,
  }) {
    try {
      final angle = camera.sensorOrientation % 360;
      final sensorW = image.width;
      final sensorH = image.height;

      // Upright size after the same rotation as decodeCameraImageUpright.
      final uprightW = (angle == 90 || angle == 270) ? sensorH : sensorW;
      final uprightH = (angle == 90 || angle == 270) ? sensorW : sensorH;

      final expanded = _expandClamped(
        faceBoxUpright,
        uprightW.toDouble(),
        uprightH.toDouble(),
        regionExpand,
      );
      if (expanded.width < 8 || expanded.height < 8) return null;

      // Map upright crop corners → sensor, take AABB.
      final sensorRect = _uprightRectToSensorAabb(
        expanded,
        sensorW: sensorW,
        sensorH: sensorH,
        angle: angle,
      );
      if (sensorRect == null) return null;

      final left = sensorRect.left.floor().clamp(0, sensorW - 1);
      final top = sensorRect.top.floor().clamp(0, sensorH - 1);
      final right = sensorRect.right.ceil().clamp(left + 1, sensorW);
      final bottom = sensorRect.bottom.ceil().clamp(top + 1, sensorH);
      final cropW = right - left;
      final cropH = bottom - top;
      if (cropW < 8 || cropH < 8) return null;

      final sensorRgb = _decodeRegionRgb(image, left, top, cropW, cropH);
      if (sensorRgb == null) return null;

      img.Image upright = sensorRgb;
      if (angle != 0) {
        upright = img.copyRotate(sensorRgb, angle: angle);
      }

      // Remap face box from full upright → crop upright.
      // Sensor crop (left,top) after rotation lands at an origin in upright
      // space; use the mapping of the sensor crop's top-left.
      final originUpright = _sensorPointToUpright(
        left.toDouble(),
        top.toDouble(),
        sensorW: sensorW,
        sensorH: sensorH,
        angle: angle,
      );
      // Also need how the crop's extents map — easier: map face box corners
      // through the known upright coords minus the expanded rect origin.
      final faceInCrop = Rect.fromLTRB(
        faceBoxUpright.left - expanded.left,
        faceBoxUpright.top - expanded.top,
        faceBoxUpright.right - expanded.left,
        faceBoxUpright.bottom - expanded.top,
      );

      // The rotated sensor crop may not match [expanded] pixel-for-pixel when
      // the AABB grew; scale faceInCrop into the actual upright crop size.
      final scaleX = upright.width / expanded.width;
      final scaleY = upright.height / expanded.height;
      final mappedFace = Rect.fromLTRB(
        faceInCrop.left * scaleX,
        faceInCrop.top * scaleY,
        faceInCrop.right * scaleX,
        faceInCrop.bottom * scaleY,
      );

      Offset? mapLm(Offset? p) {
        if (p == null) return null;
        return Offset(
          (p.dx - expanded.left) * scaleX,
          (p.dy - expanded.top) * scaleY,
        );
      }

      // Silence unused when angle==0 (origin helper still documents mapping).
      assert(originUpright.dx.isFinite);

      return CameraRegionCrop(
        rgb: upright,
        faceBoxInCrop: mappedFace,
        leftEye: mapLm(leftEye),
        rightEye: mapLm(rightEye),
        nose: mapLm(nose),
        mouthLeft: mapLm(mouthLeft),
        mouthRight: mapLm(mouthRight),
        uprightFrameSize: Size(uprightW.toDouble(), uprightH.toDouble()),
        regionInUpright: expanded,
      );
    } catch (e, st) {
      debugPrint('CameraRegionDecode: extract failed: $e\n$st');
      return null;
    }
  }

  static Rect _expandClamped(
    Rect box,
    double frameW,
    double frameH,
    double scale,
  ) {
    final cx = box.center.dx;
    final cy = box.center.dy;
    final w = box.width * scale;
    final h = box.height * scale;
    var left = cx - w / 2;
    var top = cy - h / 2;
    var right = cx + w / 2;
    var bottom = cy + h / 2;
    if (left < 0) {
      right -= left;
      left = 0;
    }
    if (top < 0) {
      bottom -= top;
      top = 0;
    }
    if (right > frameW) {
      left -= right - frameW;
      right = frameW;
    }
    if (bottom > frameH) {
      top -= bottom - frameH;
      bottom = frameH;
    }
    left = left.clamp(0, frameW);
    top = top.clamp(0, frameH);
    right = right.clamp(left + 1, frameW);
    bottom = bottom.clamp(top + 1, frameH);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// img.copyRotate(angle) clockwise mapping used by decodeCameraImageUpright.
  static Offset _sensorPointToUpright(
    double sx,
    double sy, {
    required int sensorW,
    required int sensorH,
    required int angle,
  }) {
    switch (angle) {
      case 90:
        // (sx,sy) → (sy, sensorW-1-sx), size (sensorH, sensorW)
        return Offset(sy, sensorW - 1 - sx);
      case 180:
        return Offset(sensorW - 1 - sx, sensorH - 1 - sy);
      case 270:
        // (sx,sy) → (sensorH-1-sy, sx), size (sensorH, sensorW)
        return Offset(sensorH - 1 - sy, sx);
      default:
        return Offset(sx, sy);
    }
  }

  static Offset _uprightPointToSensor(
    double ux,
    double uy, {
    required int sensorW,
    required int sensorH,
    required int angle,
  }) {
    switch (angle) {
      case 90:
        // Inverse of (sx,sy)→(sy, W-1-sx): ux=sy, uy=W-1-sx → sx=W-1-uy, sy=ux
        return Offset(sensorW - 1 - uy, ux);
      case 180:
        return Offset(sensorW - 1 - ux, sensorH - 1 - uy);
      case 270:
        // Inverse of (sx,sy)→(H-1-sy, sx): ux=H-1-sy, uy=sx → sx=uy, sy=H-1-ux
        return Offset(uy, sensorH - 1 - ux);
      default:
        return Offset(ux, uy);
    }
  }

  static Rect? _uprightRectToSensorAabb(
    Rect upright, {
    required int sensorW,
    required int sensorH,
    required int angle,
  }) {
    final corners = [
      _uprightPointToSensor(
        upright.left,
        upright.top,
        sensorW: sensorW,
        sensorH: sensorH,
        angle: angle,
      ),
      _uprightPointToSensor(
        upright.right,
        upright.top,
        sensorW: sensorW,
        sensorH: sensorH,
        angle: angle,
      ),
      _uprightPointToSensor(
        upright.left,
        upright.bottom,
        sensorW: sensorW,
        sensorH: sensorH,
        angle: angle,
      ),
      _uprightPointToSensor(
        upright.right,
        upright.bottom,
        sensorW: sensorW,
        sensorH: sensorH,
        angle: angle,
      ),
    ];
    var minX = corners.first.dx;
    var maxX = corners.first.dx;
    var minY = corners.first.dy;
    var maxY = corners.first.dy;
    for (final c in corners.skip(1)) {
      minX = math.min(minX, c.dx);
      maxX = math.max(maxX, c.dx);
      minY = math.min(minY, c.dy);
      maxY = math.max(maxY, c.dy);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  static img.Image? _decodeRegionRgb(
    CameraImage image,
    int left,
    int top,
    int width,
    int height,
  ) {
    if (image.format.group == ImageFormatGroup.bgra8888 &&
        image.planes.isNotEmpty) {
      return _bgraRegion(image, left, top, width, height);
    }
    if (image.format.group == ImageFormatGroup.yuv420 &&
        image.planes.length >= 3) {
      return _yuv420Region(image, left, top, width, height);
    }
    return null;
  }

  static img.Image _bgraRegion(
    CameraImage image,
    int left,
    int top,
    int width,
    int height,
  ) {
    final plane = image.planes.first;
    final rowStride = plane.bytesPerRow;
    final bytes = plane.bytes;
    final out = img.Image(width: width, height: height);
    for (var y = 0; y < height; y++) {
      final srcRow = (top + y) * rowStride + left * 4;
      for (var x = 0; x < width; x++) {
        final i = srcRow + x * 4;
        if (i + 3 >= bytes.length) continue;
        // BGRA
        out.setPixelRgba(
          x,
          y,
          bytes[i + 2],
          bytes[i + 1],
          bytes[i],
          bytes[i + 3],
        );
      }
    }
    return out;
  }

  static img.Image _yuv420Region(
    CameraImage image,
    int left,
    int top,
    int width,
    int height,
  ) {
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final yBytes = yPlane.bytes;
    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;
    final yRowStride = yPlane.bytesPerRow;
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;
    final out = img.Image(width: width, height: height);

    for (var dy = 0; dy < height; dy++) {
      final sy = top + dy;
      for (var dx = 0; dx < width; dx++) {
        final sx = left + dx;
        final yIndex = sy * yRowStride + sx;
        final uvIndex =
            (sy >> 1) * uvRowStride + (sx >> 1) * uvPixelStride;
        if (yIndex >= yBytes.length ||
            uvIndex >= uBytes.length ||
            uvIndex >= vBytes.length) {
          continue;
        }
        final y = yBytes[yIndex];
        final u = uBytes[uvIndex];
        final v = vBytes[uvIndex];
        // BT.601 YUV → RGB
        final r = (y + 1.370705 * (v - 128)).round().clamp(0, 255);
        final g =
            (y - 0.337633 * (u - 128) - 0.698001 * (v - 128)).round().clamp(0, 255);
        final b = (y + 1.732446 * (u - 128)).round().clamp(0, 255);
        out.setPixelRgb(dx, dy, r, g, b);
      }
    }
    return out;
  }
}

/// Small upright RGB region + geometry remapped into crop space.
class CameraRegionCrop {
  const CameraRegionCrop({
    required this.rgb,
    required this.faceBoxInCrop,
    required this.uprightFrameSize,
    required this.regionInUpright,
    this.leftEye,
    this.rightEye,
    this.nose,
    this.mouthLeft,
    this.mouthRight,
  });

  final img.Image rgb;
  final Rect faceBoxInCrop;
  final Size uprightFrameSize;
  final Rect regionInUpright;
  final Offset? leftEye;
  final Offset? rightEye;
  final Offset? nose;
  final Offset? mouthLeft;
  final Offset? mouthRight;
}
