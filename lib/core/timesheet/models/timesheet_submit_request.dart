import '../network/timesheet_odoo_api_catalog.dart' show TimesheetSubmitParams;
import '../timesheet_defaults.dart';

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
    );
  }

  Map<String, dynamic> toJsonRpcParams() {
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
