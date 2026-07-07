/// One cached embedding row (employee primary and/or enrollment template).
class FaceEmbeddingRecord {
  const FaceEmbeddingRecord({
    required this.employeeId,
    required this.empCode,
    required this.name,
    required this.embedding,
    this.department = '',
    this.jobTitle = '',
    this.inForemanTeam = false,
    this.pose,
    this.faceImageId,
  });

  final int employeeId;
  final String empCode;
  final String name;
  final String department;
  final String jobTitle;
  final bool inForemanTeam;
  final String? pose;
  final int? faceImageId;
  final List<double> embedding;
}
