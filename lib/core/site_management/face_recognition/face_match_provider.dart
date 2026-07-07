import 'package:el_race/core/site_management/face_recognition/face_match_logger.dart';
import 'package:el_race/core/site_management/face_recognition/face_match_session.dart';
import 'package:el_race/core/site_management/face_recognition/face_recognition_availability.dart';
import 'package:el_race/core/site_management/face_recognition/face_recognition_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// M.2 — readiness + last match session for Add Timesheet.
final faceRecognitionReadyProvider = Provider<bool>((ref) {
  return ref.watch(faceRecognitionServiceProvider).isReady;
});

final faceRecognitionAvailabilityProvider =
    Provider<FaceRecognitionAvailability>((ref) {
  return ref.watch(faceRecognitionServiceProvider).availability;
});

class FaceMatchSessionNotifier extends Notifier<FaceMatchSessionRecord?> {
  @override
  FaceMatchSessionRecord? build() => null;

  void record(FaceMatchSessionRecord record) {
    state = record;
    debugPrint(
      'FaceMatchSession: ${record.outcome} '
      'score=${record.bestScore.toStringAsFixed(4)} '
      'emp=${record.employeeId} followUp=${record.followUp}',
    );
  }

  void markConfirmed() {
    final s = state;
    if (s == null) return;
    state = s.copyWith(followUp: FaceForemanFollowUp.confirmed);
    FaceMatchLogger.logForemanFollowUp(
      followUp: FaceForemanFollowUp.confirmed,
      session: s,
    );
    debugPrint('FaceMatchSession: foreman confirmed emp=${s.employeeId}');
  }

  void markRejected() {
    final s = state;
    if (s == null) return;
    state = s.copyWith(followUp: FaceForemanFollowUp.rejected);
    FaceMatchLogger.logForemanFollowUp(
      followUp: FaceForemanFollowUp.rejected,
      session: s,
    );
    debugPrint('FaceMatchSession: foreman rejected match emp=${s.employeeId}');
  }

  void markManualPick() {
    final s = state;
    if (s == null) {
      debugPrint('FaceMatchSession: foreman manual pick (no prior match)');
      return;
    }
    state = s.copyWith(followUp: FaceForemanFollowUp.manualPick);
    FaceMatchLogger.logForemanFollowUp(
      followUp: FaceForemanFollowUp.manualPick,
      session: s,
    );
    debugPrint('FaceMatchSession: foreman manual pick (was ${s.outcome})');
  }

  void clear() => state = null;
}

final faceMatchSessionProvider =
    NotifierProvider<FaceMatchSessionNotifier, FaceMatchSessionRecord?>(
  FaceMatchSessionNotifier.new,
);
