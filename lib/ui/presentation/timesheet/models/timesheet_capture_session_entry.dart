import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';
import 'package:el_race/core/timesheet/services/capture_queue_service.dart';

/// One foreman-captured employee in an Add-timesheet session.
class TimesheetCaptureSessionEntry {
  const TimesheetCaptureSessionEntry({
    required this.employee,
    required this.matchScore,
    required this.draft,
    required this.capturedAt,
    this.verifyLead,
    this.verifyCohortSize,
    this.verifyUsedNoCohortBar,
  });

  final TimesheetOdooEmployee employee;

  /// 1:1 capture: the target score.
  final double matchScore;
  final AttendanceCaptureDraft draft;
  final DateTime capturedAt;

  /// 1:1 verification details; null for captures made before 1:1.
  final double? verifyLead;
  final int? verifyCohortSize;
  final bool? verifyUsedNoCohortBar;

  int get employeeId => employee.employeeId;
}
