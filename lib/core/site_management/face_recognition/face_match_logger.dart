import 'package:el_race/core/site_management/face_recognition/face_match_session.dart';
import 'package:el_race/core/site_management/face_recognition/face_pilot_log_store.dart';
import 'package:el_race/core/site_management/face_recognition/face_recognition_config.dart';
import 'package:flutter/foundation.dart';

/// Pilot / tuning logs for Phase B (P.4).
abstract final class FaceMatchLogger {
  static void logAttempt({
    required double bestScore,
    required double secondBestScore,
    required int? employeeId,
    required String? employeeName,
    required bool inForemanTeam,
    required bool matchedAtProductionThreshold,
    required int templateCount,
    required int preprocessMs,
    required int embedMs,
    required int matchMs,
    required int totalMs,
    String? imagePath,
    FaceMatchUiOutcome? outcome,
    FaceForemanFollowUp? followUp,
  }) {
    final activePass = bestScore >= FaceRecognitionMatch.activeMatchThreshold;
    final slow = totalMs > FaceRecognitionPerformance.targetTotalMs;
    debugPrint(
      'FaceMatchLog: best=${bestScore.toStringAsFixed(4)} '
      'second=${secondBestScore.toStringAsFixed(4)} '
      'emp=$employeeId '
      'inTeam=$inForemanTeam '
      'match@${FaceRecognitionMatch.activeMatchThreshold}=$activePass '
      'prod@${FaceRecognitionMatch.defaultThreshold}=$matchedAtProductionThreshold '
      'templates=$templateCount '
      'ms=pre$preprocessMs+emb$embedMs+mat$matchMs=${totalMs}ms'
      '${slow ? " SLOW" : ""}',
    );
    if (kDebugMode && imagePath != null) {
      debugPrint('FaceMatchLog: image=$imagePath');
    }
    FacePilotLogStore.recordMatchAttempt(
      bestScore: bestScore,
      secondBestScore: secondBestScore,
      employeeId: employeeId,
      employeeName: employeeName,
      inForemanTeam: inForemanTeam,
      matchedAtProductionThreshold: matchedAtProductionThreshold,
      templateCount: templateCount,
      preprocessMs: preprocessMs,
      embedMs: embedMs,
      matchMs: matchMs,
      totalMs: totalMs,
      imagePath: imagePath,
      outcome: outcome,
      followUp: followUp,
    );
  }

  static void logForemanFollowUp({
    required FaceForemanFollowUp followUp,
    required FaceMatchSessionRecord? session,
  }) {
    FacePilotLogStore.recordForemanFollowUp(
      followUp: followUp,
      outcome: session?.outcome,
      employeeId: session?.employeeId,
      bestScore: session?.bestScore ?? 0,
    );
  }

  static void logTemplateScores({
    required int employeeId,
    required List<({String? pose, double score})> scores,
  }) {
    if (!kDebugMode) return;
    final parts = scores
        .map((s) => '${s.pose ?? "primary"}=${s.score.toStringAsFixed(4)}')
        .join(', ');
    debugPrint('FaceMatchLog: E.3 emp=$employeeId templates [$parts]');
  }
}
