import 'dart:io';

import 'package:flutter/foundation.dart';

/// Android-only capture performance profile for best-frame / live detect.
///
/// Low-end is decided from self-test timings (and very low RAM), not from a
/// coarse RAM/cores tier. Budget SoC: fewer TFLite threads, sequential
/// MiniFASNet, downscaled ML Kit input, ~3 evidence cycles/s. iOS never reads
/// this.
abstract final class AndroidFaceCapturePerf {
  static bool _lowEnd = false;
  static bool _loggedLowEndWhyThisCamera = false;

  /// Emb self-test (best of 2) above this → low-end.
  static const int embMsLowEndThreshold = 200;

  /// Combined MiniFASNet self-test (best of 2) above this → low-end.
  static const int padPairMsLowEndThreshold = 300;

  /// Physical RAM below this → low-end regardless of self-test.
  static const double ramGbLowEndThreshold = 4.0;

  /// Runtime detect promote: skip first N detections (warm-up), then require
  /// median detect_ms over [detectMsSampleCount] frames above this.
  static const int detectMsPromoteThreshold = 300;
  static const int detectMsWarmupSkip = 5;
  static const int detectMsSampleCount = 10;

  static final List<int> _detectMsSamples = <int>[];
  static int _detectMsSeen = 0;

  static bool get isLowEnd => Platform.isAndroid && _lowEnd;

  /// Call at camera open so the why-log can fire once for this session.
  static void resetLowEndWhyLogForCameraOpen() {
    _loggedLowEndWhyThisCamera = false;
    _detectMsSamples.clear();
    _detectMsSeen = 0;
  }

  /// One line per camera open when [isLowEnd] is true.
  static void logLowEndWhyOnce({
    required String rule,
    String? model,
    int? cores,
    double? ramGb,
    int? embMs,
    int? padPairMs,
    int? detectMs,
  }) {
    if (!Platform.isAndroid || !_lowEnd || _loggedLowEndWhyThisCamera) {
      return;
    }
    _loggedLowEndWhyThisCamera = true;
    debugPrint(
      'AndroidFaceCapturePerf: lowEnd=true why=$rule '
      'model=${model ?? '-'} cores=${cores ?? '-'} '
      'ram_gb=${ramGb != null ? ramGb.toStringAsFixed(1) : '-'} '
      'emb_ms=${embMs ?? '-'} pad_pair_ms=${padPairMs ?? '-'} '
      'detect_ms=${detectMs ?? '-'} threads=$tfliteThreads '
      'sequentialPad=$sequentialPad',
    );
  }

  static int get tfliteThreads {
    if (!Platform.isAndroid) return 4;
    return _lowEnd ? 2 : 4;
  }

  /// When true, MiniFASNet V2 then V1SE (no Future.wait).
  static bool get sequentialPad => isLowEnd;

  /// Feed ML Kit a ~640-wide NV21 on all Android (cuts GC; PAD uses region crop).
  static bool get downscaleMlKit => Platform.isAndroid;

  /// Prefer a lighter camera stream when low-end (preview+stream share preset).
  static bool get preferMediumStream => isLowEnd;

  /// When low-end but still on 720p (medium unavailable), process every Nth.
  /// With [preferMediumStream] the lighter preset is enough — process all.
  static int get streamProcessEveryNth =>
      isLowEnd && !preferMediumStream ? 2 : 1;

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

  /// Decide low-end from RAM + self-test (best-of-2) timings. Logs once.
  ///
  /// [lowEnd] when: ram &lt; 4 GB, or emb &gt; 200 ms, or pad pair &gt; 300 ms.
  static bool decideFromSelfTest({
    required double? ramGb,
    required int embMs,
    required int padPairMs,
    String? model,
    int? cores,
  }) {
    if (!Platform.isAndroid) {
      configure(lowEnd: false);
      return false;
    }
    final lowRam =
        ramGb != null && ramGb > 0 && ramGb < ramGbLowEndThreshold;
    final slowEmb = embMs > embMsLowEndThreshold;
    final slowPad = padPairMs > padPairMsLowEndThreshold;
    final lowEnd = lowRam || slowEmb || slowPad;
    final rule = lowRam
        ? 'ram_gb<${ramGbLowEndThreshold.toStringAsFixed(0)}'
        : slowEmb
            ? 'selftest_emb_ms>$embMsLowEndThreshold'
            : slowPad
                ? 'selftest_pad_pair_ms>$padPairMsLowEndThreshold'
                : 'selftest_fast';
    configure(lowEnd: lowEnd);
    debugPrint(
      'AndroidFaceCapturePerf: decide lowEnd=$lowEnd rule=$rule '
      'model=${model ?? '-'} cores=${cores ?? '-'} '
      'ram_gb=${ramGb != null ? ramGb.toStringAsFixed(1) : '-'} '
      'emb_ms=$embMs (limit=$embMsLowEndThreshold) '
      'pad_pair_ms=$padPairMs (limit=$padPairMsLowEndThreshold)',
    );
    if (lowEnd) {
      logLowEndWhyOnce(
        rule: rule,
        model: model,
        cores: cores,
        ramGb: ramGb,
        embMs: embMs,
        padPairMs: padPairMs,
      );
    }
    return lowEnd;
  }

  /// Promote to low-end from self-test timings (emb/pad). Detect_ms uses
  /// [noteDetectMs] instead (warm-up + median).
  static bool promoteIfSlow({
    int? embMs,
    int? padPairMs,
    String? model,
    int? cores,
    double? ramGb,
  }) {
    if (!Platform.isAndroid || _lowEnd) return false;
    final slowEmb = embMs != null && embMs > embMsLowEndThreshold;
    final slowPad =
        padPairMs != null && padPairMs > padPairMsLowEndThreshold;
    if (!slowEmb && !slowPad) return false;
    final rule = slowEmb
        ? 'selftest_emb_ms>$embMsLowEndThreshold'
        : 'selftest_pad_pair_ms>$padPairMsLowEndThreshold';
    configure(lowEnd: true);
    logLowEndWhyOnce(
      rule: rule,
      model: model,
      cores: cores,
      ramGb: ramGb,
      embMs: embMs,
      padPairMs: padPairMs,
    );
    return true;
  }

  /// Record one detection time. After warm-up, if median of the last
  /// [detectMsSampleCount] samples &gt; [detectMsPromoteThreshold], promote.
  static bool noteDetectMs(
    int detectMs, {
    String? model,
    int? cores,
    double? ramGb,
  }) {
    if (!Platform.isAndroid || _lowEnd) return false;
    _detectMsSeen += 1;
    if (_detectMsSeen <= detectMsWarmupSkip) {
      return false;
    }
    _detectMsSamples.add(detectMs);
    if (_detectMsSamples.length > detectMsSampleCount) {
      _detectMsSamples.removeAt(0);
    }
    if (_detectMsSamples.length < detectMsSampleCount) return false;
    final sorted = List<int>.from(_detectMsSamples)..sort();
    final median = sorted[sorted.length ~/ 2];
    if (median <= detectMsPromoteThreshold) return false;
    configure(lowEnd: true);
    debugPrint(
      'AndroidFaceCapturePerf: switch lowEnd=true '
      'why=median_detect_ms>$detectMsPromoteThreshold '
      'median=$median samples=$_detectMsSamples '
      'warmup_skipped=$detectMsWarmupSkip '
      'model=${model ?? '-'} cores=${cores ?? '-'} '
      'ram_gb=${ramGb != null ? ramGb.toStringAsFixed(1) : '-'}',
    );
    logLowEndWhyOnce(
      rule: 'median_detect_ms>$detectMsPromoteThreshold',
      model: model,
      cores: cores,
      ramGb: ramGb,
      detectMs: median,
    );
    return true;
  }
}
