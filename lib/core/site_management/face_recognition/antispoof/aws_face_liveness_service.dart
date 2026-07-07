import 'package:cloud_functions/cloud_functions.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/antispoof_config.dart';
import 'package:flutter/foundation.dart';

class AwsFaceLivenessSession {
  const AwsFaceLivenessSession({
    required this.sessionId,
    required this.mockMode,
  });

  final String sessionId;
  final bool mockMode;
}

class AwsFaceLivenessResult {
  const AwsFaceLivenessResult({
    required this.sessionId,
    required this.confidence,
    required this.live,
    required this.mockMode,
    this.status,
  });

  final String sessionId;
  final double confidence;
  final bool live;
  final bool mockMode;
  final String? status;

  bool get passed =>
      live && confidence >= AntispoofConfig.awsLivenessConfidenceThreshold;
}

/// Firebase region for liveness callables (must match [LIVENESS_FUNCTIONS_REGION] in functions/index.js).
const kLivenessFunctionsRegion = 'asia-south1';

/// Firebase callable wrapper for AWS Rekognition Face Liveness.
class AwsFaceLivenessService {
  AwsFaceLivenessService({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: kLivenessFunctionsRegion);

  final FirebaseFunctions _functions;

  Future<AwsFaceLivenessSession> createSession() async {
    final callable = _functions.httpsCallable('createFaceLivenessSession');
    final result = await callable.call<Map<String, dynamic>>({});
    final data = _asMap(result.data);
    final sessionId = data['session_id']?.toString() ?? '';
    if (sessionId.isEmpty) {
      throw StateError('createFaceLivenessSession returned empty session_id');
    }
    return AwsFaceLivenessSession(
      sessionId: sessionId,
      mockMode: data['mock_mode'] == true,
    );
  }

  Future<AwsFaceLivenessResult> getSessionResults(String sessionId) async {
    final callable = _functions.httpsCallable('getFaceLivenessSessionResults');
    final result = await callable.call<Map<String, dynamic>>({
      'session_id': sessionId,
    });
    final data = _asMap(result.data);
    final confidence = _toDouble(data['confidence']);
    final live = data['status']?.toString().toUpperCase() == 'SUCCEEDED' ||
        data['live'] == true;
    final status = data['status']?.toString();
    debugPrint(
      'AWS liveness: session=$sessionId status=$status conf=$confidence '
      'live=$live mock=${data['mock_mode']}',
    );
    return AwsFaceLivenessResult(
      sessionId: sessionId,
      confidence: confidence,
      live: live,
      mockMode: data['mock_mode'] == true,
      status: status,
    );
  }

  /// Poll after native FaceLivenessDetector completes (session may be IN_PROGRESS briefly).
  Future<AwsFaceLivenessResult> pollSessionResults(
    String sessionId, {
    int maxAttempts = 24,
    Duration interval = const Duration(milliseconds: 500),
  }) async {
    AwsFaceLivenessResult? last;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      last = await getSessionResults(sessionId);
      if (last.mockMode) return last;
      final status = last.status?.toUpperCase() ?? '';
      if (last.passed) return last;
      if (status == 'SUCCEEDED' ||
          status == 'FAILED' ||
          status == 'EXPIRED') {
        return last;
      }
      if (attempt < maxAttempts - 1) {
        await Future<void>.delayed(interval);
      }
    }
    return last ?? await getSessionResults(sessionId);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return {};
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
