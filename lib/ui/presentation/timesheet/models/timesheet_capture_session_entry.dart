import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';
import 'package:el_race/core/timesheet/services/capture_queue_service.dart';

/// One foreman-captured employee in an Add-timesheet session.
class TimesheetCaptureSessionEntry {
  const TimesheetCaptureSessionEntry({
    required this.employee,
    required this.matchScore,
    required this.draft,
    required this.capturedAt,
  });

  final TimesheetOdooEmployee employee;
  final double matchScore;
  final AttendanceCaptureDraft draft;
  final DateTime capturedAt;

  int get employeeId => employee.employeeId;
}
