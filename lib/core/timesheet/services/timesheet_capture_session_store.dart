import 'dart:convert';

import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';
import 'package:el_race/core/timesheet/services/capture_queue_service.dart';
import 'package:el_race/ui/presentation/timesheet/models/timesheet_capture_session_entry.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_route_args.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists in-progress Add-timesheet captures across interruptions.
abstract final class TimesheetCaptureSessionStore {
  static const _prefsKey = 'tm_capture_session_v1';

  /// How long a saved (but not yet submitted) session stays valid.
  static const Duration defaultTtl = Duration(hours: 1);

  static Future<void> save({
    required TimesheetProjectDayArgs args,
    required List<TimesheetCaptureSessionEntry> captures,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (captures.isEmpty) {
      await prefs.remove(_prefsKey);
      return;
    }
    final payload = <String, dynamic>{
      'project_id': args.projectId,
      'project_name': args.projectName,
      'task_id': args.taskId,
      'task_name': args.taskName,
      'date': args.date.toIso8601String(),
      'saved_at': DateTime.now().toIso8601String(),
      'captures': [
        for (final entry in captures)
          {
            'match_score': entry.matchScore,
            'captured_at': entry.capturedAt.toIso8601String(),
            'employee': {
              'id': entry.employee.id,
              'employee_id': entry.employee.employeeId,
              'name': entry.employee.name,
              'file_id': entry.employee.fileId,
              'image': entry.employee.image,
              'job_position': entry.employee.jobPosition,
            },
            'draft': entry.draft.toJson(),
          },
      ],
    };
    await prefs.setString(_prefsKey, jsonEncode(payload));
  }

  static Future<({TimesheetProjectDayArgs args, List<TimesheetCaptureSessionEntry> captures})?>
      loadMatching(TimesheetProjectDayArgs args) async {
    final session = await loadAny();
    if (session == null) return null;
    final stored = session.args;
    if (stored.projectId != args.projectId ||
        stored.taskId != args.taskId ||
        !_sameDay(stored.date, args.date)) {
      return null;
    }
    return (args: args, captures: session.captures);
  }

  /// Loads any saved session regardless of project, honoring [ttl].
  /// Expired sessions are cleared and `null` is returned.
  static Future<
      ({
        TimesheetProjectDayArgs args,
        List<TimesheetCaptureSessionEntry> captures,
        DateTime savedAt,
      })?> loadAny({Duration ttl = defaultTtl}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt =
          DateTime.tryParse(map['saved_at']?.toString() ?? '') ?? DateTime.now();
      if (DateTime.now().difference(savedAt) > ttl) {
        await prefs.remove(_prefsKey);
        return null;
      }
      final date = DateTime.tryParse(map['date']?.toString() ?? '');
      if (date == null) return null;
      final args = TimesheetProjectDayArgs(
        projectId: map['project_id']?.toString() ?? '',
        projectName: map['project_name']?.toString() ?? '',
        taskId: map['task_id']?.toString() ?? '',
        taskName: map['task_name']?.toString() ?? '',
        date: date,
      );
      final capturesRaw = map['captures'];
      if (capturesRaw is! List) return null;
      final captures = <TimesheetCaptureSessionEntry>[];
      for (final item in capturesRaw) {
        if (item is! Map) continue;
        final empMap = item['employee'];
        final draftMap = item['draft'];
        if (empMap is! Map || draftMap is! Map) continue;
        captures.add(
          TimesheetCaptureSessionEntry(
            employee: TimesheetOdooEmployee(
              id: int.tryParse(empMap['id']?.toString() ?? '') ?? 0,
              employeeId:
                  int.tryParse(empMap['employee_id']?.toString() ?? '') ?? 0,
              name: empMap['name']?.toString() ?? '',
              fileId: empMap['file_id']?.toString(),
              image: empMap['image']?.toString(),
              jobPosition: empMap['job_position']?.toString(),
            ),
            matchScore:
                double.tryParse(item['match_score']?.toString() ?? '') ?? 0,
            draft: AttendanceCaptureDraft.fromJson(draftMap),
            capturedAt:
                DateTime.tryParse(item['captured_at']?.toString() ?? '') ??
                    DateTime.now(),
          ),
        );
      }
      if (captures.isEmpty) return null;
      return (args: args, captures: captures, savedAt: savedAt);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
