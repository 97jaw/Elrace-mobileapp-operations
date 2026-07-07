import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';

class TimesheetProjectArgs {
  const TimesheetProjectArgs({
    required this.projectId,
    this.projectName,
    this.clientImageUrl,
    this.woRefNo,
  });

  final String projectId;
  final String? projectName;
  final String? clientImageUrl;
  final String? woRefNo;
}

class TimesheetProjectsListArgs {
  const TimesheetProjectsListArgs({
    this.showFiltersInitially = false,
    this.openChatOnSelect = false,
  });

  final bool showFiltersInitially;
  /// When true, picking a project opens the project chat hub instead of dates.
  final bool openChatOnSelect;
}

/// Foreman flow: project → dates → day operations.
class TimesheetProjectDayArgs {
  const TimesheetProjectDayArgs({
    required this.projectId,
    required this.projectName,
    required this.taskId,
    required this.taskName,
    required this.date,
  });

  final String projectId;
  final String projectName;
  final String taskId;
  final String taskName;
  final DateTime date;
}

class TimesheetTaskArgs {
  const TimesheetTaskArgs({
    required this.projectId,
    required this.taskId,
    this.taskName,
  });

  final String projectId;
  final String taskId;
  final String? taskName;
}

/// Context for attendance capture (AT1 → AT2 → AT4).
class TimesheetCaptureArgs {
  const TimesheetCaptureArgs({
    required this.projectId,
    required this.taskId,
    this.taskName,
    this.workDate,
    this.mode = 'individual',
    this.event = 'checkIn',
    this.targetWorkerId,
    this.targetWorkerName,
    this.targetEmployeeOdooId,
  });

  final String projectId;
  final String taskId;
  final String? taskName;
  /// Calendar day from project date picker (legacy task-sheet parity).
  final DateTime? workDate;
  final String mode;
  final String event;
  final String? targetWorkerId;
  final String? targetWorkerName;
  final int? targetEmployeeOdooId;

  TimesheetCaptureArgs copyWith({
    String? mode,
    String? event,
    DateTime? workDate,
  }) {
    return TimesheetCaptureArgs(
      projectId: projectId,
      taskId: taskId,
      taskName: taskName,
      workDate: workDate ?? this.workDate,
      mode: mode ?? this.mode,
      event: event ?? this.event,
      targetWorkerId: targetWorkerId,
      targetWorkerName: targetWorkerName,
      targetEmployeeOdooId: targetEmployeeOdooId,
    );
  }
}

class TimesheetCaptureSummaryArgs {
  const TimesheetCaptureSummaryArgs({
    required this.capture,
    required this.mode,
    required this.rows,
    this.draftId,
  });

  final TimesheetCaptureArgs capture;
  final String mode;
  final List<TimesheetCaptureSummaryRow> rows;
  final String? draftId;
}

TimesheetCaptureArgs timesheetCaptureArgsFromRoute(Object? arguments) {
  if (arguments is TimesheetCaptureArgs) return arguments;
  if (arguments is TimesheetTaskArgs) {
    return TimesheetCaptureArgs(
      projectId: arguments.projectId,
      taskId: arguments.taskId,
      taskName: arguments.taskName,
    );
  }
  if (arguments is TimesheetProjectArgs) {
    return TimesheetCaptureArgs(
      projectId: arguments.projectId,
      taskId: 't_inspection',
    );
  }
  if (arguments is String && (arguments == 'individual' || arguments == 'group')) {
    return TimesheetCaptureArgs(
      projectId: 'p_midtown',
      taskId: 't_inspection',
      mode: arguments,
    );
  }
  return const TimesheetCaptureArgs(
    projectId: 'p_midtown',
    taskId: 't_inspection',
  );
}

class TimesheetCaptureSummaryRow {
  const TimesheetCaptureSummaryRow({
    required this.name,
    required this.status,
    required this.score,
    required this.outsideGeofence,
    this.workerId,
    this.odooEmployeeId,
    this.draftId,
  });

  final String name;
  final String status;
  final String score;
  final bool outsideGeofence;
  final String? workerId;
  final int? odooEmployeeId;
  final String? draftId;

  bool get canSubmit =>
      status == 'matched' || status == 'needs_confirmation';
}

/// Face enrollment entry from Add timesheet camera (or standalone).
class TimesheetFaceEnrollArgs {
  const TimesheetFaceEnrollArgs({
    required this.projectId,
    this.returnToCapture,
    this.prefillFileId,
  });

  final String projectId;
  final TimesheetProjectDayArgs? returnToCapture;
  final String? prefillFileId;
}

class TimesheetFaceEnrollCaptureArgs {
  const TimesheetFaceEnrollCaptureArgs({
    required this.projectId,
    required this.employee,
    this.returnToCapture,
  });

  final String projectId;
  final TimesheetOdooEmployee employee;
  final TimesheetProjectDayArgs? returnToCapture;
}
