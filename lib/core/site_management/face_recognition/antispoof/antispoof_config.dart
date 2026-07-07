/// Tunable thresholds for anti-spoof (on-device burst PAD; optional AWS Face Liveness).
class AntispoofConfig {
  AntispoofConfig._();

  /// When false (default), use fast on-device burst verification (~5s).
  /// When true, require AWS Face Liveness oval after on-device pre-check.
  static const bool useAwsFaceLiveness = false;

  /// Frames collected from live stream for burst PAD.
  static const int burstFrameCount = 4;

  static const Duration burstFrameInterval = Duration(milliseconds: 400);

  /// When false, burst liveness starts on any detected face (not full quality gate).
  static const bool burstRequiresQualityGate = false;

  /// Max wall time for burst collection + PAD analysis.
  static const Duration maxVerificationBudget = Duration(seconds: 5);

  /// Verify → capture must finish within this window.
  static const Duration livenessCaptureTtl = Duration(seconds: 3);

  /// Delay before auto-restarting liveness after retry tap.
  static const Duration livenessRetryDelay = Duration(seconds: 1);

  /// Stream frames PAD-checked immediately before still capture.
  static const int preShutterFrameCount = 2;

  static const Duration preShutterFrameInterval = Duration(milliseconds: 200);

  /// Temporal motion check sample count for burst (matches burstFrameCount).
  static const int burstTemporalMinSamples = 4;

  /// IoU threshold for "frozen" boxes — only combined with zero head/eye motion.
  static const double burstMaxFrameSimilarity = 0.995;

  /// Min combined yaw+pitch variance to count as natural head motion (degrees²).
  static const double burstMinHeadMotionVariance = 0.05;

  /// Min eye-open probability variance across burst frames.
  static const double burstMinEyeVariance = 0.008;

  static const String modelV2Asset =
      'assets/antispoof/minifasnet_v2_2.7_80x80.tflite';
  static const String modelV1SeAsset =
      'assets/antispoof/minifasnet_v1se_4.0_80x80.tflite';

  static const double modelV2CropScale = 2.7;
  static const double modelV1SeCropScale = 4.0;

  static const int inputSize = 80;
  static const int numClasses = 3;

  /// Fused softmax probability for class index 1 (live / real).
  static const double liveConfidenceThreshold = 0.70;

  /// Below live threshold but still live argmax → uncertain; AWS still required.
  static const double liveUncertainFloor = 0.45;

  /// Spoof if print + replay probabilities exceed this (even when argmax is live).
  static const double spoofAttackSumThreshold = 0.55;

  /// Multi-frame Layer 1: need this many passing frames out of [multiFrameWindow].
  static const int multiFramePassRequired = 4;
  static const int multiFrameWindow = 5;

  /// Min interval between on-device PAD checks on the live stream.
  static const Duration onDeviceThrottle = Duration(milliseconds: 400);

  /// AWS Rekognition Face Liveness minimum confidence (0–100).
  /// AWS may return SUCCEEDED in the high 70s; 80 was rejecting valid live sessions.
  static const double awsLivenessConfidenceThreshold = 75.0;

  static const int liveClassIndex = 1;
  static const int printAttackClassIndex = 0;
  static const int replayAttackClassIndex = 2;

  @Deprecated('Use onDeviceThrottle')
  static const Duration layer1Throttle = onDeviceThrottle;

  @Deprecated('ML Kit challenges removed; AWS is active liveness')
  static const Duration challengeWindow = Duration(seconds: 6);
}
