import 'dart:io';

import 'package:el_race/core/timesheet/network/timesheet_functions_client.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';

enum AttendanceCaptureSyncState {
  pending,
  synced,
  failed,
}

class AttendanceCaptureDraft {
  const AttendanceCaptureDraft({
    required this.id,
    required this.projectId,
    required this.taskId,
    required this.event,
    required this.createdAt,
    required this.cropLocalPath,
    required this.lat,
    required this.lon,
    required this.syncState,
    this.workerId,
    this.error,
    this.attempts = 0,
    this.livenessFlagged = false,
    this.livenessLogJson,
    this.awsLivenessSessionId,
    this.awsLivenessConfidence,
  });

  final String id;
  final String projectId;
  final String taskId;
  final String event;
  final DateTime createdAt;
  final String cropLocalPath;
  final double? lat;
  final double? lon;
  final String? workerId;
  final AttendanceCaptureSyncState syncState;
  final String? error;
  final int attempts;
  /// Legacy HR flag — hybrid flow blocks instead of flagging pass-through.
  final bool livenessFlagged;
  final Map<String, dynamic>? livenessLogJson;
  final String? awsLivenessSessionId;
  final double? awsLivenessConfidence;

  AttendanceCaptureDraft copyWith({
    AttendanceCaptureSyncState? syncState,
    String? error,
    int? attempts,
    bool? livenessFlagged,
    Map<String, dynamic>? livenessLogJson,
    String? awsLivenessSessionId,
    double? awsLivenessConfidence,
  }) {
    return AttendanceCaptureDraft(
      id: id,
      projectId: projectId,
      taskId: taskId,
      event: event,
      createdAt: createdAt,
      cropLocalPath: cropLocalPath,
      lat: lat,
      lon: lon,
      workerId: workerId,
      syncState: syncState ?? this.syncState,
      error: error ?? this.error,
      attempts: attempts ?? this.attempts,
      livenessFlagged: livenessFlagged ?? this.livenessFlagged,
      livenessLogJson: livenessLogJson ?? this.livenessLogJson,
      awsLivenessSessionId:
          awsLivenessSessionId ?? this.awsLivenessSessionId,
      awsLivenessConfidence:
          awsLivenessConfidence ?? this.awsLivenessConfidence,
    );
  }

  factory AttendanceCaptureDraft.fromJson(Map<dynamic, dynamic> json) {
    final syncStateName = json['sync_state']?.toString() ?? 'pending';
    return AttendanceCaptureDraft(
      id: json['id']?.toString() ?? '',
      projectId: json['project_id']?.toString() ?? '',
      taskId: json['task_id']?.toString() ?? '',
      event: json['event']?.toString() ?? 'checkIn',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      cropLocalPath: json['crop_local_path']?.toString() ?? '',
      lat: _doubleOrNull(json['lat']),
      lon: _doubleOrNull(json['lon']),
      workerId: json['worker_id']?.toString(),
      syncState: AttendanceCaptureSyncState.values.firstWhere(
        (state) => state.name == syncStateName,
        orElse: () => AttendanceCaptureSyncState.pending,
      ),
      error: json['error']?.toString(),
      attempts: int.tryParse(json['attempts']?.toString() ?? '') ?? 0,
      livenessFlagged: json['liveness_flagged'] == true,
      livenessLogJson: json['liveness_log'] is Map
          ? Map<String, dynamic>.from(json['liveness_log'] as Map)
          : null,
      awsLivenessSessionId: json['aws_liveness_session_id']?.toString(),
      awsLivenessConfidence: _doubleOrNull(json['aws_liveness_confidence']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'task_id': taskId,
      'event': event,
      'created_at': createdAt.toIso8601String(),
      'crop_local_path': cropLocalPath,
      'lat': lat,
      'lon': lon,
      'worker_id': workerId,
      'sync_state': syncState.name,
      'error': error,
      'attempts': attempts,
      'liveness_flagged': livenessFlagged,
      if (livenessLogJson != null) 'liveness_log': livenessLogJson,
      if (awsLivenessSessionId != null)
        'aws_liveness_session_id': awsLivenessSessionId,
      if (awsLivenessConfidence != null)
        'aws_liveness_confidence': awsLivenessConfidence,
    };
  }

  static double? _doubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class CaptureQueueDrainResult {
  const CaptureQueueDrainResult({
    required this.synced,
    required this.failed,
    required this.remaining,
    required this.results,
  });

  final int synced;
  final int failed;
  final int remaining;
  final List<CaptureQueueMatchResult> results;
}

class CaptureQueueMatchResult {
  const CaptureQueueMatchResult({
    required this.draftId,
    required this.match,
  });

  final String draftId;
  final TimesheetMatchAttendanceResult match;
}

class TimesheetCaptureQueueService {
  TimesheetCaptureQueueService({TimesheetFunctionsClient? functionsClient})
      : _functionsClient = functionsClient ?? TimesheetFunctionsClient();

  static const String boxName = 'timesheet_capture_queue';
  static const String workmanagerTaskName = 'timesheet_sync_drain';
  static const String workmanagerUniqueName = 'timesheet_sync_drain_periodic';

  final TimesheetFunctionsClient _functionsClient;

  Future<void> enqueue(AttendanceCaptureDraft draft) async {
    final box = await _openBox();
    await box.put(draft.id, draft.toJson());
  }

  Future<List<AttendanceCaptureDraft>> pending() async {
    final box = await _openBox();
    return box.values
        .whereType<Map<dynamic, dynamic>>()
        .map(AttendanceCaptureDraft.fromJson)
        .where((draft) => draft.syncState != AttendanceCaptureSyncState.synced)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<int> pendingCount() async {
    return (await pending()).length;
  }

  Future<void> markSynced(String id) async {
    final box = await _openBox();
    final draft = _readDraft(box, id);
    if (draft == null) return;
    await box.put(
      id,
      draft.copyWith(syncState: AttendanceCaptureSyncState.synced).toJson(),
    );
  }

  Future<void> markFailed(String id, Object error) async {
    final box = await _openBox();
    final draft = _readDraft(box, id);
    if (draft == null) return;
    await box.put(
      id,
      draft
          .copyWith(
            syncState: AttendanceCaptureSyncState.failed,
            error: error.toString(),
            attempts: draft.attempts + 1,
          )
          .toJson(),
    );
  }

  Future<CaptureQueueDrainResult> drain({
    Future<TimesheetMatchAttendanceResult> Function(
      AttendanceCaptureDraft draft,
    )? sync,
  }) async {
    final drafts = await pending();
    var synced = 0;
    var failed = 0;
    final results = <CaptureQueueMatchResult>[];

    for (final draft in drafts) {
      try {
        final match = sync == null
            ? await _syncDraftWithFunctions(draft)
            : await sync(draft);
        await markSynced(draft.id);
        results.add(CaptureQueueMatchResult(draftId: draft.id, match: match));
        synced += 1;
      } catch (error) {
        await markFailed(draft.id, error);
        failed += 1;
      }
    }

    return CaptureQueueDrainResult(
      synced: synced,
      failed: failed,
      remaining: await pendingCount(),
      results: results,
    );
  }

  Future<void> registerBackgroundDrain() async {
    await Workmanager().registerPeriodicTask(
      workmanagerUniqueName,
      workmanagerTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  Future<Box<dynamic>> _openBox() async {
    await _ensureHiveReady();
    return Hive.openBox<dynamic>(boxName);
  }

  AttendanceCaptureDraft? _readDraft(Box<dynamic> box, String id) {
    final raw = box.get(id);
    if (raw is Map<dynamic, dynamic>) {
      return AttendanceCaptureDraft.fromJson(raw);
    }
    return null;
  }

  Future<TimesheetMatchAttendanceResult> _syncDraftWithFunctions(
    AttendanceCaptureDraft draft,
  ) {
    // TODO(backend): upload local crop to Firebase Storage and pass the HTTPS
    // URL. Phase 1 uses the local path as a deterministic mock crop key.
    return _functionsClient.matchAttendance(
      projectId: draft.projectId,
      taskId: draft.taskId,
      cropUrl: draft.cropLocalPath,
      lat: draft.lat ?? 0,
      lon: draft.lon ?? 0,
      event: draft.event,
    );
  }

  Future<void> _ensureHiveReady() async {
    try {
      await Hive.initFlutter();
    } catch (_) {
      if (Hive.isBoxOpen(boxName)) return;
      final docsDir =
          Directory('${Directory.systemTemp.parent.path}/Documents');
      if (!docsDir.existsSync()) docsDir.createSync(recursive: true);
      Hive.init(docsDir.path);
    }
  }
}

AttendanceCaptureDraft timesheetMockCaptureDraft() {
  return AttendanceCaptureDraft(
    id: 'mock_${DateTime.now().millisecondsSinceEpoch}',
    projectId: 'p_midtown',
    taskId: 't_inspection',
    event: 'checkIn',
    createdAt: DateTime.now(),
    cropLocalPath: 'mock_crop.jpg',
    lat: 25.2048,
    lon: 55.2708,
    syncState: AttendanceCaptureSyncState.pending,
  );
}
