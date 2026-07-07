import 'package:el_race/core/timesheet/models/timesheet_model_parsers.dart';
import 'package:el_race/core/timesheet/providers/timesheet_role_provider.dart';
import 'package:el_race/core/utils/shared_pref.dart';

/// ERP staff line on `project.project` (PM scope).
class TimesheetProjectStaffLine {
  const TimesheetProjectStaffLine({
    required this.employeeId,
    required this.access,
  });

  final int employeeId;
  final String access;
}

/// Raw project row + parsed access metadata from `get_projects`.
class TimesheetProjectAccessRow {
  const TimesheetProjectAccessRow({
    required this.raw,
    required this.projectId,
    required this.supervisorEmployeeIds,
    required this.staffLines,
  });

  final Map<String, dynamic> raw;
  final String projectId;
  final List<int> supervisorEmployeeIds;
  final List<TimesheetProjectStaffLine> staffLines;
}

abstract final class TimesheetProjectAccessService {
  static int? loginEmployeeId() {
    final data = SharedPref.getLoginDataOrNull()?.result?.data;
    if (data == null) return null;
    // Use Odoo hr.employee id only — emp_profile_id is file id, not employee pk.
    return tmIntOrNullFromJson(data.employee_id) ??
        tmIntOrNullFromJson(data.emp_id);
  }

  static TimesheetProjectAccessRow parseAccessRow(Map<String, dynamic> json) {
    final projectId = tmStringFromJson(
      json['project_id'] ?? json['id'] ?? json['agreement_id'],
    );

    final supervisors = <int>[];
    final supervisorRaw = json['supervisors'];
    if (supervisorRaw is List) {
      for (final item in supervisorRaw) {
        if (item is! Map) continue;
        final id = tmIntOrNullFromJson(
          item['employee_id'] ?? item['emp_id'] ?? item['id'],
        );
        if (id != null) supervisors.add(id);
      }
    }
    for (final id in tmIntListFromJson(json['supervisor_ids'])) {
      if (!supervisors.contains(id)) supervisors.add(id);
    }
    for (final id in tmIntListFromJson(json['foreman_ids'])) {
      if (!supervisors.contains(id)) supervisors.add(id);
    }

    final staffLines = <TimesheetProjectStaffLine>[];
    final staffRaw = json['staff_line_ids'] ??
        json['staff_lines'] ??
        json['project_staff_lines'];
    if (staffRaw is List) {
      for (final item in staffRaw) {
        if (item is! Map) continue;
        final employeeId = tmIntOrNullFromJson(
          item['employee_id'] ?? item['emp_id'] ?? item['id'],
        );
        if (employeeId == null) continue;
        staffLines.add(
          TimesheetProjectStaffLine(
            employeeId: employeeId,
            access: tmStringFromJson(
              item['access'] ?? item['access_level'] ?? item['role'],
            ),
          ),
        );
      }
    }

    return TimesheetProjectAccessRow(
      raw: json,
      projectId: projectId,
      supervisorEmployeeIds: supervisors,
      staffLines: staffLines,
    );
  }

  static List<TimesheetProjectAccessRow> filterForRole({
    required List<TimesheetProjectAccessRow> rows,
    required TimesheetRoleResolution resolution,
    required int? employeeId,
  }) {
    if (resolution.hrWideScope) return rows;
    if (employeeId == null) return const [];

    switch (resolution.role) {
      case TimesheetEffectiveRole.foreman:
        return rows
            .where((row) => row.supervisorEmployeeIds.contains(employeeId))
            .toList();
      case TimesheetEffectiveRole.pm:
        return rows.where((row) {
          return row.staffLines.any(
            (line) =>
                line.employeeId == employeeId &&
                line.access.toLowerCase() == 'project',
          );
        }).toList();
    }
  }
}
