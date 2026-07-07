import 'package:el_race/core/site_management/face_recognition/data/local/face_db_database.dart';
import 'package:el_race/core/site_management/face_recognition/data/local/face_db_dao.dart';
import 'package:el_race/core/site_management/face_recognition/data/models/face_enrollment_pose.dart';
import 'package:el_race/core/site_management/face_recognition/data/repositories/face_db_repository.dart';

/// Result of a local face-template check (milliseconds, no network).
class FaceEnrollmentCheckResult {
  const FaceEnrollmentCheckResult({
    required this.employeeId,
    required this.templateCount,
    required this.isEnrolled,
  });

  final int employeeId;
  final int templateCount;
  final bool isEnrolled;

  bool get needsEnrollment => !isEnrolled;
}

/// Quick on-device check against cached face DB (after [FaceDbRepository.syncIfNeeded]).
class FaceEnrollmentStatusService {
  FaceEnrollmentStatusService({
    FaceDbDao? dao,
    FaceDbRepository? faceDbRepository,
  })  : _dao = dao ?? const FaceDbDao(),
        _faceDb = faceDbRepository ?? FaceDbRepository();

  final FaceDbDao _dao;
  final FaceDbRepository _faceDb;

  static const int minimumTemplates = FaceEnrollmentPose.minimumRequired;

  /// [refreshFaceDb] — when true, forces `/face_db/embeddings` re-download so
  /// Odoo deletes/re-enrolls are reflected (version-only sync can stay stale).
  Future<FaceEnrollmentCheckResult> checkEmployee(
    int employeeId, {
    bool refreshFaceDb = false,
  }) async {
    if (employeeId <= 0) {
      return FaceEnrollmentCheckResult(
        employeeId: employeeId,
        templateCount: 0,
        isEnrolled: false,
      );
    }

    if (refreshFaceDb) {
      await _faceDb.forceRefresh();
    } else {
      await _faceDb.syncIfNeeded();
    }

    final db = await FaceDbDatabase.instance.database;
    final count = await _dao.countTemplatesForEmployee(db, employeeId);
    return FaceEnrollmentCheckResult(
      employeeId: employeeId,
      templateCount: count,
      isEnrolled: count >= minimumTemplates,
    );
  }

  /// Re-read cache after enrollment upload + [FaceDbRepository.forceRefresh].
  Future<FaceEnrollmentCheckResult> recheckAfterEnrollment(int employeeId) =>
      checkEmployee(employeeId, refreshFaceDb: true);
}
