import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';

enum TimesheetOfflineQueueType {
  sitePhoto,
  siteReport,
}

class TimesheetOfflineQueueItem {
  const TimesheetOfflineQueueItem({
    required this.id,
    required this.projectId,
    required this.type,
    required this.createdAt,
    required this.payload,
  });

  final String id;
  final String projectId;
  final TimesheetOfflineQueueType type;
  final DateTime createdAt;
  final Map<String, dynamic> payload;

  factory TimesheetOfflineQueueItem.fromJson(Map<dynamic, dynamic> json) {
    final typeName =
        json['type']?.toString() ?? TimesheetOfflineQueueType.sitePhoto.name;
    return TimesheetOfflineQueueItem(
      id: json['id']?.toString() ?? '',
      projectId: json['project_id']?.toString() ?? '',
      type: TimesheetOfflineQueueType.values.firstWhere(
        (type) => type.name == typeName,
        orElse: () => TimesheetOfflineQueueType.sitePhoto,
      ),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      payload: Map<String, dynamic>.from(
        json['payload'] is Map ? json['payload'] as Map : const {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'type': type.name,
      'created_at': createdAt.toIso8601String(),
      'payload': payload,
    };
  }
}

class TimesheetOfflineQueueService {
  static const String boxName = 'timesheet_offline_queue';

  Future<void> enqueue(TimesheetOfflineQueueItem item) async {
    final box = await _openBox();
    await box.put(item.id, item.toJson());
  }

  Future<int> pendingCount() async {
    final box = await _openBox();
    return box.length;
  }

  Future<List<TimesheetOfflineQueueItem>> pending() async {
    final box = await _openBox();
    return box.values
        .whereType<Map<dynamic, dynamic>>()
        .map(TimesheetOfflineQueueItem.fromJson)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<TimesheetOfflineDrainResult> drain() async {
    final box = await _openBox();
    final items = await pending();
    var synced = 0;
    var failed = 0;

    for (final item in items) {
      try {
        // TODO(backend): replace this mock drain with Firebase Storage upload
        // plus Odoo bridge writes for photos/reports.
        await Future<void>.delayed(const Duration(milliseconds: 80));
        await box.delete(item.id);
        synced += 1;
      } catch (_) {
        failed += 1;
      }
    }

    return TimesheetOfflineDrainResult(
      synced: synced,
      failed: failed,
      remaining: await pendingCount(),
    );
  }

  Future<Box<dynamic>> _openBox() async {
    await _ensureHiveReady();
    return Hive.openBox<dynamic>(boxName);
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

class TimesheetOfflineDrainResult {
  const TimesheetOfflineDrainResult({
    required this.synced,
    required this.failed,
    required this.remaining,
  });

  final int synced;
  final int failed;
  final int remaining;
}

TimesheetOfflineQueueItem timesheetMockSitePhotoItem(String projectId) {
  final id = 'photo_${DateTime.now().millisecondsSinceEpoch}';
  return TimesheetOfflineQueueItem(
    id: id,
    projectId: projectId,
    type: TimesheetOfflineQueueType.sitePhoto,
    createdAt: DateTime.now(),
    payload: {
      'local_path': 'mock_site_photo.jpg',
      'category': 'progress',
      'caption': 'Mock captured site photo',
    },
  );
}

TimesheetOfflineQueueItem timesheetMockSiteReportItem({
  required String projectId,
  required String summary,
  required String weather,
  required String manpower,
  required String issues,
}) {
  final id = 'report_${DateTime.now().millisecondsSinceEpoch}';
  return TimesheetOfflineQueueItem(
    id: id,
    projectId: projectId,
    type: TimesheetOfflineQueueType.siteReport,
    createdAt: DateTime.now(),
    payload: {
      'summary': summary,
      'weather': weather,
      'manpower': manpower,
      'issues': issues,
      'signature_state': 'mock_signed',
    },
  );
}
