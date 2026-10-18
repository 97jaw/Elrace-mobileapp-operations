import 'dart:io';

import 'package:flutter/foundation.dart';

/// Android-only capture performance profile for best-frame / live detect.
///
/// Low-end (budget SoC): fewer TFLite threads, sequential MiniFASNet, downscaled
/// ML Kit input, ~3 evidence cycles/s. Fast Android keeps 4 threads + parallel
/// PAD + full-res detect. iOS never reads this.
abstract final class AndroidFaceCapturePerf {
  static bool _lowEnd = false;

  /// Emb self-test ms above this → promote to low-end (if not already).
  static const int embMsPromoteThreshold = 200;

  /// Combined MiniFASNet self-test ms above this → promote.
  static const int padPairMsPromoteThreshold = 350;

  /// Rolling avg detect_ms above this (after a few frames) → promote.
  static const int detectMsPromoteThreshold = 120;

  static bool get isLowEnd => Platform.isAndroid && _lowEnd;

  static int get tfliteThreads {
    if (!Platform.isAndroid) return 4;
    return _lowEnd ? 2 : 4;
  }

  /// When true, MiniFASNet V2 then V1SE (no Future.wait).
  static bool get sequentialPad => isLowEnd;

  /// Feed ML Kit a ~640-wide NV21; map boxes back to full upright.
  static bool get downscaleMlKit => isLowEnd;

  /// Evidence loop min interval (~3/s on low-end, ~5/s otherwise).
  static Duration get evidenceProcessInterval => isLowEnd
      ? const Duration(milliseconds: 333)
      : const Duration(milliseconds: 200);

  static const int mlKitTargetWidth = 640;

  /// Call before first [FaceEmbedder] / [MinifasnetFusionEngine] load.
  static void configure({required bool lowEnd}) {
    if (!Platform.isAndroid) {
      _lowEnd = false;
      return;
    }
    if (_lowEnd == lowEnd) return;
    _lowEnd = lowEnd;
    debugPrint(
      'AndroidFaceCapturePerf: lowEnd=$_lowEnd threads=$tfliteThreads '
      'sequentialPad=$sequentialPad downscaleMlKit=$downscaleMlKit '
      'evidence_ms=${evidenceProcessInterval.inMilliseconds}',
    );
  }

  /// Promote to low-end from self-test / measured latency. Returns true if newly set.
  static bool promoteIfSlow({int? embMs, int? padPairMs, int? detectMs}) {
    if (!Platform.isAndroid || _lowEnd) return false;
    final slowEmb = embMs != null && embMs >= embMsPromoteThreshold;
    final slowPad =
        padPairMs != null && padPairMs >= padPairMsPromoteThreshold;
    final slowDetect =
        detectMs != null && detectMs >= detectMsPromoteThreshold;
    if (!slowEmb && !slowPad && !slowDetect) return false;
    configure(lowEnd: true);
    debugPrint(
      'AndroidFaceCapturePerf: promoted lowEnd from '
      'emb_ms=$embMs pad_pair_ms=$padPairMs detect_ms=$detectMs',
    );
    return true;
  }
}
