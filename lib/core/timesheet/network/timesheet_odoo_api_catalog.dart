/// Catalog of **existing** Odoo timesheet APIs (task sheet module) vs **new**
/// Module 6 endpoints. FM site attendance **writes** via submit only.
///
/// See `doc/Module_6_FM_API_Mapping.md` for screen-by-screen mapping.
abstract final class TimesheetOdooApiCatalog {
  // --- Existing production endpoints (reuse in FM) ---

  /// **Attendance write** — same as HR task sheet "Submit timesheet".
  static const String submitTimesheet = '/timesheet/submit';

  /// Foreman / user task list (used by `task_sheet_screen.dart`).
  static const String tasksList = '/tasks/list';

  /// Projects list (used by `get_projects`, swipe button, horizontal slider).
  static const String getProjects = '/get_projects';

  /// Site Management — role + status filtered on server (supervisor_ids / staff lines).
  static const String siteProjects = '/timesheet/site_projects';

  /// Resolved x_labor_ids / x_foreman_ids from login hr.employee.
  static const String myHrScope = '/timesheet/my_hr_scope';

  /// Project staff_list + supervisors for chat pickers.
  static const String projectStaff = '/timesheet/project_staff';

  /// Pandora timesheet PDF (``timesheet.wizard`` → ``print_timesheet``).
  static const String printReport = '/timesheet/print_report';

  /// All site labors (+ drivers) for report picker — same pool as `/employee/list`.
  static const String timesheetLaborList = '/timesheet/labor_list';

  /// Timesheet rows for a task on a date (used by `EmptyShiftPage`).
  static const String taskTimesheetsList = '/task/timesheets/list';

  /// Aggregated counts per day for a task (used by `TaskDetailsPage`).
  static const String countTimesheetsByDays = '/count/timesheets/by/days';

  /// Geofence check (used by swipe / location flows).
  static const String validateUserLocation = '/validate_user_location';

  /// Employee roster for timesheet picker (via `TeamMembersApiService`).
  static const String employeeList = '/employee/list';
  static const String employeeListX = '/employee/listx';

  // --- New Module 6 endpoints (SRD §14.1 — implement on Odoo) ---

  static const String projects = '/timesheet/projects';
  static const String projectDetail = '/timesheet/projects'; // + /{id}
  static const String projectTasks = '/timesheet/projects'; // + /{id}/tasks
  static const String taskDetail = '/timesheet/tasks'; // + /{id}
  static const String attendanceList = '/timesheet/attendance';
  static const String attendanceWrite = '/timesheet/attendance';
  static const String workersCreate = '/timesheet/workers';
  static const String reportsSubmit = '/timesheet/reports';
}

/// JSON-RPC `params` for `POST /api/timesheet/submit`.
/// FM maps capture UI → these keys; HR task sheet uses the same shape.
abstract final class TimesheetSubmitParams {
  static const String projectId = 'project_id';
  static const String taskId = 'task_id';
  static const String name = 'name';
  static const String breakTime = 'break_time';
  static const String leaveTypeId = 'leave_type_id';
  static const String employeeIds = 'employee_ids';
  static const String date = 'date';
  static const String dateTime = 'date_time';
  static const String dateTimeEnd = 'date_time_end';
}

/// FM screen / state → submit param source.
abstract final class TimesheetFmSubmitFieldSource {
  static const String projectId = 'TimesheetCaptureArgs.projectId (FM2/FM3 nav)';
  static const String taskId = 'TimesheetCaptureArgs.taskId';
  static const String name = 'Matched worker name or targetWorkerName';
  static const String breakTime = 'Default 0 (no FM UI; HR task sheet has picker)';
  static const String leaveTypeId = 'Default false (no FM UI; HR has leave types)';
  static const String employeeIds = 'Worker.odooEmployeeId from task roster / match';
  static const String date = 'Capture date (local today unless backdated)';
  static const String dateTime =
      'checkIn: capture time; checkOut: capture time − 8h (shift window)';
  static const String dateTimeEnd = 'Capture time (check-in and check-out end)';
}
