import 'package:el_race/core/site_management/face_recognition/antispoof/antispoof_layer1.dart';

enum TimesheetLivenessFinalVerdict {
  passed,
  onDevicePassed,
  flagged,
  spoofBlocked,
}

/// Local audit payload (Layer 4 backend upload skipped).
class LivenessAttemptLog {
  const LivenessAttemptLog({
    required this.layer1Verdict,
    required this.layer1FusedProbs,
    required this.challengeAction,
    required this.challengeResult,
    required this.finalVerdict,
    required this.timestamp,
    this.awsSessionId,
    this.awsConfidence,
  });

  final Layer1Verdict layer1Verdict;
  final List<double>? layer1FusedProbs;
  final String? challengeAction;
  final String? challengeResult;
  final TimesheetLivenessFinalVerdict finalVerdict;
  final DateTime timestamp;
  final String? awsSessionId;
  final double? awsConfidence;

  Map<String, dynamic> toJson() => {
        'layer1_verdict': layer1Verdict.name,
        'layer1_probs': layer1FusedProbs,
        'challenge_action': challengeAction,
        'challenge_result': challengeResult,
        'final_verdict': finalVerdict.name,
        'timestamp': timestamp.toIso8601String(),
        if (awsSessionId != null) 'aws_session_id': awsSessionId,
        if (awsConfidence != null) 'aws_confidence': awsConfidence,
      };
}
