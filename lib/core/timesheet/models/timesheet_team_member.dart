import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';

class TimesheetTeamMember {
  const TimesheetTeamMember({
    required this.employeeId,
    required this.name,
    required this.fileId,
    this.imageUrl,
    this.subtitle,
    this.odooUserId,
    this.access,
  });

  final int employeeId;
  final String name;
  final String fileId;
  final String? imageUrl;
  final String? subtitle;
  final int? odooUserId;
  /// `supervisor`, `project` (PM line), or other staff_list access from API.
  final String? access;

  bool get isSupervisor => access == 'supervisor';
  bool get isProjectManager => access == 'project';

  factory TimesheetTeamMember.fromEmployee(TimesheetOdooEmployee employee) {
    return TimesheetTeamMember(
      employeeId: employee.employeeId,
      name: employee.name,
      fileId: employee.fileId ?? employee.employeeId.toString(),
      imageUrl: employee.image,
      subtitle: employee.jobPosition ?? employee.department,
    );
  }

  TimesheetOdooEmployee toOdooEmployee() {
    return TimesheetOdooEmployee(
      id: employeeId,
      employeeId: employeeId,
      name: name,
      fileId: fileId,
      image: imageUrl,
      jobPosition: subtitle,
    );
  }
}
