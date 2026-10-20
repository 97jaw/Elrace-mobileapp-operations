import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:el_race/core/site_management/face_recognition/face_match_session.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// P.4 — in-memory ring buffer + optional JSONL export for threshold tuning.
abstract final class FacePilotLogStore {
  static const int maxEntries = 100;
  static final List<Map<String, dynamic>> _buffer = [];
  static String? _lastExportPath;

  static String? get lastExportPath => _lastExportPath;

  static List<Map<String, dynamic>> snapshot() => List.unmodifiable(_buffer);

  static void recordMatchAttempt({
    required double bestScore,
    required double secondBestScore,
    required int? employeeId,
    required String? employeeName,
    required bool inForemanTeam,
    required bool matchedAtProductionThreshold,
    required int templateCount,
    required int preprocessMs,
    required int embedMs,
    required int matchMs,
    required int totalMs,
    String? imagePath,
    FaceForemanFollowUp? followUp,
    FaceMatchUiOutcome? outcome,
  }) {
    final entry = <String, dynamic>{
      'ts': DateTime.now().toIso8601String(),
      'best': bestScore,
      'second': secondBestScore,
      'emp_id': employeeId,
      'name': employeeName,
      'in_team': inForemanTeam,
      'prod_match': matchedAtProductionThreshold,
      'templates': templateCount,
      'preprocess_ms': preprocessMs,
      'embed_ms': embedMs,
      'match_ms': matchMs,
      'total_ms': totalMs,
      if (outcome != null) 'outcome': outcome.name,
      if (followUp != null) 'follow_up': followUp.name,
      if (imagePath != null && kDebugMode) 'image': imagePath,
    };
    _buffer.add(entry);
    while (_buffer.length > maxEntries) {
      _buffer.removeAt(0);
    }
    if (kDebugMode) {
      unawaited(_appendJsonl(entry));
    }
  }

  /// 1:1 verify attempt. Cohort member is logged by id only (tuning).
  static void recordVerifyAttempt({
    required int targetEmployeeId,
    required String outcome,
    required double? targetScore,
    required double? cohortMaxScore,
    required int? cohortMaxEmployeeId,
    required double? lead,
    required int cohortSize,
    required bool usedNoCohortBar,
    required double? faceWidthPx,
    required int preprocessMs,
    required int embedMs,
    required int verifyMs,
    required int totalMs,
    String? imagePath,
  }) {
    final entry = <String, dynamic>{
      'ts': DateTime.now().toIso8601String(),
      'event': 'verify',
      'target_id': targetEmployeeId,
      'outcome': outcome,
      't': targetScore,
      'c_max': cohortMaxScore,
      'c_max_id': cohortMaxEmployeeId,
      'lead': lead,
      'cohort': cohortSize,
      'no_cohort_bar': usedNoCohortBar,
      'face_px': faceWidthPx,
      'preprocess_ms': preprocessMs,
      'embed_ms': embedMs,
      'verify_ms': verifyMs,
      'total_ms': totalMs,
      if (imagePath != null && kDebugMode) 'image': imagePath,
    };
    _buffer.add(entry);
    while (_buffer.length > maxEntries) {
      _buffer.removeAt(0);
    }
    if (kDebugMode) {
      unawaited(_appendJsonl(entry));
    }
  }

  static void recordForemanFollowUp({
    required FaceForemanFollowUp followUp,
    required FaceMatchUiOutcome? outcome,
    required int? employeeId,
    required double bestScore,
  }) {
    final entry = <String, dynamic>{
      'ts': DateTime.now().toIso8601String(),
      'event': 'foreman_action',
      'follow_up': followUp.name,
      if (outcome != null) 'outcome': outcome.name,
      'emp_id': employeeId,
      'best': bestScore,
    };
    _buffer.add(entry);
    while (_buffer.length > maxEntries) {
      _buffer.removeAt(0);
    }
    debugPrint(
      'FacePilotLog: foreman ${followUp.name} emp=$employeeId '
      'score=${bestScore.toStringAsFixed(4)}',
    );
    if (kDebugMode) {
      unawaited(_appendJsonl(entry));
    }
  }

  static Future<String?> exportJsonlSnapshot() async {
    if (_buffer.isEmpty) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/face_match_pilot_log.jsonl');
      final lines = _buffer.map(jsonEncode).join('\n');
      await file.writeAsString('$lines\n', mode: FileMode.write);
      _lastExportPath = file.path;
      debugPrint(
          'FacePilotLog: exported ${_buffer.length} entries → ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('FacePilotLog: export failed: $e');
      return null;
    }
  }

  static Future<void> _appendJsonl(Map<String, dynamic> entry) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/face_match_pilot_log.jsonl');
      await file.writeAsString('${jsonEncode(entry)}\n', mode: FileMode.append);
      _lastExportPath = file.path;
    } catch (_) {
      // Non-fatal during pilot.
    }
  }
}
