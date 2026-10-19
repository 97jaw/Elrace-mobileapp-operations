import 'package:el_race/core/site_management/face_recognition/data/models/face_match_result.dart';
import 'package:el_race/core/site_management/face_recognition/domain/face_verifier.dart';

/// M.2 — last capture outcome for pilot logging (P.4).
enum FaceMatchUiOutcome {
  none,
  inTeam,
  outOfTeam,
  belowThreshold,
  engineError,
}

enum FaceForemanFollowUp {
  pending,
  confirmed,
  rejected,
  manualPick,
}

class FaceMatchSessionRecord {
  const FaceMatchSessionRecord({
    required this.outcome,
    required this.bestScore,
    required this.secondBestScore,
    this.employeeId,
    this.employeeName,
    this.inForemanTeam = false,
    this.followUp = FaceForemanFollowUp.pending,
    this.capturedAt,
    this.verifyOutcome,
    this.verifyLead,
    this.verifyCohortSize,
  });

  /// 1:1 attempt on the target labor. Scores are target vs cohort; the
  /// cohort member's identity is never recorded.
  factory FaceMatchSessionRecord.fromVerify(
    FaceVerifyResult result, {
    String? targetName,
  }) {
    final outcome = switch (result.outcome) {
      FaceVerifyOutcome.verified => FaceMatchUiOutcome.inTeam,
      FaceVerifyOutcome.error => FaceMatchUiOutcome.engineError,
      _ => FaceMatchUiOutcome.belowThreshold,
    };
    return FaceMatchSessionRecord(
      outcome: outcome,
      bestScore: result.targetScore ?? 0,
      secondBestScore: result.cohortMaxScore ?? 0,
      employeeId: result.targetEmployeeId,
      employeeName: targetName,
      inForemanTeam: result.isVerified,
      capturedAt: DateTime.now(),
      verifyOutcome: result.outcome,
      verifyLead: result.lead,
      verifyCohortSize: result.cohortSize,
    );
  }

  final FaceMatchUiOutcome outcome;
  final double bestScore;
  final double secondBestScore;
  final int? employeeId;
  final String? employeeName;
  final bool inForemanTeam;
  final FaceForemanFollowUp followUp;
  final DateTime? capturedAt;
  final FaceVerifyOutcome? verifyOutcome;
  final double? verifyLead;
  final int? verifyCohortSize;

  FaceMatchSessionRecord copyWith({FaceForemanFollowUp? followUp}) {
    return FaceMatchSessionRecord(
      outcome: outcome,
      bestScore: bestScore,
      secondBestScore: secondBestScore,
      employeeId: employeeId,
      employeeName: employeeName,
      inForemanTeam: inForemanTeam,
      followUp: followUp ?? this.followUp,
      capturedAt: capturedAt,
      verifyOutcome: verifyOutcome,
      verifyLead: verifyLead,
      verifyCohortSize: verifyCohortSize,
    );
  }

  static FaceMatchSessionRecord fromResult(
    FaceMatchResult result, {
    required bool passesThreshold,
    required bool inForemanTeam,
  }) {
    final best = result.best;
    FaceMatchUiOutcome outcome;
    if (!passesThreshold || best == null) {
      outcome = FaceMatchUiOutcome.belowThreshold;
    } else if (inForemanTeam) {
      outcome = FaceMatchUiOutcome.inTeam;
    } else {
      outcome = FaceMatchUiOutcome.outOfTeam;
    }
    return FaceMatchSessionRecord(
      outcome: outcome,
      bestScore: result.bestScore,
      secondBestScore: result.secondBestScore,
      employeeId: best?.employeeId,
      employeeName: best?.name,
      inForemanTeam: inForemanTeam,
      capturedAt: DateTime.now(),
    );
  }
}
