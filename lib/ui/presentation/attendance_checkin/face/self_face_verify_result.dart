class SelfFaceVerifyResult {
  const SelfFaceVerifyResult({
    required this.verified,
    required this.score,
    required this.livenessOk,
    this.message,
  });

  final bool verified;
  final double score;
  final bool livenessOk;
  final String? message;

  static const failedMatch = SelfFaceVerifyResult(
    verified: false,
    score: 0,
    livenessOk: false,
    message: 'Face not matched. Please try again or contact HR.',
  );
}
