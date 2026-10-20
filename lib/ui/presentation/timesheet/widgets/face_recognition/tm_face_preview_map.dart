import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Upright size matching ML Kit face boxes / green marker space.
///
/// Camera buffers are often landscape while the UI is portrait. Face boxes are
/// in the rotated upright frame — swap width/height when orientations disagree
/// so guide geometry and marker mapping share one space.
Size uprightImageSize({
  required Size imageSize,
  required Size viewSize,
}) {
  if (imageSize.width <= 0 || imageSize.height <= 0) return imageSize;
  final viewPortrait = viewSize.height >= viewSize.width;
  final imagePortrait = imageSize.height >= imageSize.width;
  if (viewPortrait == imagePortrait) return imageSize;
  return Size(imageSize.height, imageSize.width);
}

/// Maps an upright ML Kit face box into the preview view (BoxFit.cover/contain).
({double scale, double dx, double dy, Size upright}) mapFaceBoxToPreview({
  required Size viewSize,
  required Size imageSize,
  required BoxFit fit,
}) {
  final upright = uprightImageSize(imageSize: imageSize, viewSize: viewSize);
  final sx = viewSize.width / upright.width;
  final sy = viewSize.height / upright.height;
  final scale = fit == BoxFit.contain ? math.min(sx, sy) : math.max(sx, sy);
  final dx = (viewSize.width - upright.width * scale) / 2;
  final dy = (viewSize.height - upright.height * scale) / 2;
  return (scale: scale, dx: dx, dy: dy, upright: upright);
}

Rect scaleFaceBoxToView({
  required Rect box,
  required Size viewSize,
  required Size imageSize,
  required BoxFit fit,
  bool mirrorX = false,
}) {
  final m = mapFaceBoxToPreview(
    viewSize: viewSize,
    imageSize: imageSize,
    fit: fit,
  );
  // [box] is in upright image space (same as [m.upright]).
  final mapped = mirrorX
      ? Rect.fromLTRB(
          m.upright.width - box.right,
          box.top,
          m.upright.width - box.left,
          box.bottom,
        )
      : box;
  return Rect.fromLTRB(
    m.dx + mapped.left * m.scale,
    m.dy + mapped.top * m.scale,
    m.dx + mapped.right * m.scale,
    m.dy + mapped.bottom * m.scale,
  );
}
