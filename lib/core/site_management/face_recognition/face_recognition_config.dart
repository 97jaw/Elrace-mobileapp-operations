/// Site Management — Phase B face recognition (on-device).
///
/// Product: **Site Management** (UI under `lib/ui/presentation/timesheet/`).
/// Do not build a parallel timesheet-only stack; wire into existing Add Timesheet flow.
library;

/// Lambda ONNX / mobile TFLite preprocessing (see inference.py).
abstract final class FaceRecognitionPreprocess {
  static const double normMean = 127.5;
  static const double normStd = 128.0;

  /// RGB 0–255 → `(pixel - normMean) / normStd` (~[-1, 1]).
  static double normalizePixel(double rgb0to255) =>
      (rgb0to255 - normMean) / normStd;

  /// TFLite model input (verified F.0 / TC-C2).
  static const int inputHeight = 112;
  static const int inputWidth = 112;
  static const int inputChannels = 3;

  /// Lambda uses ~15% pad on max(w,h); mobile mirrors this (not 22% capture pad).
  static const double lambdaPadFraction = 0.15;

  /// P.3 — align eyes horizontal via ML Kit landmarks before 112×112 resize.
  static const bool useLandmarkAlignment = true;

  /// 5-point ArcFace similarity warp for probes compared against phone-built
  /// profile templates (and for building those templates). Server/enrollment
  /// templates always use the legacy crop. Flipping this also flips the
  /// profile template pipeline version, so the cache is rebuilt.
  static const bool useFivePointAlignment = true;
}

/// P.1 — performance targets and tuning flags.
abstract final class FaceRecognitionPerformance {
  /// Decode + crop + resize on a background isolate (TFLite stays on main).
  static const bool useIsolateForPreprocess = true;

  /// Pilot target: preprocess + embed + match (logged, not enforced).
  static const int targetTotalMs = 800;
}

abstract final class FaceRecognitionModel {
  static const String assetPath = 'assets/mobilefacenet_512.tflite';
  static const int embeddingDim = 512;
}

/// Match bar set from Odoo system parameters `elrace.face_match_min_score`
/// and `elrace.face_match_min_lead` (via `/api/app/config`). Out-of-range or
/// unset values fall back to the defaults.
abstract final class FaceMatchTuning {
  static const double defaultMinScore = 0.15;
  static const double defaultMinLead = 0.02;

  static const double _scoreFloor = 0.10;
  static const double _scoreCeil = 0.90;
  static const double _leadCeil = 0.30;

  static double _minScore = defaultMinScore;
  static double _minLead = defaultMinLead;

  static double get minScore => _minScore;
  static double get minLead => _minLead;

  static void apply({double? minScore, double? minLead}) {
    _minScore = (minScore != null &&
            minScore.isFinite &&
            minScore >= _scoreFloor &&
            minScore <= _scoreCeil)
        ? minScore
        : defaultMinScore;
    _minLead = (minLead != null &&
            minLead.isFinite &&
            minLead >= 0 &&
            minLead <= _leadCeil)
        ? minLead
        : defaultMinLead;
  }
}

/// Match mode from Odoo `elrace.face_match_mode` (via `/api/app/config`).
enum FaceMatchMode {
  /// Today's 1:1 verify (default / fallback).
  verify,

  /// Auto identification of Your Team labors (TASK 10).
  walkup,
}

/// Walk-up identification bars from `elrace.face_walkup_min_score` /
/// `elrace.face_walkup_min_lead`. Valid score 0.20–0.90, lead 0.05–0.40.
abstract final class FaceWalkUpTuning {
  static const double defaultMinScore = 0.40;
  static const double defaultMinLead = 0.15;

  static double _minScore = defaultMinScore;
  static double _minLead = defaultMinLead;

  static double get minScore => _minScore;
  static double get minLead => _minLead;

  static void apply({double? minScore, double? minLead}) {
    _minScore = (minScore != null &&
            minScore.isFinite &&
            minScore >= 0.20 &&
            minScore <= 0.90)
        ? minScore
        : defaultMinScore;
    _minLead = (minLead != null &&
            minLead.isFinite &&
            minLead >= 0.05 &&
            minLead <= 0.40)
        ? minLead
        : defaultMinLead;
  }
}

/// 1:1 verification bars set from Odoo system parameters
/// `elrace.face_verify_*` (via `/api/app/config`). Out-of-range, non-finite
/// or unset values fall back to the defaults. Read per decision.
abstract final class FaceVerifyTuning {
  static const double defaultMinScore = 0.30;
  static const double defaultMinLead = 0.05;
  static const double defaultMinScoreNoCohort = 0.40;
  static const int defaultMinCohort = 5;
  static const int defaultMinFacePx = 80;

  static double _minScore = defaultMinScore;
  static double _minLead = defaultMinLead;
  static double _minScoreNoCohort = defaultMinScoreNoCohort;
  static int _minCohort = defaultMinCohort;
  static int _minFacePx = defaultMinFacePx;

  /// Probe must reach this against the selected labor (cohort big enough).
  static double get minScore => _minScore;

  /// Probe score on the selected labor minus the best cohort score.
  static double get minLead => _minLead;

  /// Bar used instead of score + lead when the cohort is too small.
  static double get minScoreNoCohort => _minScoreNoCohort;

  /// Cohort members needed before [minScore] + [minLead] apply.
  static int get minCohort => _minCohort;

  /// Smallest face width (px, still image) that is verified at all.
  static int get minFacePx => _minFacePx;

  static void apply({
    double? minScore,
    double? minLead,
    double? minScoreNoCohort,
    int? minCohort,
    int? minFacePx,
  }) {
    _minScore = _inRange(minScore, 0.10, 0.90) ? minScore! : defaultMinScore;
    _minLead = _inRange(minLead, 0, 0.30) ? minLead! : defaultMinLead;
    _minScoreNoCohort = _inRange(minScoreNoCohort, 0.10, 0.90)
        ? minScoreNoCohort!
        : defaultMinScoreNoCohort;
    _minCohort = minCohort != null && minCohort >= 0 && minCohort <= 50
        ? minCohort
        : defaultMinCohort;
    _minFacePx = minFacePx != null && minFacePx >= 48 && minFacePx <= 300
        ? minFacePx
        : defaultMinFacePx;
  }

  static bool _inRange(double? v, double min, double max) =>
      v != null && v.isFinite && v >= min && v <= max;
}

abstract final class FaceRecognitionMatch {
  static const double defaultThreshold = 0.75;
  static const double idealThreshold = 0.80;

  /// Add-to-list after still capture — pilot bar (iOS + Android, same).
  static double get pilotThreshold => FaceMatchTuning.minScore;

  /// Soft still accept when live preview already locked the same employee.
  static double get pilotSoftCaptureThreshold => FaceMatchTuning.minScore;

  /// Stream score floor before auto-shutter (same as match bar).
  static double get pilotAutoCaptureMinScore => FaceMatchTuning.minScore;

  /// Name badge floor — same as match so badge ⇒ eligible to detect.
  static double get pilotDisplayThreshold => FaceMatchTuning.minScore;

  /// Minimum winner gap to show employee name on live preview.
  static double get minDisplayWinnerMargin => FaceMatchTuning.minLead;

  /// Best must beat 2nd-best employee by this before roster add.
  /// Aligned with display margin so a shown name can also detect.
  static double get minWinnerMargin => FaceMatchTuning.minLead;

  /// Set false to revert UI + matcher to [defaultThreshold].
  static const bool usePilotThresholdForMatch = true;

  static double get activeMatchThreshold =>
      usePilotThresholdForMatch ? pilotThreshold : defaultThreshold;

  static double get activeDisplayThreshold =>
      usePilotThresholdForMatch ? pilotDisplayThreshold : defaultThreshold;

  /// TC-C2 / E.3 bar: same photo vs stored embedding.
  static const double verificationMinCosine = 0.95;

  /// Close second match — optional UI hint.
  static const double closeSecondDelta = 0.05;
}

/// Target-labor camera ("Your Team").
abstract final class FaceExpectedLaborMatch {
  /// Retry window for a just-enrolled labor whose templates aren't synced.
  static const Duration templateRefreshCooldown = Duration(seconds: 5);
  static const int maxTemplateRefreshAttempts = 4;
}

/// Post-capture enrollment checks (run once, after every pose is captured).
/// Attendance matching never reads these.
abstract final class FaceEnrollmentChecks {
  /// Each turned pose vs the front photo (same device, same pipeline).
  static const double samePersonMinCosine = 0.30;

  /// Mean score (across all poses) against another enrolled employee.
  /// Different people reach ~0.45 in pilot logs, so warn above that and only
  /// hard-block on a clearly stronger match.
  static const double duplicateWarnCosine = 0.52;
  static const double duplicateBlockCosine = 0.65;
}
