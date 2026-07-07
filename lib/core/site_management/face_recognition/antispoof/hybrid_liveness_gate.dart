import 'dart:ui';

import 'package:el_race/core/site_management/face_recognition/antispoof/antispoof_config.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/antispoof_layer1.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/liveness_attempt_log.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/on_device_pad_evaluator.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/timesheet_face_classification_snapshot.dart';
import 'package:flutter/foundation.dart';

enum LivenessGatePhase {
  idle,
  verifying,
  onDeviceRunning,
  onDeviceSpoof,
  onDevicePassed,
  awsRequired,
  awsRunning,
  fullyPassed,
  blocked,
}

class LivenessGateSnapshot {
  const LivenessGateSnapshot({
    required this.phase,
    required this.statusMessage,
    this.showSpoofWarning = false,
    this.onDeviceStepComplete = false,
    this.awsStepComplete = false,
    this.lastLog,
    this.awsSessionId,
    this.awsConfidence,
  });

  final LivenessGatePhase phase;
  final String statusMessage;
  final bool showSpoofWarning;
  final bool onDeviceStepComplete;
  final bool awsStepComplete;
  final LivenessAttemptLog? lastLog;
  final String? awsSessionId;
  final double? awsConfidence;

  /// Capture / recognition only after burst PAD within TTL (or AWS when enabled).
  bool get recognitionAllowed => phase == LivenessGatePhase.fullyPassed;

  bool get needsAwsStep =>
      AntispoofConfig.useAwsFaceLiveness &&
      (phase == LivenessGatePhase.onDevicePassed ||
          phase == LivenessGatePhase.awsRequired);

  bool get isVerifying => phase == LivenessGatePhase.verifying;

  int get stepNumber {
    if (phase == LivenessGatePhase.fullyPassed) return 2;
    if (isVerifying ||
        needsAwsStep ||
        phase == LivenessGatePhase.awsRunning) {
      return 2;
    }
    return 1;
  }
}

/// Tier 1 on-device PAD → Tier 2 AWS Face Liveness (mandatory every check-in).
class HybridLivenessGate {
  HybridLivenessGate({OnDevicePadEvaluator? onDevice})
      : _onDevice = onDevice ?? OnDevicePadEvaluator();

  final OnDevicePadEvaluator _onDevice;

  LivenessGatePhase _phase = LivenessGatePhase.idle;
  String _status = 'Center your face in the frame';
  Layer1Result? _lastLayer1;
  LivenessAttemptLog? _lastLog;
  String? _awsSessionId;
  double? _awsConfidence;
  DateTime? _verifiedAt;

  bool get _withinCaptureTtl {
    final verifiedAt = _verifiedAt;
    if (verifiedAt == null) return false;
    return DateTime.now().difference(verifiedAt) <=
        AntispoofConfig.livenessCaptureTtl;
  }

  LivenessGateSnapshot get snapshot {
    expireIfNeeded();
    return LivenessGateSnapshot(
        phase: _phase,
        statusMessage: _status,
        showSpoofWarning: _phase == LivenessGatePhase.onDeviceSpoof ||
            _phase == LivenessGatePhase.blocked,
        onDeviceStepComplete: _phase == LivenessGatePhase.onDevicePassed ||
            _phase == LivenessGatePhase.awsRequired ||
            _phase == LivenessGatePhase.awsRunning ||
            _phase == LivenessGatePhase.fullyPassed,
        awsStepComplete: _phase == LivenessGatePhase.fullyPassed,
        lastLog: _lastLog,
        awsSessionId: _awsSessionId,
        awsConfidence: _awsConfidence,
      );
  }

  bool get recognitionAllowed {
    expireIfNeeded();
    if (_phase != LivenessGatePhase.fullyPassed) return false;
    return _withinCaptureTtl;
  }

  /// Returns true if session was expired and reset.
  bool expireIfNeeded() {
    if (_phase != LivenessGatePhase.fullyPassed) return false;
    if (_withinCaptureTtl) return false;
    _phase = LivenessGatePhase.idle;
    _status = 'Liveness expired — verify again';
    _verifiedAt = null;
    debugPrint('AntiSpoof: liveness TTL expired');
    return true;
  }

  void resetSession() {
    _phase = LivenessGatePhase.idle;
    _status = 'Center your face in the frame';
    _lastLayer1 = null;
    _lastLog = null;
    _awsSessionId = null;
    _awsConfidence = null;
    _verifiedAt = null;
    _onDevice.reset();
  }

  void markVerifying() {
    if (_phase != LivenessGatePhase.idle &&
        _phase != LivenessGatePhase.onDeviceSpoof) {
      return;
    }
    _phase = LivenessGatePhase.verifying;
    _status = 'Verifying…';
    _onDevice.reset();
  }

  void setStatusMessage(String message) {
    _status = message;
  }

  void completeBurstVerification({
    required bool passed,
    required String message,
    Layer1Result? layer1,
  }) {
    _lastLayer1 = layer1;
    if (passed) {
      _phase = LivenessGatePhase.fullyPassed;
      _verifiedAt = DateTime.now();
      _status = 'Verified — hold for capture';
      _recordLog(
        finalVerdict: TimesheetLivenessFinalVerdict.passed,
        challengeResult: 'burst_passed',
      );
      return;
    }

    if (layer1?.verdict == Layer1Verdict.spoof) {
      _blockOnDevice(message);
      return;
    }

    _phase = LivenessGatePhase.blocked;
    _status = message;
    _recordLog(
      finalVerdict: TimesheetLivenessFinalVerdict.spoofBlocked,
      challengeResult: 'burst_failed',
    );
  }

  Future<void> evaluateStreamFrame({
    required String imagePath,
    required Rect faceBox,
    TimesheetFaceClassificationSnapshot? classification,
  }) async {
    if (_phase == LivenessGatePhase.fullyPassed ||
        _phase == LivenessGatePhase.verifying ||
        _phase == LivenessGatePhase.onDeviceRunning ||
        _phase == LivenessGatePhase.awsRunning ||
        _phase == LivenessGatePhase.onDevicePassed ||
        _phase == LivenessGatePhase.awsRequired ||
        _phase == LivenessGatePhase.blocked) {
      return;
    }
    if (_phase == LivenessGatePhase.onDeviceSpoof) return;

    _phase = LivenessGatePhase.onDeviceRunning;
    _status = 'Step 1: Checking face liveness…';

    final frame = await _onDevice.evaluateFrame(
      imagePath: imagePath,
      faceBox: faceBox,
      classification: classification,
    );
    _lastLayer1 = frame.layer1;

    if (!frame.passed) {
      if (frame.layer1.verdict == Layer1Verdict.spoof) {
        _blockOnDevice(frame.layer1.message);
      } else {
        _phase = LivenessGatePhase.idle;
        _status = frame.layer1.message;
      }
      return;
    }

    _phase = LivenessGatePhase.onDevicePassed;
    _status = 'Step 1 complete — start AWS Face Liveness (Step 2)';
    _recordLog(
      finalVerdict: TimesheetLivenessFinalVerdict.onDevicePassed,
      challengeResult: 'on_device_passed',
    );
  }

  void markAwsRequired() {
    if (_phase != LivenessGatePhase.onDevicePassed) return;
    _phase = LivenessGatePhase.awsRequired;
    _status = 'Step 2: AWS Face Liveness required';
  }

  void markAwsRunning({required String sessionId}) {
    _awsSessionId = sessionId;
    _phase = LivenessGatePhase.awsRunning;
    _status = 'Step 2: Follow the AWS liveness prompts…';
  }

  void completeAwsLiveness({
    required String sessionId,
    required double confidence,
    required bool live,
  }) {
    _awsSessionId = sessionId;
    _awsConfidence = confidence;
    if (!live ||
        confidence < AntispoofConfig.awsLivenessConfidenceThreshold) {
      _phase = LivenessGatePhase.blocked;
      _status =
          'AWS liveness failed (${confidence.toStringAsFixed(1)}%). Check-in blocked.';
      _recordLog(
        finalVerdict: TimesheetLivenessFinalVerdict.spoofBlocked,
        challengeResult: 'aws_failed',
        awsSessionId: sessionId,
        awsConfidence: confidence,
      );
      debugPrint('AntiSpoof: AWS liveness blocked conf=$confidence');
      return;
    }

    _phase = LivenessGatePhase.fullyPassed;
    _verifiedAt = DateTime.now();
    _status = 'Liveness verified — you may capture';
    _recordLog(
      finalVerdict: TimesheetLivenessFinalVerdict.passed,
      challengeResult: 'aws_passed',
      awsSessionId: sessionId,
      awsConfidence: confidence,
    );
  }

  Future<bool> verifyShutterFrame({
    required String imagePath,
    required Rect faceBox,
  }) async {
    return verifyShutterBurst(
      frames: [
        (imagePath: imagePath, faceBox: faceBox),
      ],
    );
  }

  Future<bool> verifyShutterBurst({
    required List<({String imagePath, Rect faceBox})> frames,
  }) async {
    for (final frame in frames) {
      final result = await _onDevice.evaluateShutter(
        imagePath: frame.imagePath,
        faceBox: frame.faceBox,
      );
      _lastLayer1 = result;
      if (result.verdict == Layer1Verdict.spoof ||
          result.verdict == Layer1Verdict.error) {
        _blockOnDevice(result.message);
        return false;
      }
    }
    return true;
  }

  void blockReplay(String message) {
    _blockOnDevice(message);
  }

  void retryAfterSpoof() {
    resetSession();
  }

  void _blockOnDevice(String message) {
    _phase = LivenessGatePhase.onDeviceSpoof;
    _status = message;
    _recordLog(
      finalVerdict: TimesheetLivenessFinalVerdict.spoofBlocked,
      challengeResult: 'blocked_on_device',
    );
  }

  void _recordLog({
    required TimesheetLivenessFinalVerdict finalVerdict,
    required String challengeResult,
    String? awsSessionId,
    double? awsConfidence,
  }) {
    _lastLog = LivenessAttemptLog(
      layer1Verdict: _lastLayer1?.verdict ?? Layer1Verdict.error,
      layer1FusedProbs: _lastLayer1?.fused?.probabilities,
      challengeAction: null,
      challengeResult: challengeResult,
      finalVerdict: finalVerdict,
      timestamp: DateTime.now(),
      awsSessionId: awsSessionId ?? _awsSessionId,
      awsConfidence: awsConfidence ?? _awsConfidence,
    );
    debugPrint('AntiSpoof log: ${_lastLog!.toJson()}');
  }
}

/// Alias for existing integrations.
typedef TimesheetLivenessGate = HybridLivenessGate;
