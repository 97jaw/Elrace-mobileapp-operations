import '../network/timesheet_odoo_api_catalog.dart' show TimesheetSubmitParams;
import '../services/capture_queue_service.dart' show AttendanceCaptureDraft;
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

/// Per-employee 1:1 face verification audit (v2 submit `face_verification`).
/// Manually added labors have none.
class TimesheetSubmitFaceAudit {
  const TimesheetSubmitFaceAudit({
    required this.employeeId,
    required this.verified,
    required this.liveness,
    this.score,
    this.lead,
    this.cohortSize,
    this.method = methodVerify,
  });

  final int employeeId;
  final bool verified;
  final double? score;
  final double? lead;
  final int? cohortSize;
  final String liveness;
  final String method;

  static const String methodVerify = 'profile_1to1';
  static const String methodWalkUp = 'profile_walkup';

  /// From a queued capture draft, or null when it carries no audit.
  static TimesheetSubmitFaceAudit? fromDraft(
    int employeeId,
    AttendanceCaptureDraft draft,
  ) {
    final verified = draft.faceVerified;
    if (verified == null) return null;
    return TimesheetSubmitFaceAudit(
      employeeId: employeeId,
      verified: verified,
      score: draft.faceScore,
      lead: draft.faceLead,
      cohortSize: draft.faceCohortSize,
      liveness: draft.faceLiveness ?? 'not_run',
      method: draft.faceMethod ?? methodVerify,
    );
  }

  Map<String, dynamic> toJson({String? appVersion}) => {
        'verified': verified,
        if (score != null) 'score': score,
        if (lead != null) 'lead': lead,
        if (cohortSize != null) 'cohort_size': cohortSize,
        'liveness': liveness,
        'method': method,
        if (appVersion != null && appVersion.isNotEmpty)
          'app_version': appVersion,
      };
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
    this.faceAudits = const [],
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

  /// Face verification audit for verified captures only; omitted when empty.
  final List<TimesheetSubmitFaceAudit> faceAudits;

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
    final start =
        isCheckOut ? capturedAt.subtract(const Duration(hours: 8)) : capturedAt;
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

  Map<String, dynamic> toJsonRpcParams({String? appVersion}) {
    final located = coords.where((c) => c.hasLocation);
    final audited = faceAudits.where((a) => employeeIds.contains(a.employeeId));
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
      if (audited.isNotEmpty)
        TimesheetSubmitParams.faceVerification: {
          for (final a in audited)
            a.employeeId.toString(): a.toJson(appVersion: appVersion),
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
