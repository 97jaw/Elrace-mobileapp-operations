import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';

/// Resolve labor by file / emp profile id or Odoo hr.employee id string.
TimesheetOdooEmployee? findTimesheetEmployeeByFileId(
  Iterable<TimesheetOdooEmployee> roster,
  String query,
) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return null;
  final lower = trimmed.toLowerCase();

  TimesheetOdooEmployee? partial;
  for (final employee in roster) {
    final fileId = employee.displayFileId.toLowerCase();
    if (fileId == lower) return employee;
    if ('${employee.employeeId}' == trimmed) return employee;
    if (fileId.contains(lower) || lower.contains(fileId)) {
      partial ??= employee;
    }
  }
  return partial;
}
