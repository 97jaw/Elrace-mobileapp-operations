import 'dart:math' as math;

import 'package:el_race/core/site_management/face_recognition/face_recognition_config.dart';

enum FaceVerifyOutcome {
  verified,
  lowScore,
  notDistinct,
  noTemplate,
  faceTooSmall,
  error,
}

/// Bars for one decision; [FaceVerifyBars.current] reads [FaceVerifyTuning].
class FaceVerifyBars {
  const FaceVerifyBars({
    required this.minScore,
    required this.minLead,
    required this.minScoreNoCohort,
    required this.minCohort,
    required this.minFacePx,
  });

  factory FaceVerifyBars.current() => FaceVerifyBars(
        minScore: FaceVerifyTuning.minScore,
        minLead: FaceVerifyTuning.minLead,
        minScoreNoCohort: FaceVerifyTuning.minScoreNoCohort,
        minCohort: FaceVerifyTuning.minCohort,
        minFacePx: FaceVerifyTuning.minFacePx,
      );

  final double minScore;
  final double minLead;
  final double minScoreNoCohort;
  final int minCohort;
  final int minFacePx;
}

/// Probe score against one other employee's template.
class FaceCohortScore {
  const FaceCohortScore({
    required this.employeeId,
    required this.score,
    this.lowRes = false,
  });

  final int employeeId;
  final double score;

  /// LOW_RES templates never count as cohort.
  final bool lowRes;
}

/// 1:1 verification of the selected labor. Never carries a cohort member's
/// name; [cohortMaxEmployeeId] is for debug logs only.
class FaceVerifyResult {
  const FaceVerifyResult({
    required this.outcome,
    required this.targetEmployeeId,
    this.targetScore,
    this.cohortMaxScore,
    this.cohortMaxEmployeeId,
    this.lead,
    this.cohortSize = 0,
    this.usedNoCohortBar = false,
    this.faceWidthPx,
    this.preprocessMs = 0,
    this.embedMs = 0,
    this.verifyMs = 0,
    this.totalMs = 0,
  });

  final FaceVerifyOutcome outcome;
  final int targetEmployeeId;
  final double? targetScore;
  final double? cohortMaxScore;
  final int? cohortMaxEmployeeId;
  final double? lead;
  final int cohortSize;
  final bool usedNoCohortBar;
  final double? faceWidthPx;
  final int preprocessMs;
  final int embedMs;
  final int verifyMs;
  final int totalMs;

  bool get isVerified => outcome == FaceVerifyOutcome.verified;

  FaceVerifyResult withTimings({
    required int preprocessMs,
    required int embedMs,
    required int verifyMs,
    required int totalMs,
  }) =>
      FaceVerifyResult(
        outcome: outcome,
        targetEmployeeId: targetEmployeeId,
        targetScore: targetScore,
        cohortMaxScore: cohortMaxScore,
        cohortMaxEmployeeId: cohortMaxEmployeeId,
        lead: lead,
        cohortSize: cohortSize,
        usedNoCohortBar: usedNoCohortBar,
        faceWidthPx: faceWidthPx,
        preprocessMs: preprocessMs,
        embedMs: embedMs,
        verifyMs: verifyMs,
        totalMs: totalMs,
      );
}

abstract final class FaceVerifier {
  /// Checks that need no embedding: target template present, face big
  /// enough. Null = go on and score. [faceWidthPx] null skips the size check
  /// (live stream).
  static FaceVerifyResult? precheck({
    required int targetEmployeeId,
    required bool hasTargetTemplate,
    required double? faceWidthPx,
    required FaceVerifyBars bars,
  }) {
    if (!hasTargetTemplate) {
      return FaceVerifyResult(
        outcome: FaceVerifyOutcome.noTemplate,
        targetEmployeeId: targetEmployeeId,
        faceWidthPx: faceWidthPx,
      );
    }
    if (faceWidthPx != null && faceWidthPx < bars.minFacePx) {
      return FaceVerifyResult(
        outcome: FaceVerifyOutcome.faceTooSmall,
        targetEmployeeId: targetEmployeeId,
        faceWidthPx: faceWidthPx,
      );
    }
    return null;
  }

  /// Decision table (TASK 02 Part C). [targetScore] null = no template.
  /// The cohort excludes the target and LOW_RES members; scores are the best
  /// per employee.
  static FaceVerifyResult decide({
    required int targetEmployeeId,
    required double? targetScore,
    required Iterable<FaceCohortScore> cohort,
    required FaceVerifyBars bars,
    double? faceWidthPx,
  }) {
    final early = precheck(
      targetEmployeeId: targetEmployeeId,
      hasTargetTemplate: targetScore != null,
      faceWidthPx: faceWidthPx,
      bars: bars,
    );
    if (early != null) return early;
    final t = targetScore!;

    final perEmployee = <int, double>{};
    for (final c in cohort) {
      if (c.employeeId == targetEmployeeId || c.lowRes) continue;
      final prev = perEmployee[c.employeeId];
      if (prev == null || c.score > prev) perEmployee[c.employeeId] = c.score;
    }
    final size = perEmployee.length;

    if (size >= bars.minCohort) {
      // Empty cohort (only when minCohort is 0) scores c_max = 0.
      int? maxId;
      var maxScore = 0.0;
      perEmployee.forEach((id, s) {
        if (maxId == null || s > maxScore) {
          maxScore = s;
          maxId = id;
        }
      });
      final lead = t - maxScore;
      final outcome = t < bars.minScore
          ? FaceVerifyOutcome.lowScore
          : lead < bars.minLead
              ? FaceVerifyOutcome.notDistinct
              : FaceVerifyOutcome.verified;
      return FaceVerifyResult(
        outcome: outcome,
        targetEmployeeId: targetEmployeeId,
        targetScore: t,
        cohortMaxScore: maxScore,
        cohortMaxEmployeeId: maxId,
        lead: lead,
        cohortSize: size,
        faceWidthPx: faceWidthPx,
      );
    }

    double? maxScore;
    int? maxId;
    perEmployee.forEach((id, s) {
      if (maxScore == null || s > maxScore!) {
        maxScore = s;
        maxId = id;
      }
    });
    return FaceVerifyResult(
      outcome: t >= bars.minScoreNoCohort
          ? FaceVerifyOutcome.verified
          : FaceVerifyOutcome.lowScore,
      targetEmployeeId: targetEmployeeId,
      targetScore: t,
      cohortMaxScore: maxScore,
      cohortMaxEmployeeId: maxId,
      lead: maxScore == null ? null : t - maxScore!,
      cohortSize: size,
      usedNoCohortBar: true,
      faceWidthPx: faceWidthPx,
    );
  }

  /// Cosine of two vectors (each L2-normalised here).
  static double cosine(List<double> a, List<double> b) {
    final n = math.min(a.length, b.length);
    var dot = 0.0;
    var na = 0.0;
    var nb = 0.0;
    for (var i = 0; i < n; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    if (na < 1e-18 || nb < 1e-18) return 0;
    return dot / (math.sqrt(na) * math.sqrt(nb));
  }
}
