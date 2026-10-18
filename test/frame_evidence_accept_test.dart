import 'dart:ui';

import 'package:el_race/core/site_management/face_recognition/antispoof/temporal_pad_heuristics.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/timesheet_face_classification_snapshot.dart';
import 'package:el_race/core/site_management/face_recognition/domain/face_verifier.dart';
import 'package:el_race/core/site_management/face_recognition/domain/frame_evidence.dart';
import 'package:el_race/core/timesheet/services/face_capture_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const frame = Size(720, 1280);
  final box = Rect.fromLTWH(200, 400, 250, 300); // ~19.5% of short side

  TimesheetFaceClassificationSnapshot clf({
    double yaw = 5,
    double roll = 2,
    double pitch = 3,
  }) =>
      TimesheetFaceClassificationSnapshot(
        boundingBox: box,
        leftEyeOpenProbability: 0.9,
        rightEyeOpenProbability: 0.9,
        headEulerAngleX: pitch,
        headEulerAngleY: yaw,
        headEulerAngleZ: roll,
      );

  TimesheetFaceLandmarkSnapshot landmarks() => TimesheetFaceLandmarkSnapshot(
        boundingBox: box,
        leftEye: const Offset(220, 480),
        rightEye: const Offset(400, 480),
        nose: const Offset(310, 560),
        mouthLeft: const Offset(240, 640),
        mouthRight: const Offset(380, 640),
      );

  FaceVerifyResult verified(int emp) => FaceVerifyResult(
        outcome: FaceVerifyOutcome.verified,
        targetEmployeeId: emp,
        targetScore: 0.72,
        lead: 0.25,
        cohortSize: 4,
      );

  FrameEvidence liveVerified({
    required DateTime at,
    required int emp,
    double quality = 0.8,
    TimesheetFaceClassificationSnapshot? classification,
  }) =>
      FrameEvidence(
        timestamp: at,
        faceBox: box,
        frameSize: frame,
        qualityScore: quality,
        identityStatus: FrameIdentityStatus.verified,
        identity: verified(emp),
        pad: FramePadVerdict.live,
        classification: classification ?? clf(),
        landmarks: landmarks(),
      );

  const temporalOk = TemporalPadVerdict(
    passed: true,
    reason: 'ok',
    ready: true,
  );

  group('BestFrameRules.evaluateAccept', () {
    test('rejects when any spoof is in the window', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      final window = [
        liveVerified(at: t0, emp: 1),
        liveVerified(at: t0.add(const Duration(milliseconds: 200)), emp: 1),
        liveVerified(at: t0.add(const Duration(milliseconds: 500)), emp: 1),
        FrameEvidence(
          timestamp: t0.add(const Duration(milliseconds: 300)),
          faceBox: box,
          frameSize: frame,
          qualityScore: 0.5,
          identityStatus: FrameIdentityStatus.notEligible,
          pad: FramePadVerdict.spoof,
        ),
      ];
      final d = BestFrameRules.evaluateAccept(
        window,
        temporalOverride: temporalOk,
      );
      expect(d.accepted, isFalse);
      expect(d.rejectReason, 'spoof');
    });

    test('waits until ≥3 live+verified frames', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      final window = [
        liveVerified(at: t0, emp: 1),
        liveVerified(at: t0.add(const Duration(milliseconds: 500)), emp: 1),
      ];
      final d = BestFrameRules.evaluateAccept(
        window,
        temporalOverride: temporalOk,
      );
      expect(d.accepted, isFalse);
      expect(d.waitReason, 'need_frames');
      expect(d.liveVerifiedCount, 2);
    });

    test('waits when span < 400 ms', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      final window = [
        liveVerified(at: t0, emp: 1, quality: 0.7),
        liveVerified(
          at: t0.add(const Duration(milliseconds: 100)),
          emp: 1,
          quality: 0.8,
        ),
        liveVerified(
          at: t0.add(const Duration(milliseconds: 200)),
          emp: 1,
          quality: 0.9,
        ),
      ];
      final d = BestFrameRules.evaluateAccept(
        window,
        temporalOverride: temporalOk,
      );
      expect(d.accepted, isFalse);
      expect(d.waitReason, 'span');
    });

    test('uncertain PAD frames do not count and do not block', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      final window = [
        liveVerified(at: t0, emp: 1, quality: 0.6),
        FrameEvidence(
          timestamp: t0.add(const Duration(milliseconds: 100)),
          faceBox: box,
          frameSize: frame,
          qualityScore: 0.5,
          identityStatus: FrameIdentityStatus.verified,
          identity: verified(1),
          pad: FramePadVerdict.uncertain,
          classification: clf(),
        ),
        liveVerified(
          at: t0.add(const Duration(milliseconds: 250)),
          emp: 1,
          quality: 0.7,
        ),
        liveVerified(
          at: t0.add(const Duration(milliseconds: 500)),
          emp: 1,
          quality: 0.95,
        ),
      ];
      final d = BestFrameRules.evaluateAccept(
        window,
        temporalOverride: temporalOk,
      );
      expect(d.accepted, isTrue);
      expect(d.liveVerifiedCount, 3);
      expect(d.best!.qualityScore, 0.95);
    });

    test('accepts with ≥3 live+verified spanning ≥400 ms and picks best', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      final window = [
        liveVerified(at: t0, emp: 7, quality: 0.55),
        liveVerified(
          at: t0.add(const Duration(milliseconds: 220)),
          emp: 7,
          quality: 0.88,
        ),
        liveVerified(
          at: t0.add(const Duration(milliseconds: 500)),
          emp: 7,
          quality: 0.70,
        ),
      ];
      final d = BestFrameRules.evaluateAccept(
        window,
        temporalOverride: temporalOk,
      );
      expect(d.accepted, isTrue);
      expect(d.best!.qualityScore, 0.88);
      expect(d.rejectReason, isNull);
    });

    test('never accepts on a single live+verified frame', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      final d = BestFrameRules.evaluateAccept(
        [liveVerified(at: t0, emp: 1, quality: 1.0)],
        temporalOverride: temporalOk,
      );
      expect(d.accepted, isFalse);
      expect(d.waitReason, 'need_frames');
    });
  });

  group('BestFrameRules.markerState', () {
    test('verified when ≥2 of last 3 identity-eligible are target', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      final window = [
        liveVerified(at: t0, emp: 42),
        FrameEvidence(
          timestamp: t0.add(const Duration(milliseconds: 100)),
          faceBox: box,
          frameSize: frame,
          qualityScore: 0.4,
          identityStatus: FrameIdentityStatus.notVerified,
          identity: FaceVerifyResult(
            outcome: FaceVerifyOutcome.lowScore,
            targetEmployeeId: 42,
            targetScore: 0.2,
          ),
          pad: FramePadVerdict.uncertain,
        ),
        liveVerified(
          at: t0.add(const Duration(milliseconds: 200)),
          emp: 42,
        ),
      ];
      final m = BestFrameRules.markerState(window: window, targetEmployeeId: 42);
      expect(m, isA<BestFrameMarkerVerified>());
      expect((m as BestFrameMarkerVerified).employeeId, 42);
    });

    test('none when a spoof is in the window', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      final window = [
        liveVerified(at: t0, emp: 42),
        liveVerified(at: t0.add(const Duration(milliseconds: 100)), emp: 42),
        FrameEvidence(
          timestamp: t0.add(const Duration(milliseconds: 150)),
          faceBox: box,
          frameSize: frame,
          qualityScore: 0.2,
          identityStatus: FrameIdentityStatus.notEligible,
          pad: FramePadVerdict.spoof,
        ),
      ];
      final m = BestFrameRules.markerState(window: window, targetEmployeeId: 42);
      expect(m, same(BestFrameMarkerState.none));
    });

    test('none when identity verified but no PAD=live in window', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      FrameEvidence idOnly({required DateTime at, required FramePadVerdict pad}) =>
          FrameEvidence(
            timestamp: at,
            faceBox: box,
            frameSize: frame,
            qualityScore: 0.8,
            identityStatus: FrameIdentityStatus.verified,
            identity: verified(42),
            pad: pad,
            classification: clf(),
            landmarks: landmarks(),
          );
      final window = [
        idOnly(at: t0, pad: FramePadVerdict.uncertain),
        idOnly(
          at: t0.add(const Duration(milliseconds: 100)),
          pad: FramePadVerdict.notEligible,
        ),
        idOnly(
          at: t0.add(const Duration(milliseconds: 200)),
          pad: FramePadVerdict.uncertain,
        ),
      ];
      final m = BestFrameRules.markerState(window: window, targetEmployeeId: 42);
      expect(m, same(BestFrameMarkerState.none));
    });
  });

  group('BestFrameRules.adaptiveWindowDuration', () {
    test('clamps to 1.2s–2.5s from 3.5× interval', () {
      expect(
        BestFrameRules.adaptiveWindowDuration(const Duration(milliseconds: 200)),
        const Duration(milliseconds: 1200), // 700 → min
      );
      expect(
        BestFrameRules.adaptiveWindowDuration(const Duration(milliseconds: 500)),
        const Duration(milliseconds: 1750),
      );
      expect(
        BestFrameRules.adaptiveWindowDuration(const Duration(milliseconds: 900)),
        const Duration(milliseconds: 2500), // 3150 → max
      );
    });
  });

  group('BestFrameRules eligibility', () {
    test('identity needs five landmarks and width ≥ 8%', () {
      expect(
        BestFrameRules.identityEligible(
          faceBox: box,
          frameSize: frame,
          landmarks: landmarks(),
          classification: clf(),
        ),
        isTrue,
      );
      expect(
        BestFrameRules.identityEligible(
          faceBox: box,
          frameSize: frame,
          landmarks: TimesheetFaceLandmarkSnapshot(boundingBox: box),
          classification: clf(),
        ),
        isFalse,
      );
    });

    test('PAD rejects too-close faces (>55%)', () {
      final close = Rect.fromLTWH(50, 100, 720, 800);
      expect(
        BestFrameRules.padEligible(
          faceBox: close,
          frameSize: frame,
          classification: clf(),
          sharpness: 30,
        ),
        isFalse,
      );
      expect(
        BestFrameRules.dominantIneligibleReason(
          faceBox: close,
          frameSize: frame,
          landmarks: landmarks(),
          classification: clf(),
          sharpness: 30,
          brightness: 0.5,
        ),
        FrameUsableDominant.tooClose,
      );
    });
  });
}
