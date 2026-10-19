import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:el_race/ui/presentation/timesheet/widgets/face_recognition/tm_face_preview_map.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Distance-hint silhouette visibility (driven without panel [setState]).
@immutable
class DistanceSilhouetteHintState {
  const DistanceSilhouetteHintState({
    required this.show,
    required this.imageSize,
    required this.fit,
    required this.mirrorX,
    this.safeTop = 0,
    this.safeBottom = 0,
  });

  static const hidden = DistanceSilhouetteHintState(
    show: false,
    imageSize: Size.zero,
    fit: BoxFit.cover,
    mirrorX: false,
  );

  final bool show;

  /// Raw size from the camera path; may be landscape on iOS. [uprightImageSize]
  /// normalizes before guide geometry.
  final Size imageSize;
  final BoxFit fit;
  final bool mirrorX;

  /// Preview-local inset under header / status chrome (keep head clear).
  final double safeTop;

  /// Preview-local inset above bottom controls (keep head clear).
  final double safeBottom;

  DistanceSilhouetteHintState copyWith({
    bool? show,
    Size? imageSize,
    BoxFit? fit,
    bool? mirrorX,
    double? safeTop,
    double? safeBottom,
  }) {
    return DistanceSilhouetteHintState(
      show: show ?? this.show,
      imageSize: imageSize ?? this.imageSize,
      fit: fit ?? this.fit,
      mirrorX: mirrorX ?? this.mirrorX,
      safeTop: safeTop ?? this.safeTop,
      safeBottom: safeBottom ?? this.safeBottom,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DistanceSilhouetteHintState &&
        other.show == show &&
        other.imageSize == imageSize &&
        other.fit == fit &&
        other.mirrorX == mirrorX &&
        other.safeTop == safeTop &&
        other.safeBottom == safeBottom;
  }

  @override
  int get hashCode =>
      Object.hash(show, imageSize, fit, mirrorX, safeTop, safeBottom);
}

/// SVG face-region anchors in viewBox units (viewBox 0 0 36 32).
const double kDistanceGuideSvgFaceWidth = 17;
const double kDistanceGuideSvgFaceCenterX = 18;
const double kDistanceGuideSvgFaceCenterY = 12.75;
const double kDistanceGuideSvgChinY = 21;
const double kDistanceGuideSvgViewW = 36;
const double kDistanceGuideSvgViewH = 32;
const double kDistanceGuideSvgHeadBottomY = 21;

const String _kFaceMaleSvgAsset = 'assets/svg/face-male.svg';

/// Debug target-box flag (default on in debug). Disable with
/// `--dart-define=DISTANCE_GUIDE_CALIBRATE=false`.
const bool kDistanceGuideCalibrate = bool.fromEnvironment(
  'DISTANCE_GUIDE_CALIBRATE',
  defaultValue: true,
);

const SvgAssetLoader _faceMaleSvgLoader = SvgAssetLoader(_kFaceMaleSvgAsset);

Widget _faceMaleSvgPicture() => const SvgPicture(
      _faceMaleSvgLoader,
      fit: BoxFit.fill,
      colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
      excludeFromSemantics: true,
    );

/// Pulsing SVG ghost for too-close distance guidance.
class TmDistanceGhostSilhouette extends StatefulWidget {
  const TmDistanceGhostSilhouette({
    super.key,
    required this.listenable,
  });

  final ValueListenable<DistanceSilhouetteHintState> listenable;

  @override
  State<TmDistanceGhostSilhouette> createState() =>
      _TmDistanceGhostSilhouetteState();
}

class _TmDistanceGhostSilhouetteState extends State<TmDistanceGhostSilhouette>
    with TickerProviderStateMixin {
  static const _pulsePeriod = Duration(milliseconds: 1400);
  static const _fadeIn = Duration(milliseconds: 200);
  static const _fadeOut = Duration(milliseconds: 200);

  AnimationController? _pulse;
  AnimationController? _fade;
  bool _wantVisible = false;

  Size? _geomViewSize;
  DistanceSilhouetteHintState? _geomHint;
  _GuideGeom? _geom;
  bool _guideLayoutLogged = false;

  @override
  void initState() {
    super.initState();
    widget.listenable.addListener(_onHint);
    _onHint();
  }

  @override
  void didUpdateWidget(covariant TmDistanceGhostSilhouette oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listenable != widget.listenable) {
      oldWidget.listenable.removeListener(_onHint);
      widget.listenable.addListener(_onHint);
      _onHint();
    }
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_onHint);
    _tearDownControllers();
    super.dispose();
  }

  void _onHint() {
    final show = widget.listenable.value.show;
    _geom = null;
    if (!show) _guideLayoutLogged = false;
    if (show) {
      _show();
    } else {
      _hide();
    }
    if (mounted) setState(() {});
  }

  void _show() {
    _wantVisible = true;
    _ensureControllers();
    final fade = _fade!;
    final pulse = _pulse!;
    fade.duration = _fadeIn;
    fade.forward();
    if (!pulse.isAnimating) {
      pulse.repeat(reverse: true);
    }
  }

  void _hide() {
    if (!_wantVisible && (_fade == null || _fade!.value == 0)) {
      _tearDownControllers();
      return;
    }
    _wantVisible = false;
    final fade = _fade;
    final pulse = _pulse;
    if (fade == null) {
      _tearDownControllers();
      return;
    }
    fade.duration = _fadeOut;
    fade.reverse().whenComplete(() {
      if (!_wantVisible) {
        pulse?.stop();
        _tearDownControllers();
        if (mounted) setState(() {});
      }
    });
  }

  void _ensureControllers() {
    _fade ??= AnimationController(vsync: this, duration: _fadeIn, value: 0)
      ..addListener(() {
        if (mounted) setState(() {});
      });
    _pulse ??= AnimationController(vsync: this, duration: _pulsePeriod)
      ..addListener(() {
        if (mounted) setState(() {});
      });
  }

  void _tearDownControllers() {
    _pulse?.dispose();
    _fade?.dispose();
    _pulse = null;
    _fade = null;
  }

  double get _opacity {
    final fade = _fade?.value ?? 0.0;
    final pulseT = _pulse?.value ?? 0.0;
    final pulse = 0.45 + 0.45 * Curves.easeInOut.transform(pulseT);
    return (fade * pulse).clamp(0.0, 1.0);
  }

  _GuideGeom _geometryFor(Size viewSize, DistanceSilhouetteHintState hint) {
    if (_geom != null &&
        _geomViewSize == viewSize &&
        _geomHint == hint) {
      return _geom!;
    }
    final g = _computeGuideGeom(viewSize, hint);
    _geomViewSize = viewSize;
    _geomHint = hint;
    _geom = g;
    if (kDebugMode && !_guideLayoutLogged) {
      _guideLayoutLogged = true;
      final box = g.mappedFace;
      final cxPct = (box.center.dx / viewSize.width) * 100;
      final cyPct = (box.center.dy / viewSize.height) * 100;
      debugPrint(
        'Guide: platform=${Platform.isIOS ? 'ios' : Platform.isAndroid ? 'android' : 'other'} '
        'uprightSize=${g.upright.width.toStringAsFixed(0)}x${g.upright.height.toStringAsFixed(0)} '
        'previewSize=${viewSize.width.toStringAsFixed(0)}x${viewSize.height.toStringAsFixed(0)} '
        'box_view=(${box.left.toStringAsFixed(0)},${box.top.toStringAsFixed(0)},'
        '${box.width.toStringAsFixed(0)},${box.height.toStringAsFixed(0)}) '
        'center_view=(${cxPct.toStringAsFixed(0)}%,${cyPct.toStringAsFixed(0)}%)',
      );
    }
    return g;
  }

  @override
  Widget build(BuildContext context) {
    final hint = widget.listenable.value;
    final opacity = _opacity;
    if (opacity <= 0.001 ||
        hint.imageSize.width <= 0 ||
        hint.imageSize.height <= 0) {
      return const SizedBox.expand();
    }

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewSize = Size(constraints.maxWidth, constraints.maxHeight);
          if (viewSize.width <= 0 || viewSize.height <= 0) {
            return const SizedBox.expand();
          }
          final geom = _geometryFor(viewSize, hint);
          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: [
              if (kDebugMode && kDistanceGuideCalibrate)
                CustomPaint(
                  painter: _TargetBoxPainter(geom.mappedFace),
                ),
              // Silhouette first; opaque label above so outlines never cross text.
              Positioned(
                left: geom.svgLeft,
                top: geom.svgTop,
                width: geom.svgW,
                height: geom.svgH,
                child: Opacity(
                  opacity: opacity,
                  child: _faceMaleSvgPicture(),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                top: geom.labelTop,
                child: Opacity(
                  opacity: opacity,
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Text(
                          'Move back a little',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GuideGeom {
  const _GuideGeom({
    required this.upright,
    required this.mappedFace,
    required this.svgLeft,
    required this.svgTop,
    required this.svgW,
    required this.svgH,
    required this.labelTop,
  });

  final Size upright;
  final Rect mappedFace;
  final double svgLeft;
  final double svgTop;
  final double svgW;
  final double svgH;
  final double labelTop;
}

/// Target face box in upright camera-image space (same space as ML Kit boxes).
Rect distanceGuideFaceBoxInImage(Size uprightSize) {
  final shortSide = math.min(uprightSize.width, uprightSize.height);
  final faceW = shortSide * 0.35;
  final faceH = faceW * 1.1;
  final cx = uprightSize.width * 0.5;
  final cy = uprightSize.height * 0.42;
  return Rect.fromCenter(center: Offset(cx, cy), width: faceW, height: faceH);
}

_GuideGeom _computeGuideGeom(Size viewSize, DistanceSilhouetteHintState hint) {
  // Same upright space the green marker uses (swap landscape buffer on iOS).
  final upright = uprightImageSize(
    imageSize: hint.imageSize,
    viewSize: viewSize,
  );
  final faceInUpright = distanceGuideFaceBoxInImage(upright);
  // Pass upright size so mapFaceBoxToPreview does not swap a second time.
  final mapped = scaleFaceBoxToView(
    box: faceInUpright,
    viewSize: viewSize,
    imageSize: upright,
    fit: hint.fit,
    mirrorX: hint.mirrorX,
  );

  final s = mapped.width / kDistanceGuideSvgFaceWidth;
  final svgW = kDistanceGuideSvgViewW * s;
  final svgH = kDistanceGuideSvgViewH * s;
  var left = mapped.center.dx - kDistanceGuideSvgFaceCenterX * s;
  var top = mapped.center.dy - kDistanceGuideSvgFaceCenterY * s;

  // Keep fully on-screen horizontally (mapping already centers; clamp only).
  left = left.clamp(0.0, math.max(0.0, viewSize.width - svgW));

  // Head = SVG y 0…21; vertical-only shift clear of header / bottom chrome.
  final headTop = top;
  final headBottom = top + kDistanceGuideSvgHeadBottomY * s;
  final minHeadTop = hint.safeTop;
  final maxHeadBottom = viewSize.height - hint.safeBottom;
  var dy = 0.0;
  if (headTop < minHeadTop) {
    dy = minHeadTop - headTop;
  }
  if (headBottom + dy > maxHeadBottom) {
    dy = maxHeadBottom - headBottom;
  }
  if (headTop + dy < minHeadTop) {
    dy = minHeadTop - headTop;
  }
  top += dy;

  // Label at neck (chin Y), sitting above the silhouette with opaque pill.
  const labelHeight = 15.0 * 1.15 + 16.0; // font + vertical padding
  final neckY = top + kDistanceGuideSvgChinY * s;
  final labelTop = neckY - labelHeight - 4;

  return _GuideGeom(
    upright: upright,
    mappedFace: mapped,
    svgLeft: left,
    svgTop: top,
    svgW: svgW,
    svgH: svgH,
    labelTop: labelTop,
  );
}

class _TargetBoxPainter extends CustomPainter {
  const _TargetBoxPainter(this.box);

  final Rect box;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFF00E676);
    canvas.drawRect(box, paint);
  }

  @override
  bool shouldRepaint(covariant _TargetBoxPainter oldDelegate) =>
      oldDelegate.box != box;
}
