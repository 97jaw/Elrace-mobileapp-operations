import 'package:el_race/core/site_management/face_recognition/data/repositories/face_db_repository.dart';
import 'package:el_race/core/site_management/face_recognition/face_enrollment_service.dart';
import 'package:el_race/core/site_management/face_recognition/face_recognition_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'face_enrollment_status_provider.dart';
export 'face_match_provider.dart';
export 'face_recognition_availability.dart';

final faceRecognitionServiceProvider = Provider<FaceRecognitionService>(
  (ref) => FaceRecognitionService(),
);

final faceEnrollmentServiceProvider = Provider<FaceEnrollmentService>(
  (ref) => FaceEnrollmentService(),
);

/// S.4 — sync when Add Timesheet opens (single [FaceRecognitionService] instance).
final faceDbSyncProvider = FutureProvider<FaceSyncResult>((ref) async {
  return ref.read(faceRecognitionServiceProvider).syncFaceDb();
});

/// Optional background refresh (e.g. timesheet module resume). Does not block UI.
final faceDbBackgroundSyncProvider = FutureProvider<FaceSyncResult>((ref) async {
  return ref.read(faceRecognitionServiceProvider).syncFaceDb();
});
