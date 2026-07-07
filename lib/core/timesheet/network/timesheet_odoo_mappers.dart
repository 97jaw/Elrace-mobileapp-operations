import 'package:el_race/core/timesheet/models/timesheet_models.dart';
import 'package:el_race/core/timesheet/models/timesheet_model_parsers.dart';
import 'timesheet_odoo_employee.dart';

/// Maps existing Odoo controller payloads → Module 6 models.
abstract final class TimesheetOdooMappers {
  static const String _erpOrigin = 'https://erp.elrace.com';

  static String _absoluteUrl(String value) {
    if (value.isEmpty) return value;
    if (value.startsWith('http')) return value;
    if (value.startsWith('/')) return '$_erpOrigin$value';
    return value;
  }

  static String workerIdForEmployee(int employeeId) => 'emp_$employeeId';

  static int? employeeIdFromWorkerId(String workerId) {
    if (workerId.startsWith('emp_')) {
      return int.tryParse(workerId.substring(4));
    }
    return int.tryParse(workerId);
  }

  /// Keeps rows whose Odoo **work date** (`date`) matches the selected calendar day.
  static List<Map<String, dynamic>> filterTimesheetRowsByWorkDate(
    List<Map<String, dynamic>> rows,
    DateTime day,
  ) {
    final y = day.year.toString().padLeft(4, '0');
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    final needle = '$y-$m-$d';
    return rows.where((row) {
      final workDate = row['date']?.toString() ?? '';
      if (workDate.isEmpty) return true;
      return workDate.startsWith(needle);
    }).toList();
  }

  static Project projectFromGetProjects(Map<String, dynamic> json) {
    final projectId = tmStringFromJson(
      json['project_id'] ?? json['id'] ?? json['agreement_id'],
    );
    return Project(
      id: projectId,
      name: tmStringFromJson(json['name']),
      code: projectId.isNotEmpty ? projectId : tmStringFromJson(json['code']),
      woRefNo: tmStringFromJson(
        json['wo_ref_no'] ?? json['wo_ref'] ?? json['work_order_no'],
      ),
      client: tmStringFromJson(
        json['partner_name'] ?? json['customer_name'] ?? json['client'],
      ),
      start: tmDateTimeFromJson(
        json['start'] ?? json['date_start'] ?? json['date'],
      ),
      end: tmDateTimeFromJson(json['end'] ?? json['date_end']),
      status: tmStringFromJson(
        json['status'] ?? json['project_status'] ?? json['state'] ?? 'IN_PROGRESS',
      ),
      lastUpdate: tmDateTimeFromJson(json['last_update'] ?? json['write_date']),
      address: tmStringFromJson(json['address'] ?? json['location'] ?? ''),
      heroImageUrl: _absoluteUrl(
        tmStringFromJson(json['hero_image_url'] ?? json['image'] ?? json['image_url']),
      ),
      clientImageUrl: _absoluteUrl(
        tmStringFromJson(
          json['client_image_url'] ??
              json['client_image'] ??
              json['partner_image_url'] ??
              json['customer_image_url'] ??
              json['partner_image'],
        ),
      ),
      progressPct: tmDoubleFromJson(
        json['progress_pct'] ?? json['progress'] ?? json['total_progress'],
      ),
      budgetMin: tmDoubleFromJson(json['budget_min']),
      budgetMax: tmDoubleFromJson(json['budget_max']),
      geofenceLat: tmDoubleFromJson(
        json['geofence_lat'] ??
            json['latitude'] ??
            json['latitute'] ??
            json['x_pr_lat'],
      ),
      geofenceLon: tmDoubleFromJson(
        json['geofence_lon'] ??
            json['longitude'] ??
            json['longitute'] ??
            json['x_pr_long'],
      ),
      geofenceRadiusM: tmDoubleFromJson(
        json['geofence_radius_m'] ?? json['radius'] ?? 100,
      ),
      pmId: tmStringFromJson(json['pm_id'] ?? ''),
      foremanIds: tmStringListFromJson(json['foreman_ids']),
      chatRoomId: tmStringFromJson(
        json['chat_room_id'] ?? 'project_$projectId',
      ),
    );
  }

  /// Groups multiple `tasks/list` rows (per employee) into unique [Task]s.
  static List<Task> tasksFromOdooList(List<Map<String, dynamic>> rows) {
    final builders = <String, _TaskAggregate>{};

    for (final row in rows) {
      final taskId = tmStringFromJson(row['id'] ?? row['task_id']);
      if (taskId.isEmpty) continue;

      final projectId = tmStringFromJson(row['project_id']);
      final employeeId = tmIntOrNullFromJson(
        row['employee_id'] ?? row['emp_id'] ?? row['employee'],
      );

      builders.putIfAbsent(
        taskId,
        () => _TaskAggregate(taskId: taskId, projectId: projectId, seed: row),
      );
      final aggregate = builders[taskId]!;
      if (employeeId != null) {
        aggregate.employeeIds.add(employeeId);
      }
      aggregate.merge(row);
    }

    return builders.values.map((aggregate) => aggregate.build()).toList();
  }

  static Worker workerFromOdooEmployee(
    TimesheetOdooEmployee member, {
    required String projectId,
  }) {
    return Worker(
      id: workerIdForEmployee(member.employeeId),
      projectId: projectId,
      name: member.name,
      trade: member.jobPosition ?? member.department ?? '',
      contact: member.phone ?? member.email ?? '',
      hourlyRate: 0,
      status: 'ACTIVE',
      faceId: '',
      refPhotoUrls:
          member.image == null || member.image!.isEmpty ? const [] : [member.image!],
      odooEmployeeId: member.employeeId,
    );
  }

  static List<Worker> workersForTask({
    required Task task,
    required List<TimesheetOdooEmployee> roster,
    required List<Map<String, dynamic>> timesheetRows,
    Set<int>? allowedLaborEmployeeIds,
  }) {
    final employeeIds = <int>{
      ...task.workerIds.map(employeeIdFromWorkerId).whereType<int>(),
      ...timesheetRows
          .map((row) => tmIntOrNullFromJson(
                row['employee_id'] ?? row['emp_id'] ?? row['employee'],
              ))
          .whereType<int>(),
    };

    if (allowedLaborEmployeeIds != null && allowedLaborEmployeeIds.isNotEmpty) {
      employeeIds.removeWhere((id) => !allowedLaborEmployeeIds.contains(id));
    }

    if (employeeIds.isEmpty) {
      return const [];
    }

    final workers = <Worker>[];
    for (final employeeId in employeeIds) {
      TimesheetOdooEmployee? member;
      for (final candidate in roster) {
        if (candidate.employeeId == employeeId) {
          member = candidate;
          break;
        }
      }
      if (member != null) {
        workers.add(
          workerFromOdooEmployee(member, projectId: task.projectId),
        );
      } else {
        final name = timesheetRows
            .map((row) {
              final rowEmp = tmIntOrNullFromJson(
                row['employee_id'] ?? row['emp_id'],
              );
              if (rowEmp != employeeId) return null;
              return tmStringFromJson(row['employee'] ?? row['employee_name']);
            })
            .whereType<String>()
            .where((value) => value.isNotEmpty)
            .firstOrNull;
        workers.add(
          Worker(
            id: workerIdForEmployee(employeeId),
            projectId: task.projectId,
            name: name ?? 'Employee $employeeId',
            trade: '',
            contact: '',
            hourlyRate: 0,
            status: 'ACTIVE',
            faceId: '',
            refPhotoUrls: const [],
            odooEmployeeId: employeeId,
          ),
        );
      }
    }
    return workers;
  }

  static List<AttendanceRecord> attendanceFromTimesheetRows({
    required String projectId,
    required String taskId,
    required List<Map<String, dynamic>> rows,
    required DateTime date,
  }) {
    final records = <AttendanceRecord>[];
    var index = 0;
    for (final row in rows) {
      final employeeId = tmIntOrNullFromJson(
        row['employee_id'] ?? row['emp_id'] ?? row['employee'],
      );
      if (employeeId == null) continue;

      final start = tmDateTimeFromJson(
        row['date_time'] ?? row['date_start'] ?? row['date'],
      );
      final end = tmDateTimeFromJson(row['date_time_end'] ?? row['date_end']);
      final timestamp = end ?? start ?? date;
      final event = _inferEvent(start: start, end: end, unitHours: row['unit_amount']);

      records.add(
        AttendanceRecord(
          id: tmStringFromJson(row['id']).isNotEmpty
              ? tmStringFromJson(row['id'])
              : 'ts_${taskId}_${employeeId}_$index',
          projectId: projectId,
          taskId: taskId,
          workerId: workerIdForEmployee(employeeId),
          foremanId: tmStringFromJson(row['foreman_id'] ?? row['user_id']),
          event: event,
          timestamp: timestamp,
          lat: tmDoubleFromJson(row['lat'] ?? row['latitude']),
          lon: tmDoubleFromJson(row['lon'] ?? row['longitude']),
          gpsAccuracyM: tmDoubleFromJson(row['gps_accuracy_m']),
          similarity: tmDoubleFromJson(row['similarity']),
          auditPhotoUrl: tmStringFromJson(row['audit_photo_url'] ?? ''),
          outsideGeofence: tmBoolFromJson(row['outside_geofence']),
          manualOverride: tmBoolFromJson(row['manual_override']),
          deviceId: tmStringFromJson(row['device_id'] ?? ''),
          syncState: tmStringFromJson(row['sync_state'] ?? row['state'] ?? 'synced'),
        ),
      );
      index += 1;
    }
    return records;
  }

  static String _inferEvent({
    required DateTime? start,
    required DateTime? end,
    required Object? unitHours,
  }) {
    final hours = tmDoubleFromJson(unitHours);
    if (end != null && start != null) {
      final duration = end.difference(start);
      if (duration.inMinutes >= 240 || hours >= 4) return 'checkOut';
    }
    if (hours >= 4) return 'checkOut';
    return 'checkIn';
  }
}

final class _TaskAggregate {
  _TaskAggregate({
    required this.taskId,
    required this.projectId,
    required Map<String, dynamic> seed,
  }) : _seed = Map<String, dynamic>.from(seed);

  final String taskId;
  final String projectId;
  final Set<int> employeeIds = {};
  Map<String, dynamic> _seed;

  void merge(Map<String, dynamic> row) {
    if (tmStringFromJson(_seed['name']).isEmpty) {
      _seed = Map<String, dynamic>.from(row);
    }
  }

  Task build() {
    final workerIds =
        employeeIds.map(TimesheetOdooMappers.workerIdForEmployee).toList();
    final name = tmStringFromJson(
      _seed['task_name'] ??
          _seed['name'] ??
          _seed['project_name'] ??
          'Task $taskId',
    );
    return Task(
      id: taskId,
      projectId: projectId.isNotEmpty
          ? projectId
          : tmStringFromJson(_seed['project_id']),
      name: name,
      description: tmStringFromJson(_seed['description'] ?? ''),
      plannedStart: tmDateTimeFromJson(
        _seed['planned_start'] ?? _seed['date_time'] ?? _seed['date'],
      ),
      plannedEnd: tmDateTimeFromJson(_seed['planned_end'] ?? _seed['date_time_end']),
      status: tmStringFromJson(_seed['status'] ?? _seed['state'] ?? 'IN_PROGRESS'),
      percentComplete: tmDoubleFromJson(_seed['percent_complete'] ?? _seed['progress']),
      assignedForemanId: tmStringFromJson(_seed['assigned_foreman_id'] ?? ''),
      workerIds: workerIds,
      odooAssigneeUserId: tmIntOrNullFromJson(
        _seed['user_id'] ?? _seed['assign_to_id'],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
