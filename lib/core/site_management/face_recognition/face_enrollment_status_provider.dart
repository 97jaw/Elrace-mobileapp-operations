import 'package:el_race/core/site_management/face_recognition/face_enrollment_status_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final faceEnrollmentStatusServiceProvider =
    Provider<FaceEnrollmentStatusService>(
  (ref) => FaceEnrollmentStatusService(),
);
