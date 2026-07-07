/// Result of polling local face DB until enrollment templates appear.
class FaceEnrollmentPollResult {
  const FaceEnrollmentPollResult({
    required this.templateCount,
    required this.ready,
    required this.timedOut,
  });

  final int templateCount;
  final bool ready;
  final bool timedOut;
}
