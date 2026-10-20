import 'package:el_race/core/services/app_config_service.dart';
import 'package:el_race/core/site_management/face_recognition/face_recognition_config.dart';
import 'package:flutter_test/flutter_test.dart';

void _expectDefaults() {
  expect(FaceVerifyTuning.minScore, FaceVerifyTuning.defaultMinScore);
  expect(FaceVerifyTuning.minLead, FaceVerifyTuning.defaultMinLead);
  expect(FaceVerifyTuning.minScoreNoCohort,
      FaceVerifyTuning.defaultMinScoreNoCohort);
  expect(FaceVerifyTuning.minCohort, FaceVerifyTuning.defaultMinCohort);
  expect(FaceVerifyTuning.minFacePx, FaceVerifyTuning.defaultMinFacePx);
}

void main() {
  setUp(FaceVerifyTuning.apply);

  group('FaceVerifyTuning.apply', () {
    test('defaults', () {
      expect(FaceVerifyTuning.defaultMinScore, 0.30);
      expect(FaceVerifyTuning.defaultMinLead, 0.05);
      expect(FaceVerifyTuning.defaultMinScoreNoCohort, 0.40);
      expect(FaceVerifyTuning.defaultMinCohort, 5);
      expect(FaceVerifyTuning.defaultMinFacePx, 80);
      _expectDefaults();
    });

    test('in-range values apply, including the bounds', () {
      FaceVerifyTuning.apply(
        minScore: 0.10,
        minLead: 0,
        minScoreNoCohort: 0.90,
        minCohort: 50,
        minFacePx: 48,
      );
      expect(FaceVerifyTuning.minScore, 0.10);
      expect(FaceVerifyTuning.minLead, 0);
      expect(FaceVerifyTuning.minScoreNoCohort, 0.90);
      expect(FaceVerifyTuning.minCohort, 50);
      expect(FaceVerifyTuning.minFacePx, 48);

      FaceVerifyTuning.apply(
        minScore: 0.90,
        minLead: 0.30,
        minScoreNoCohort: 0.10,
        minCohort: 0,
        minFacePx: 300,
      );
      expect(FaceVerifyTuning.minScore, 0.90);
      expect(FaceVerifyTuning.minLead, 0.30);
      expect(FaceVerifyTuning.minScoreNoCohort, 0.10);
      expect(FaceVerifyTuning.minCohort, 0);
      expect(FaceVerifyTuning.minFacePx, 300);
    });

    test('out of range falls back to defaults', () {
      FaceVerifyTuning.apply(
        minScore: 0.09,
        minLead: 0.31,
        minScoreNoCohort: 0.95,
        minCohort: 51,
        minFacePx: 47,
      );
      _expectDefaults();
      FaceVerifyTuning.apply(minLead: -0.01, minCohort: -1, minFacePx: 301);
      _expectDefaults();
    });

    test('non-finite and null fall back to defaults', () {
      FaceVerifyTuning.apply(
        minScore: double.nan,
        minLead: double.infinity,
        minScoreNoCohort: double.negativeInfinity,
      );
      _expectDefaults();
      FaceVerifyTuning.apply(minScore: 0.35);
      FaceVerifyTuning.apply();
      _expectDefaults();
    });
  });

  group('AppConfigService.applyFaceVerifyConfig', () {
    test('keys missing (older backend) keep defaults', () {
      AppConfigService.applyFaceVerifyConfig(const {
        'isTestMode': false,
        'face_match_min_score': 0.35,
      });
      _expectDefaults();
    });

    test('null values (parameters unset) keep defaults', () {
      AppConfigService.applyFaceVerifyConfig({
        for (final k in AppConfigService.faceVerifyKeys) k: null,
      });
      _expectDefaults();
    });

    test('valid values apply; whole-number doubles accepted for ints', () {
      AppConfigService.applyFaceVerifyConfig(const {
        'face_verify_min_score': 0.32,
        'face_verify_min_lead': 0.06,
        'face_verify_min_score_no_cohort': 0.45,
        'face_verify_min_cohort': 6,
        'face_verify_min_face_px': 120.0,
      });
      expect(FaceVerifyTuning.minScore, 0.32);
      expect(FaceVerifyTuning.minLead, 0.06);
      expect(FaceVerifyTuning.minScoreNoCohort, 0.45);
      expect(FaceVerifyTuning.minCohort, 6);
      expect(FaceVerifyTuning.minFacePx, 120);
    });

    test('ints given as ints work for the score keys', () {
      AppConfigService.applyFaceVerifyConfig(const {
        'face_verify_min_lead': 0,
      });
      expect(FaceVerifyTuning.minLead, 0);
    });

    test('out of range, wrong type and fractional ints keep defaults', () {
      AppConfigService.applyFaceVerifyConfig(const {
        'face_verify_min_score': 1.5,
        'face_verify_min_lead': '0.06',
        'face_verify_min_score_no_cohort': 0.05,
        'face_verify_min_cohort': 6.5,
        'face_verify_min_face_px': 'abc',
      });
      _expectDefaults();
    });
  });
}
