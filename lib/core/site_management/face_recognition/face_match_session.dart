import 'package:el_race/core/site_management/face_recognition/data/models/face_match_result.dart';

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
  });

  final FaceMatchUiOutcome outcome;
  final double bestScore;
  final double secondBestScore;
  final int? employeeId;
  final String? employeeName;
  final bool inForemanTeam;
  final FaceForemanFollowUp followUp;
  final DateTime? capturedAt;

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
