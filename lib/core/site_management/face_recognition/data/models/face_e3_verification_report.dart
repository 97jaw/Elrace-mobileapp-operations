/// E.3 — on-device probe vs cached enrollment templates (TC-C2 style).
class FaceE3VerificationReport {
  const FaceE3VerificationReport({
    required this.employeeId,
    required this.topScore,
    required this.passesVerification,
    required this.templateScores,
    required this.preprocessMs,
    required this.embedMs,
  });

  final int employeeId;
  final double topScore;
  final bool passesVerification;
  final List<({String? pose, double score})> templateScores;
  final int preprocessMs;
  final int embedMs;
}
