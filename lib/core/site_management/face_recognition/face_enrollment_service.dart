import 'package:el_race/core/site_management/face_recognition/data/models/face_enrollment_pose.dart';
import 'package:el_race/core/site_management/face_recognition/data/models/face_enrollment_result.dart';
import 'package:el_race/core/site_management/face_recognition/data/repositories/face_enrollment_repository.dart';

/// Phase C — mobile enrollment facade (no UI; wire from PM/HR screens later).
class FaceEnrollmentService {
  FaceEnrollmentService({FaceEnrollmentRepository? repository})
      : _repository = repository ?? FaceEnrollmentRepository();

  final FaceEnrollmentRepository _repository;

  Future<FaceEnrollmentResult> enrollOdooEmployee({
    required int employeeId,
    required Map<FaceEnrollmentPose, String> imagePathsByPose,
    int? foremanEmployeeId,
    bool refreshFaceDbAfterUpload = true,
    bool waitForTemplatesInFaceDb = true,
  }) {
    return _repository.enrollEmployee(
      employeeId: employeeId,
      imagePathsByPose: imagePathsByPose,
      foremanEmployeeId: foremanEmployeeId,
      refreshFaceDbAfterUpload: refreshFaceDbAfterUpload,
      waitForTemplatesInFaceDb: waitForTemplatesInFaceDb,
    );
  }

  /// Convenience: ordered list [front, left, right, up] (+ optional down).
  Future<FaceEnrollmentResult> enrollFromPhotoList({
    required int employeeId,
    required List<String> localPaths,
    bool refreshFaceDbAfterUpload = true,
  }) {
    const order = [
      FaceEnrollmentPose.front,
      FaceEnrollmentPose.left,
      FaceEnrollmentPose.right,
      FaceEnrollmentPose.up,
      FaceEnrollmentPose.down,
    ];
    final map = <FaceEnrollmentPose, String>{};
    for (var i = 0; i < localPaths.length && i < order.length; i++) {
      map[order[i]] = localPaths[i];
    }
    return enrollOdooEmployee(
      employeeId: employeeId,
      imagePathsByPose: map,
      refreshFaceDbAfterUpload: refreshFaceDbAfterUpload,
    );
  }
}
