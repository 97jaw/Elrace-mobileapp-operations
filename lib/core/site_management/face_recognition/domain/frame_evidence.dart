import 'dart:math' as math;
import 'dart:ui';

import 'package:el_race/core/site_management/face_recognition/antispoof/antispoof_config.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/temporal_pad_heuristics.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/timesheet_face_classification_snapshot.dart';
import 'package:el_race/core/site_management/face_recognition/domain/face_alignment.dart';
import 'package:el_race/core/site_management/face_recognition/domain/face_verifier.dart';
import 'package:el_race/core/timesheet/services/face_capture_service.dart';
import 'package:image/image.dart' as img;

/// Per-frame PAD classification for the best-frame window.
enum FramePadVerdict {
  live,
  spoof,
  uncertain,
  notEligible,
  error,
}

/// Per-frame 1:1 identity status for the best-frame window.
enum FrameIdentityStatus {
  verified,
  notVerified,
  notEligible,
}

/// Dominant reason no frame was identity- or PAD-usable (Task 09 hints).
enum FrameUsableDominant {
  tooFar,
  tooClose,
  angle,
  blur,
  dark,
  none,
}

/// Rolling evidence for one processed stream frame (TASK 08).
class FrameEvidence {
  FrameEvidence({
    required this.timestamp,
    required this.faceBox,
    required this.frameSize,
    required this.qualityScore,
    required this.identityStatus,
    required this.pad,
    this.rgbFrame,
    this.identity,
    this.classification,
    this.landmarks,
    this.ineligibleReason = FrameUsableDominant.none,
    this.sharpness = 0,
    this.brightness = 0,
  });

  final DateTime timestamp;
  final Rect faceBox;

  /// Upright decoded frame size (width × height).
  final Size frameSize;

  /// Pixels kept only while this frame is the current best candidate.
  img.Image? rgbFrame;

  final double qualityScore;
  final FrameIdentityStatus identityStatus;
  final FaceVerifyResult? identity;
  final FramePadVerdict pad;
  final TimesheetFaceClassificationSnapshot? classification;
  final TimesheetFaceLandmarkSnapshot? landmarks;
  final FrameUsableDominant ineligibleReason;
  final double sharpness;
  final double brightness;

  bool get isLiveVerified =>
      pad == FramePadVerdict.live &&
      identityStatus == FrameIdentityStatus.verified;

  void releasePixels() {
    rgbFrame = null;
  }
}

/// Marker state for Task 09 (square + emp id). No name.
sealed class BestFrameMarkerState {
  const BestFrameMarkerState();
  static const none = BestFrameMarkerNone();
}

class BestFrameMarkerNone extends BestFrameMarkerState {
  const BestFrameMarkerNone();
}

class BestFrameMarkerVerified extends BestFrameMarkerState {
  const BestFrameMarkerVerified({
    required this.employeeId,
    required this.faceBox,
  });

  final int employeeId;
  final Rect faceBox;
}

/// Result of [evaluateBestFrameAccept].
class BestFrameAcceptDecision {
  const BestFrameAcceptDecision({
    required this.accepted,
    this.rejectReason,
    this.waitReason,
    this.best,
    this.windowCount = 0,
    this.liveVerifiedCount = 0,
    this.spoofCount = 0,
  });

  final bool accepted;

  /// Hard reject (e.g. `spoof`); caller clears window + cooldown.
  final String? rejectReason;

  /// Soft: rule not yet met (`need_frames`, `span`, `temporal`, …).
  final String? waitReason;
  final FrameEvidence? best;
  final int windowCount;
  final int liveVerifiedCount;
  final int spoofCount;
}

/// Frame-relative eligibility and accept rule (TASK 08 / approach §3).
abstract final class BestFrameRules {
  static const Duration windowDuration = Duration(milliseconds: 1200);
  static const Duration windowDurationMin = Duration(milliseconds: 1200);
  static const Duration windowDurationMax = Duration(milliseconds: 2500);
  static const double windowIntervalFactor = 3.5;
  static const Duration minAcceptSpan = Duration(milliseconds: 400);
  static const Duration processInterval = Duration(milliseconds: 200);
  static const Duration processIntervalLowEnd = Duration(milliseconds: 400);
  static const Duration spoofCooldown = Duration(milliseconds: 1500);
  static const Duration manualWait = Duration(milliseconds: 1500);
  static const Duration waitingLogInterval = Duration(seconds: 2);
  static const Duration markerSafetyStale = Duration(milliseconds: 1800);

  /// Adaptive evidence window: `clamp(3.5 × avgInterval, 1.2 s, 2.5 s)`.
  static Duration adaptiveWindowDuration(Duration avgProcessedInterval) {
    final ms = (avgProcessedInterval.inMilliseconds * windowIntervalFactor)
        .round()
        .clamp(
          windowDurationMin.inMilliseconds,
          windowDurationMax.inMilliseconds,
        );
    return Duration(milliseconds: ms);
  }

  /// Ideal face width as a fraction of the upright short side.
  static const double idealFaceWidthFraction = 0.35;

  static const double identityMinWidthFraction = 0.08;
  static const double identityMaxYawDeg = 35;
  static const double identityMaxRollDeg = 30;

  static const double padMinWidthFraction = 0.10;
  // max uses AntispoofConfig.maxFaceWidthFraction (0.55)
  static const double padMaxYawDeg = 30;

  /// Same still-path floor as [TimesheetFaceCaptureService.minSharpnessScore].
  static const double minSharpness = TimesheetFaceCaptureService.minSharpnessScore;

  static bool hasFiveLandmarks(TimesheetFaceLandmarkSnapshot? landmarks) {
    if (landmarks == null) return false;
    return FaceAlignment.sourcePoints(
          eyeA: landmarks.leftEye,
          eyeB: landmarks.rightEye,
          nose: landmarks.nose,
          mouthA: landmarks.mouthLeft,
          mouthB: landmarks.mouthRight,
        ) !=
        null;
  }

  static double shortSide(Size frameSize) =>
      math.min(frameSize.width, frameSize.height);

  static double faceWidthFraction(Rect faceBox, Size frameSize) {
    final short = shortSide(frameSize);
    if (short <= 0) return 0;
    return faceBox.width / short;
  }

  static bool boxFullyInside(Rect faceBox, Size frameSize) {
    return faceBox.left >= 0 &&
        faceBox.top >= 0 &&
        faceBox.right <= frameSize.width + 0.5 &&
        faceBox.bottom <= frameSize.height + 0.5;
  }

  /// Identity-eligible: width ≥ 8 %, yaw ≤ 35°, roll ≤ 30°, 5 landmarks.
  static bool identityEligible({
    required Rect faceBox,
    required Size frameSize,
    required TimesheetFaceLandmarkSnapshot? landmarks,
    required TimesheetFaceClassificationSnapshot? classification,
  }) {
    if (!hasFiveLandmarks(landmarks)) return false;
    if (faceWidthFraction(faceBox, frameSize) < identityMinWidthFraction) {
      return false;
    }
    final yaw = (classification?.headEulerAngleY ?? 0).abs();
    final roll = (classification?.headEulerAngleZ ?? 0).abs();
    if (yaw > identityMaxYawDeg || roll > identityMaxRollDeg) return false;
    return true;
  }

  /// PAD-eligible: width 10–55 %, yaw ≤ 30°, box inside, sharpness ≥ still floor.
  static bool padEligible({
    required Rect faceBox,
    required Size frameSize,
    required TimesheetFaceClassificationSnapshot? classification,
    required double sharpness,
  }) {
    return padIneligibleReasons(
      faceBox: faceBox,
      frameSize: frameSize,
      classification: classification,
      sharpness: sharpness,
    ).isEmpty;
  }

  /// Human-readable PAD gate failures (too close / out of frame / angle / blur…).
  static List<String> padIneligibleReasons({
    required Rect faceBox,
    required Size frameSize,
    required TimesheetFaceClassificationSnapshot? classification,
    required double sharpness,
  }) {
    final reasons = <String>[];
    final frac = faceWidthFraction(faceBox, frameSize);
    if (frac < padMinWidthFraction) reasons.add('too_far');
    if (frac > AntispoofConfig.maxFaceWidthFraction) reasons.add('too_close');
    final yaw = (classification?.headEulerAngleY ?? 0).abs();
    if (yaw > padMaxYawDeg) reasons.add('angle');
    if (!boxFullyInside(faceBox, frameSize)) reasons.add('out_of_frame');
    if (sharpness < minSharpness) reasons.add('blur');
    return reasons;
  }

  /// Dominant ineligibility reason for Task 09 delayed hints.
  static FrameUsableDominant dominantIneligibleReason({
    required Rect faceBox,
    required Size frameSize,
    required TimesheetFaceLandmarkSnapshot? landmarks,
    required TimesheetFaceClassificationSnapshot? classification,
    required double sharpness,
    required double brightness,
  }) {
    final frac = faceWidthFraction(faceBox, frameSize);
    if (frac > AntispoofConfig.maxFaceWidthFraction) {
      return FrameUsableDominant.tooClose;
    }
    if (frac < identityMinWidthFraction) {
      return FrameUsableDominant.tooFar;
    }
    final yaw = (classification?.headEulerAngleY ?? 0).abs();
    final roll = (classification?.headEulerAngleZ ?? 0).abs();
    if (yaw > identityMaxYawDeg || roll > identityMaxRollDeg) {
      return FrameUsableDominant.angle;
    }
    if (sharpness < minSharpness) return FrameUsableDominant.blur;
    if (brightness < 0.18 || brightness > 0.92) {
      return FrameUsableDominant.dark;
    }
    if (!hasFiveLandmarks(landmarks)) return FrameUsableDominant.angle;
    return FrameUsableDominant.none;
  }

  /// Quality 0..1 — pick best frame only; never blocks.
  static double qualityScore({
    required Rect faceBox,
    required Size frameSize,
    required TimesheetFaceClassificationSnapshot? classification,
    required double sharpness,
    required double brightness,
  }) {
    final frac = faceWidthFraction(faceBox, frameSize);
    final sizeScore = (1.0 - ((frac - idealFaceWidthFraction).abs() / 0.35))
        .clamp(0.0, 1.0);

    final yaw = (classification?.headEulerAngleY ?? 90).abs();
    final roll = (classification?.headEulerAngleZ ?? 90).abs();
    final pitch = (classification?.headEulerAngleX ?? 90).abs();
    final frontal = ((1.0 - yaw / 45.0).clamp(0.0, 1.0) +
            (1.0 - roll / 40.0).clamp(0.0, 1.0) +
            (1.0 - pitch / 40.0).clamp(0.0, 1.0)) /
        3.0;

    final sharpScore = (sharpness / 40.0).clamp(0.0, 1.0);

    final left = classification?.leftEyeOpenProbability;
    final right = classification?.rightEyeOpenProbability;
    double eyes = 0.5;
    if (left != null && right != null) {
      eyes = ((left + right) / 2.0).clamp(0.0, 1.0);
    }

    // Prefer mid brightness (~0.45–0.55).
    final brightScore =
        (1.0 - ((brightness - 0.5).abs() / 0.5)).clamp(0.0, 1.0);

    return (0.30 * sizeScore +
            0.25 * frontal +
            0.20 * sharpScore +
            0.15 * eyes +
            0.10 * brightScore)
        .clamp(0.0, 1.0);
  }

  /// Mean luminance of the face crop in [0, 1].
  static double faceBrightness(img.Image source, Rect faceBox) {
    final left = faceBox.left.clamp(0, source.width - 1).toInt();
    final top = faceBox.top.clamp(0, source.height - 1).toInt();
    final width = faceBox.width.clamp(1, source.width - left).toInt();
    final height = faceBox.height.clamp(1, source.height - top).toInt();
    if (width < 2 || height < 2) return 0.5;
    var sum = 0.0;
    var n = 0;
    final stepX = math.max(1, width ~/ 16);
    final stepY = math.max(1, height ~/ 16);
    for (var y = top; y < top + height; y += stepY) {
      for (var x = left; x < left + width; x += stepX) {
        final p = source.getPixel(x, y);
        sum += (0.299 * p.r + 0.587 * p.g + 0.114 * p.b) / 255.0;
        n++;
      }
    }
    return n == 0 ? 0.5 : (sum / n).clamp(0.0, 1.0);
  }

  /// Laplacian variance on the face crop (same idea as still quality).
  static double faceSharpness(img.Image source, Rect faceBox) {
    final left = faceBox.left.clamp(0, source.width - 1).toInt();
    final top = faceBox.top.clamp(0, source.height - 1).toInt();
    final width = faceBox.width.clamp(1, source.width - left).toInt();
    final height = faceBox.height.clamp(1, source.height - top).toInt();
    if (width < 3 || height < 3) return 0;
    double lum(int x, int y) {
      final p = source.getPixel(x, y);
      return 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
    }

    var sum = 0.0;
    var sumSq = 0.0;
    var n = 0;
    for (var y = top + 1; y < top + height - 1; y++) {
      for (var x = left + 1; x < left + width - 1; x++) {
        final lap = lum(x - 1, y) +
            lum(x + 1, y) +
            lum(x, y - 1) +
            lum(x, y + 1) -
            4 * lum(x, y);
        sum += lap;
        sumSq += lap * lap;
        n++;
      }
    }
    if (n == 0) return 0;
    final mean = sum / n;
    return sumSq / n - mean * mean;
  }

  /// Prune evidence older than [duration] (default 1.2 s) before [now].
  static List<FrameEvidence> pruneWindow(
    List<FrameEvidence> window,
    DateTime now, {
    Duration duration = windowDuration,
  }) {
    final cutoff = now.subtract(duration);
    final kept = <FrameEvidence>[];
    for (final e in window) {
      if (e.timestamp.isBefore(cutoff)) {
        e.releasePixels();
      } else {
        kept.add(e);
      }
    }
    return kept;
  }

  /// Keep pixels only on [best]; release the rest.
  static void retainBestPixels(
    List<FrameEvidence> window,
    FrameEvidence? best,
  ) {
    for (final e in window) {
      if (!identical(e, best)) e.releasePixels();
    }
  }

  /// ACCEPT RULE (exactly as TASK 08 §4).
  ///
  /// [temporalOverride] lets unit tests inject a temporal verdict; when null,
  /// [TemporalPadHeuristics.forBurst] runs on window frames that have
  /// classification (existing thresholds, unchanged).
  static BestFrameAcceptDecision evaluateAccept(
    List<FrameEvidence> window, {
    TemporalPadVerdict? temporalOverride,
  }) {
    final spoofCount =
        window.where((e) => e.pad == FramePadVerdict.spoof).length;
    if (spoofCount > 0) {
      return BestFrameAcceptDecision(
        accepted: false,
        rejectReason: 'spoof',
        windowCount: window.length,
        spoofCount: spoofCount,
      );
    }

    final accepted =
        window.where((e) => e.isLiveVerified).toList(growable: false);
    if (accepted.length < 3) {
      return BestFrameAcceptDecision(
        accepted: false,
        waitReason: 'need_frames',
        windowCount: window.length,
        liveVerifiedCount: accepted.length,
      );
    }

    accepted.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final span = accepted.last.timestamp.difference(accepted.first.timestamp);
    if (span < minAcceptSpan) {
      return BestFrameAcceptDecision(
        accepted: false,
        waitReason: 'span',
        windowCount: window.length,
        liveVerifiedCount: accepted.length,
      );
    }

    final temporal = temporalOverride ?? _runTemporal(window);
    if (!temporal.ready) {
      return BestFrameAcceptDecision(
        accepted: false,
        waitReason: 'temporal',
        windowCount: window.length,
        liveVerifiedCount: accepted.length,
      );
    }
    if (!temporal.passed) {
      return BestFrameAcceptDecision(
        accepted: false,
        rejectReason: 'temporal_fail',
        waitReason: temporal.reason,
        windowCount: window.length,
        liveVerifiedCount: accepted.length,
      );
    }

    FrameEvidence best = accepted.first;
    for (final e in accepted.skip(1)) {
      if (e.qualityScore > best.qualityScore) best = e;
    }
    if (!best.isLiveVerified) {
      return BestFrameAcceptDecision(
        accepted: false,
        waitReason: 'best_not_live_verified',
        windowCount: window.length,
        liveVerifiedCount: accepted.length,
      );
    }

    return BestFrameAcceptDecision(
      accepted: true,
      best: best,
      windowCount: window.length,
      liveVerifiedCount: accepted.length,
    );
  }

  static TemporalPadVerdict _runTemporal(List<FrameEvidence> window) {
    final temporal = TemporalPadHeuristics.forBurst();
    for (final e in window) {
      final c = e.classification;
      if (c == null) continue;
      temporal.addSample(face: c, boundingBox: e.faceBox);
    }
    return temporal.evaluate();
  }

  /// Marker/shutter green when: target verified on ≥2 of last 3
  /// identity-eligible frames AND ≥1 frame in the window has PAD = live
  /// (uncertain / notEligible do not count) AND no spoof in the window.
  static BestFrameMarkerState markerState({
    required List<FrameEvidence> window,
    required int targetEmployeeId,
  }) {
    if (window.any((e) => e.pad == FramePadVerdict.spoof)) {
      return BestFrameMarkerState.none;
    }
    if (!window.any((e) => e.pad == FramePadVerdict.live)) {
      return BestFrameMarkerState.none;
    }
    final idEligible = window
        .where((e) => e.identityStatus != FrameIdentityStatus.notEligible)
        .toList(growable: false);
    if (idEligible.isEmpty) return BestFrameMarkerState.none;
    final last3 = idEligible.length <= 3
        ? idEligible
        : idEligible.sublist(idEligible.length - 3);
    final verifiedHits = last3.where((e) {
      final id = e.identity;
      return e.identityStatus == FrameIdentityStatus.verified &&
          id != null &&
          id.targetEmployeeId == targetEmployeeId &&
          id.isVerified;
    }).length;
    if (verifiedHits < 2) return BestFrameMarkerState.none;
    final latest = last3.last;
    return BestFrameMarkerVerified(
      employeeId: targetEmployeeId,
      faceBox: latest.faceBox,
    );
  }
}
