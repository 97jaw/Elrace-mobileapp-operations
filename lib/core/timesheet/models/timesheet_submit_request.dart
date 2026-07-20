import '../network/timesheet_odoo_api_catalog.dart' show TimesheetSubmitParams;
import '../timesheet_defaults.dart';

/// Per-employee captured GPS point sent with a timesheet submission.
///
/// Maps to `x_lat` / `x_long` on the created `account.analytic.line`.
class TimesheetSubmitCoord {
  const TimesheetSubmitCoord({required this.employeeId, this.lat, this.lon});

  final int employeeId;
  final double? lat;
  final double? lon;

  bool get hasLocation => lat != null && lon != null;
}

/// Payload for Odoo `POST /api/timesheet/submit`.
///
/// **Site attendance = this request.** Same contract as HR task sheet
/// (`EmployeeShiftRequestPage`, `add_task_sheet.dart`). See
/// `doc/Module_6_FM_API_Mapping.md` and [TimesheetFmSubmitFieldSource].
class TimesheetSubmitRequest {
  const TimesheetSubmitRequest({
    required this.projectId,
    required this.taskId,
    required this.employeeIds,
    required this.employeeName,
    required this.date,
    required this.dateTime,
    required this.dateTimeEnd,
    this.breakTimeHours = 0,
    this.leaveTypeId = false,
    this.coords = const [],
  });

  final String projectId;
  final String taskId;
  final List<int> employeeIds;
  final String employeeName;
  final DateTime date;
  final DateTime dateTime;
  final DateTime dateTimeEnd;
  final int breakTimeHours;
  final Object leaveTypeId;

  /// Per-employee captured coordinates (`x_lat` / `x_long`). Entries without a
  /// location are dropped when building the request payload.
  final List<TimesheetSubmitCoord> coords;

  /// Builds submit params from a site capture (check-in / check-out).
  factory TimesheetSubmitRequest.fromSiteCapture({
    required String projectId,
    required String taskId,
    required int employeeId,
    required String employeeName,
    required DateTime capturedAt,
    required bool isCheckOut,
    int breakTimeHours = 0,
    Object leaveTypeId = false,
    double? lat,
    double? lon,
  }) {
    final start = isCheckOut
        ? capturedAt.subtract(const Duration(hours: 8))
        : capturedAt;
    return TimesheetSubmitRequest(
      projectId: projectId,
      taskId: taskId,
      employeeIds: [employeeId],
      employeeName: employeeName,
      date: capturedAt,
      dateTime: start,
      dateTimeEnd: capturedAt,
      breakTimeHours: breakTimeHours,
      leaveTypeId: leaveTypeId,
      coords: [
        TimesheetSubmitCoord(employeeId: employeeId, lat: lat, lon: lon),
      ],
    );
  }

  Map<String, dynamic> toJsonRpcParams() {
    final located = coords.where((c) => c.hasLocation);
    return {
      TimesheetSubmitParams.projectId: _coerceOdooId(projectId),
      TimesheetSubmitParams.taskId: TimesheetDefaults.submitTaskIdParam(taskId),
      TimesheetSubmitParams.name: employeeName,
      TimesheetSubmitParams.breakTime: breakTimeHours,
      TimesheetSubmitParams.leaveTypeId: leaveTypeId,
      TimesheetSubmitParams.employeeIds: employeeIds,
      TimesheetSubmitParams.date: _formatDate(date),
      TimesheetSubmitParams.dateTime: _formatDateTime(dateTime),
      TimesheetSubmitParams.dateTimeEnd: _formatDateTime(dateTimeEnd),
      if (located.isNotEmpty)
        TimesheetSubmitParams.coords: {
          for (final c in located)
            c.employeeId.toString(): {'x_lat': c.lat, 'x_long': c.lon},
        },
    };
  }

  static String _formatDate(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static dynamic _coerceOdooId(String value) {
    final parsed = int.tryParse(value);
    return parsed ?? value;
  }

  static String _formatDateTime(DateTime value) {
    return '${_formatDate(value)} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}:'
        '${value.second.toString().padLeft(2, '0')}';
  }
}

class TimesheetSubmitResult {
  const TimesheetSubmitResult({
    required this.success,
    this.message,
  });

  final bool success;
  final String? message;
}
