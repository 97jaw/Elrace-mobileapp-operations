import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:image/image.dart' as img;

/// Crop a caller asks for. [fivePoint] only when the probe is compared with
/// phone-built profile templates; anything compared with server/enrollment
/// templates must use [legacy].
enum FaceChipCrop { fivePoint, legacy }

/// Crop that actually produced a chip (`align=` in logs).
enum FaceChipAlign {
  fivePoint('5pt'),
  legacy('legacy'),
  fallback('fallback');

  const FaceChipAlign(this.logName);

  final String logName;
}

/// 2-D similarity: `x' = a·x − b·y + tx`, `y' = b·x + a·y + ty`.
class FaceSimilarityTransform {
  const FaceSimilarityTransform(this.a, this.b, this.tx, this.ty);

  final double a;
  final double b;
  final double tx;
  final double ty;

  double get scale => math.sqrt(a * a + b * b);

  Offset apply(Offset p) =>
      Offset(a * p.dx - b * p.dy + tx, b * p.dx + a * p.dy + ty);

  Offset applyInverse(Offset p) {
    final d = a * a + b * b;
    final x = p.dx - tx;
    final y = p.dy - ty;
    return Offset((a * x + b * y) / d, (-b * x + a * y) / d);
  }
}

/// ArcFace 5-point alignment to the 112×112 InsightFace reference.
abstract final class FaceAlignment {
  /// Image-left eye, image-right eye, nose tip, image-left mouth corner,
  /// image-right mouth corner.
  static const List<Offset> reference = [
    Offset(38.2946, 51.6963),
    Offset(73.5318, 51.5014),
    Offset(56.0252, 71.7366),
    Offset(41.5493, 92.3655),
    Offset(70.7299, 92.2041),
  ];

  /// Source points in [reference] order, or null if any landmark is missing.
  /// ML Kit names are the subject's left/right, so pairs are ordered by x.
  static List<Offset>? sourcePoints({
    required Offset? eyeA,
    required Offset? eyeB,
    required Offset? nose,
    required Offset? mouthA,
    required Offset? mouthB,
  }) {
    if (eyeA == null ||
        eyeB == null ||
        nose == null ||
        mouthA == null ||
        mouthB == null) {
      return null;
    }
    final eyes = eyeA.dx <= eyeB.dx ? [eyeA, eyeB] : [eyeB, eyeA];
    final mouth = mouthA.dx <= mouthB.dx ? [mouthA, mouthB] : [mouthB, mouthA];
    return [eyes[0], eyes[1], nose, mouth[0], mouth[1]];
  }

  /// Least-squares similarity (Umeyama, no reflection) mapping [src] onto
  /// [dst]. Null when the source points are collapsed or the result is not
  /// finite.
  static FaceSimilarityTransform? estimate(List<Offset> src, List<Offset> dst) {
    final n = src.length;
    if (n < 2 || dst.length != n) return null;
    var msx = 0.0, msy = 0.0, mdx = 0.0, mdy = 0.0;
    for (var i = 0; i < n; i++) {
      msx += src[i].dx;
      msy += src[i].dy;
      mdx += dst[i].dx;
      mdy += dst[i].dy;
    }
    msx /= n;
    msy /= n;
    mdx /= n;
    mdy /= n;
    var srcVar = 0.0, dot = 0.0, cross = 0.0;
    for (var i = 0; i < n; i++) {
      final sx = src[i].dx - msx;
      final sy = src[i].dy - msy;
      final dx = dst[i].dx - mdx;
      final dy = dst[i].dy - mdy;
      srcVar += sx * sx + sy * sy;
      dot += sx * dx + sy * dy;
      cross += sx * dy - sy * dx;
    }
    if (!srcVar.isFinite || srcVar < 1.0) return null;
    final a = dot / srcVar;
    final b = cross / srcVar;
    final t = FaceSimilarityTransform(
      a,
      b,
      mdx - (a * msx - b * msy),
      mdy - (b * msx + a * msy),
    );
    final s = t.scale;
    if (!s.isFinite || s < 1e-3 || !t.tx.isFinite || !t.ty.isFinite) {
      return null;
    }
    return t;
  }

  /// Bilinear warp of [source] through [t] into a [width]×[height] RGB image.
  /// Samples outside [source] are black.
  static img.Image warp(
    img.Image source,
    FaceSimilarityTransform t, {
    int width = 112,
    int height = 112,
  }) {
    final out = img.Image(width: width, height: height);
    final sw = source.width;
    final sh = source.height;
    final d = t.a * t.a + t.b * t.b;
    final ia = t.a / d;
    final ib = t.b / d;
    for (var y = 0; y < height; y++) {
      final ry = y - t.ty;
      for (var x = 0; x < width; x++) {
        final rx = x - t.tx;
        final sx = ia * rx + ib * ry;
        final sy = -ib * rx + ia * ry;
        final x0 = sx.floor();
        final y0 = sy.floor();
        final fx = sx - x0;
        final fy = sy - y0;
        var r = 0.0, g = 0.0, bl = 0.0;
        void add(int px, int py, double w) {
          if (w <= 0 || px < 0 || py < 0 || px >= sw || py >= sh) return;
          final p = source.getPixel(px, py);
          r += p.r * w;
          g += p.g * w;
          bl += p.b * w;
        }

        add(x0, y0, (1 - fx) * (1 - fy));
        add(x0 + 1, y0, fx * (1 - fy));
        add(x0, y0 + 1, (1 - fx) * fy);
        add(x0 + 1, y0 + 1, fx * fy);
        out.setPixelRgb(
          x,
          y,
          r.round().clamp(0, 255),
          g.round().clamp(0, 255),
          bl.round().clamp(0, 255),
        );
      }
    }
    return out;
  }
}
