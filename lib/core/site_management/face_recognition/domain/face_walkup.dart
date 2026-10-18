import 'package:el_race/core/site_management/face_recognition/face_recognition_config.dart';

/// Role of a scored template in walk-up matching (TASK 10).
enum FaceWalkUpKind {
  /// Your Team, ready, not LOW_RES / look-alike — may auto-identify.
  candidate,

  /// Your Team with a ready template but LOW_RES or look-alike — Pick labor only.
  excludedTeam,

  /// Project labor not in Your Team — may show amber when bars pass.
  projectLabor,
}

/// Per-frame walk-up identification (TASK 10 §3).
class FaceWalkUpResult {
  const FaceWalkUpResult({
    required this.identified,
    this.winnerEmployeeId,
    this.score,
    this.lead,
    this.secondEmployeeId,
    this.secondScore,
    this.outOfTeam = false,
    this.excludedTeamMember = false,
  });

  static const none = FaceWalkUpResult(identified: false);

  final bool identified;
  final int? winnerEmployeeId;
  final double? score;
  final double? lead;
  final int? secondEmployeeId;
  final double? secondScore;

  /// Global best is project labor (not Your Team) and bars pass → amber.
  final bool outOfTeam;

  /// Global best is Your Team but LOW_RES / look-alike → Pick labor, never amber.
  final bool excludedTeamMember;
}

/// Probe score against one template employee.
class FaceWalkUpScore {
  const FaceWalkUpScore({
    required this.employeeId,
    required this.score,
    required this.kind,
  });

  final int employeeId;
  final double score;
  final FaceWalkUpKind kind;

  bool get isCandidate => kind == FaceWalkUpKind.candidate;
}

abstract final class FaceWalkUp {
  /// Decide from per-employee scores (candidates + excluded team + cohort).
  ///
  /// - Candidate + bars → [identified]
  /// - Project labor + bars → [outOfTeam]
  /// - Excluded Your Team (any score as global best) → [excludedTeamMember]
  /// - Otherwise → unknown (no marker)
  static FaceWalkUpResult decide({
    required Iterable<FaceWalkUpScore> allScores,
    double? minScore,
    double? minLead,
  }) {
    final scoreBar = minScore ?? FaceWalkUpTuning.minScore;
    final leadBar = minLead ?? FaceWalkUpTuning.minLead;

    final perEmployee = <int, FaceWalkUpScore>{};
    for (final s in allScores) {
      final prev = perEmployee[s.employeeId];
      if (prev == null || s.score > prev.score) {
        perEmployee[s.employeeId] = s;
      }
    }
    if (perEmployee.isEmpty) return FaceWalkUpResult.none;

    FaceWalkUpScore? globalBest;
    for (final s in perEmployee.values) {
      if (globalBest == null || s.score > globalBest.score) {
        globalBest = s;
      }
    }
    if (globalBest == null) return FaceWalkUpResult.none;

    double? secondScore;
    int? secondId;
    for (final s in perEmployee.values) {
      if (s.employeeId == globalBest.employeeId) continue;
      if (secondScore == null || s.score > secondScore) {
        secondScore = s.score;
        secondId = s.employeeId;
      }
    }
    final lead = globalBest.score - (secondScore ?? 0.0);
    final barsOk = globalBest.score >= scoreBar && lead >= leadBar;

    switch (globalBest.kind) {
      case FaceWalkUpKind.excludedTeam:
        return FaceWalkUpResult(
          identified: false,
          winnerEmployeeId: globalBest.employeeId,
          score: globalBest.score,
          lead: lead,
          secondEmployeeId: secondId,
          secondScore: secondScore,
          excludedTeamMember: true,
        );
      case FaceWalkUpKind.projectLabor:
        if (!barsOk) return FaceWalkUpResult.none;
        return FaceWalkUpResult(
          identified: false,
          winnerEmployeeId: globalBest.employeeId,
          score: globalBest.score,
          lead: lead,
          secondEmployeeId: secondId,
          secondScore: secondScore,
          outOfTeam: true,
        );
      case FaceWalkUpKind.candidate:
        return FaceWalkUpResult(
          identified: barsOk,
          winnerEmployeeId: globalBest.employeeId,
          score: globalBest.score,
          lead: lead,
          secondEmployeeId: secondId,
          secondScore: secondScore,
        );
    }
  }
}
