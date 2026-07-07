import 'timesheet_model_parsers.dart';
import 'timesheet_team_member.dart';

/// Parses Odoo `hr.employee` many2many id lists (`x_labor_ids`, `x_foreman_ids`).
abstract final class TimesheetHrMapping {
  static List<int> employeeIdsFromJson(dynamic raw) {
    if (raw == null) return const [];

    // Expanded records from /api/timesheet/my_hr_scope
    if (raw is List && raw.isNotEmpty) {
      final first = raw.first;
      if (first is Map) {
        final members = teamMembersFromJson(raw);
        return members.map((m) => m.employeeId).toList();
      }
      // Odoo command tuples: [[6, false, [1, 2, 3]]]
      if (first is List) {
        final ids = <int>[];
        for (final item in raw) {
          if (item is List && item.length >= 3) {
            final command = item[0];
            final payload = item[2];
            if (command == 6 || command == 4) {
              ids.addAll(_idsFromPayload(payload));
            } else if (command == 1 && item.length >= 2) {
              final id = tmIntOrNullFromJson(item[1]);
              if (id != null) ids.add(id);
            }
          }
        }
        if (ids.isNotEmpty) return ids;
      }
    }

    if (raw is List) {
      final ids = <int>[];
      for (final item in raw) {
        if (item is int) {
          ids.add(item);
          continue;
        }
        if (item is num) {
          ids.add(item.toInt());
          continue;
        }
        if (item is Map) {
          final id = tmIntOrNullFromJson(
            item['id'] ?? item['employee_id'] ?? item['emp_id'],
          );
          if (id != null) ids.add(id);
          continue;
        }
        final parsed = int.tryParse(item.toString());
        if (parsed != null) ids.add(parsed);
      }
      return ids;
    }
    final single = tmIntOrNullFromJson(raw);
    if (single != null) return [single];
    return const [];
  }

  static List<int> _idsFromPayload(dynamic payload) {
    if (payload is! List) return const [];
    return payload
        .map((e) => tmIntOrNullFromJson(e))
        .whereType<int>()
        .toList();
  }

  static List<TimesheetTeamMember> teamMembersFromJson(dynamic raw) {
    if (raw is! List) return const [];
    final members = <TimesheetTeamMember>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final employeeId = tmIntOrNullFromJson(
            map['employee_id'] ?? map['emp_id'] ?? map['id'],
          ) ??
          0;
      if (employeeId == 0) continue;
      members.add(
        TimesheetTeamMember(
          employeeId: employeeId,
          name: tmStringFromJson(
            map['name'] ?? map['employee_name'] ?? map['emp_name'],
          ),
          fileId: tmStringFromJson(
            map['file_id'] ??
                map['emp_profile_id'] ??
                map['emp_code'] ??
                map['employee_code'] ??
                employeeId,
          ),
          imageUrl: _optionalString(
            map['image_url'] ?? map['profile_photo_url'] ?? map['image'],
          ),
          subtitle: _optionalString(
            map['job_position'] ?? map['job_title'] ?? map['designation'],
          ),
          odooUserId: tmIntOrNullFromJson(
            map['odoo_user_id'] ?? map['user_id'],
          ),
          access: _optionalString(map['access']),
        ),
      );
    }
    return members;
  }

  static String? _optionalString(Object? value) {
    final text = tmStringFromJson(value);
    return text.isEmpty ? null : text;
  }
}

/// Login + roster scope for foreman labors / PM foremen.
class TimesheetHrEmployeeScope {
  const TimesheetHrEmployeeScope({
    required this.loginEmployeeId,
    required this.laborEmployeeIds,
    required this.foremanEmployeeIds,
    this.laborMembers = const [],
    this.foremanMembers = const [],
  });

  final int? loginEmployeeId;
  final Set<int> laborEmployeeIds;
  final Set<int> foremanEmployeeIds;
  final List<TimesheetTeamMember> laborMembers;
  final List<TimesheetTeamMember> foremanMembers;

  bool get hasLaborScope => laborEmployeeIds.isNotEmpty;
  bool get hasForemanScope => foremanEmployeeIds.isNotEmpty;
}
