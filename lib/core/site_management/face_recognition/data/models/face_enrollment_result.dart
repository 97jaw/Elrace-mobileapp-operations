class FaceEnrollmentResult {
  const FaceEnrollmentResult({
    required this.success,
    required this.employeeId,
    this.message,
    this.enrollmentStatus,
    this.templateCount = 0,
    this.lines = const [],
  });

  final bool success;
  final int employeeId;
  final String? message;
  final String? enrollmentStatus;
  final int templateCount;
  final List<FaceEnrollmentLineResult> lines;

  factory FaceEnrollmentResult.failed(int employeeId, String message) {
    return FaceEnrollmentResult(
      success: false,
      employeeId: employeeId,
      message: message,
    );
  }
}

class FaceEnrollmentLineResult {
  const FaceEnrollmentLineResult({
    required this.faceImageId,
    required this.pose,
    this.embeddingStatus,
    this.s3Key,
  });

  final int faceImageId;
  final String pose;
  final String? embeddingStatus;
  final String? s3Key;
}
