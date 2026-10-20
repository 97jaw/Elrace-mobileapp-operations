import 'package:el_race/core/site_management/face_recognition/domain/face_verifier.dart';
import 'package:flutter_test/flutter_test.dart';

const _bars = FaceVerifyBars(
  minScore: 0.30,
  minLead: 0.05,
  minScoreNoCohort: 0.40,
  minCohort: 5,
  minFacePx: 80,
);

const _target = 100;

List<FaceCohortScore> _cohort(List<double> scores, {int firstId = 1}) => [
      for (var i = 0; i < scores.length; i++)
        FaceCohortScore(employeeId: firstId + i, score: scores[i]),
    ];

FaceVerifyResult _decide(
  double? t,
  Iterable<FaceCohortScore> cohort, {
  double? facePx,
  FaceVerifyBars bars = _bars,
}) =>
    FaceVerifier.decide(
      targetEmployeeId: _target,
      targetScore: t,
      cohort: cohort,
      bars: bars,
      faceWidthPx: facePx,
    );

void main() {
  group('FaceVerifier.decide', () {
    test('verified: score and lead above bars', () {
      final r = _decide(0.45, _cohort([0.10, 0.20, 0.30, 0.35, 0.15]));
      expect(r.outcome, FaceVerifyOutcome.verified);
      expect(r.cohortSize, 5);
      expect(r.cohortMaxScore, 0.35);
      expect(r.cohortMaxEmployeeId, 4);
      expect(r.lead, closeTo(0.10, 1e-9));
      expect(r.usedNoCohortBar, isFalse);
    });

    test('lowScore: target below minScore', () {
      final r = _decide(0.25, _cohort([0.05, 0.05, 0.05, 0.05, 0.05]));
      expect(r.outcome, FaceVerifyOutcome.lowScore);
    });

    test('notDistinct: score ok, lead below minLead', () {
      final r = _decide(0.40, _cohort([0.10, 0.10, 0.10, 0.10, 0.37]));
      expect(r.outcome, FaceVerifyOutcome.notDistinct);
      expect(r.lead, closeTo(0.03, 1e-9));
    });

    test('small cohort uses minScoreNoCohort', () {
      final cohort = _cohort([0.10, 0.10, 0.10, 0.10]);
      final reject = _decide(0.35, cohort);
      expect(reject.outcome, FaceVerifyOutcome.lowScore);
      expect(reject.usedNoCohortBar, isTrue);
      expect(reject.cohortSize, 4);

      final accept = _decide(0.41, cohort);
      expect(accept.outcome, FaceVerifyOutcome.verified);
      expect(accept.usedNoCohortBar, isTrue);
    });

    test('empty cohort with minCohort 0 scores c_max as 0', () {
      const bars = FaceVerifyBars(
        minScore: 0.30,
        minLead: 0.05,
        minScoreNoCohort: 0.40,
        minCohort: 0,
        minFacePx: 80,
      );
      final r = _decide(0.32, const [], bars: bars);
      expect(r.outcome, FaceVerifyOutcome.verified);
      expect(r.usedNoCohortBar, isFalse);
      expect(r.cohortMaxScore, 0);
      expect(r.lead, closeTo(0.32, 1e-9));
    });

    test('noTemplate when the target has no template', () {
      final r = _decide(null, _cohort([0.1, 0.1, 0.1, 0.1, 0.1]));
      expect(r.outcome, FaceVerifyOutcome.noTemplate);
      expect(r.targetScore, isNull);
    });

    test('noTemplate wins over faceTooSmall', () {
      final r = _decide(null, const [], facePx: 40);
      expect(r.outcome, FaceVerifyOutcome.noTemplate);
    });

    test('faceTooSmall when the still face is narrower than minFacePx', () {
      final r = _decide(0.60, _cohort([0.1, 0.1, 0.1, 0.1, 0.1]), facePx: 79);
      expect(r.outcome, FaceVerifyOutcome.faceTooSmall);
      final ok = _decide(0.60, _cohort([0.1, 0.1, 0.1, 0.1, 0.1]), facePx: 80);
      expect(ok.outcome, FaceVerifyOutcome.verified);
    });

    test('no face width (live stream) skips the size check', () {
      final r = _decide(0.60, _cohort([0.1, 0.1, 0.1, 0.1, 0.1]));
      expect(r.outcome, FaceVerifyOutcome.verified);
    });

    test('LOW_RES cohort members are excluded', () {
      final cohort = [
        ..._cohort([0.10, 0.10, 0.10, 0.10, 0.10]),
        const FaceCohortScore(employeeId: 50, score: 0.44, lowRes: true),
      ];
      final r = _decide(0.45, cohort);
      expect(r.outcome, FaceVerifyOutcome.verified);
      expect(r.cohortSize, 5);
      expect(r.cohortMaxScore, 0.10);
    });

    test('LOW_RES exclusion can drop the cohort below minCohort', () {
      final cohort = [
        ..._cohort([0.10, 0.10, 0.10, 0.10]),
        const FaceCohortScore(employeeId: 50, score: 0.10, lowRes: true),
      ];
      final r = _decide(0.35, cohort);
      expect(r.cohortSize, 4);
      expect(r.usedNoCohortBar, isTrue);
      expect(r.outcome, FaceVerifyOutcome.lowScore);
    });

    test('target is never counted in the cohort', () {
      final cohort = [
        ..._cohort([0.10, 0.10, 0.10, 0.10, 0.10]),
        const FaceCohortScore(employeeId: _target, score: 0.99),
      ];
      final r = _decide(0.45, cohort);
      expect(r.outcome, FaceVerifyOutcome.verified);
      expect(r.cohortSize, 5);
      expect(r.cohortMaxEmployeeId, isNot(_target));
    });

    test('several templates of one cohort employee count once (best)', () {
      final cohort = [
        ..._cohort([0.10, 0.10, 0.10, 0.10]),
        const FaceCohortScore(employeeId: 9, score: 0.20),
        const FaceCohortScore(employeeId: 9, score: 0.42),
      ];
      final r = _decide(0.45, cohort);
      expect(r.cohortSize, 5);
      expect(r.cohortMaxScore, 0.42);
      expect(r.outcome, FaceVerifyOutcome.notDistinct);
    });
  });

  test('FaceVerifier.cosine normalises its inputs', () {
    expect(FaceVerifier.cosine([2, 0], [5, 0]), closeTo(1, 1e-9));
    expect(FaceVerifier.cosine([1, 0], [0, 3]), closeTo(0, 1e-9));
    expect(FaceVerifier.cosine([0, 0], [1, 1]), 0);
  });
}
