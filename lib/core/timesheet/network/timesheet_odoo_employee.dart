import 'package:el_race/core/timesheet/models/timesheet_hr_mapping.dart';
import 'package:el_race/core/timesheet/models/timesheet_model_parsers.dart';

/// Public HR photo base (no `/api` prefix).
const String kTimesheetErpPublicBase = 'https://erp.elrace.com';

/// One entry per [TimesheetOdooEmployee.employeeId].
///
/// [DropdownButton] requires `value ==` exactly one item; duplicate ids in the
/// labor list break that even when [TimesheetOdooEmployee.operator ==] matches.
List<TimesheetOdooEmployee> dedupeTimesheetEmployeesById(
  Iterable<TimesheetOdooEmployee> employees,
) {
  final seen = <int>{};
  final out = <TimesheetOdooEmployee>[];
  for (final e in employees) {
    if (seen.add(e.employeeId)) out.add(e);
  }
  return out;
}

/// Canonical list instance for dropdown [value], or null if not in [employees].
TimesheetOdooEmployee? timesheetEmployeeForDropdown(
  TimesheetOdooEmployee? selected,
  List<TimesheetOdooEmployee> employees,
) {
  if (selected == null) return null;
  TimesheetOdooEmployee? match;
  for (final e in employees) {
    if (e.employeeId == selected.employeeId) {
      match = e;
      break;
    }
  }
  return match;
}

/// Odoo employee row from `/employee/list` or `/timesheet/labor_list`.
class TimesheetOdooEmployee {
  const TimesheetOdooEmployee({
    required this.id,
    required this.employeeId,
    required this.name,
    this.jobPosition,
    this.department,
    this.phone,
    this.email,
    this.image,
    this.fileId,
    this.hasProfileImage,
    this.laborIds = const [],
    this.foremanIds = const [],
  });

  final int id;
  final int employeeId;
  final String name;
  final String? fileId;
  final List<int> laborIds;
  final List<int> foremanIds;
  final String? jobPosition;
  final String? department;
  final String? phone;
  final String? email;
  final String? image;
  final bool? hasProfileImage;

  /// File / emp id shown in lists (e.g. E12345).
  String get displayFileId {
    final code = fileId?.trim();
    if (code != null && code.isNotEmpty) return code;
    return employeeId.toString();
  }

  String? get imageUrl {
    final url = image?.trim();
    return (url != null && url.isNotEmpty) ? url : null;
  }

  /// URL used for Phase 1 face match (API value or standard public path).
  String? get faceMatchImageUrl {
    final fromApi = imageUrl;
    if (fromApi != null) return fromApi;
    if (employeeId > 0) {
      return '$kTimesheetErpPublicBase/public/employee/image/$employeeId';
    }
    return null;
  }

  /// Skip face match when HR has no stored profile photo.
  bool get canUseFaceMatch => hasProfileImage != false && faceMatchImageUrl != null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimesheetOdooEmployee && other.employeeId == employeeId;
  }

  @override
  int get hashCode => employeeId.hashCode;

  bool matchesSearchQuery(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) ||
        displayFileId.toLowerCase().contains(q);
  }

  factory TimesheetOdooEmployee.fromJson(Map<String, dynamic> json) {
    final id = tmIntOrNullFromJson(json['id'] ?? json['employee_id']) ?? 0;
    final employeeId =
        tmIntOrNullFromJson(json['employee_id'] ?? json['id']) ?? id;

    var fileId = _optionalString(
      json['file_id'] ??
          json['emp_id'] ??
          json['emp_profile_id'] ??
          json['employee_code'] ??
          json['emp_code'],
    );

    var name = tmStringFromJson(
      json['name'] ?? json['employee_name'] ?? json['display_name'],
    );

    if ((fileId == null || fileId.isEmpty) && name.contains(' ')) {
      final split = _splitFileIdFromCombinedName(name);
      fileId = split.fileId ?? fileId;
      name = split.name;
    }

    return TimesheetOdooEmployee(
      id: id,
      employeeId: employeeId,
      name: name,
      jobPosition: _optionalString(
        json['job_position'] ?? json['job_title'] ?? json['designation'],
      ),
      department: _optionalString(json['department'] ?? json['section']),
      phone: _optionalString(
        json['phone'] ?? json['mobile'] ?? json['work_phone'],
      ),
      email: _optionalString(json['email'] ?? json['work_email']),
      image: _optionalString(
        json['profile_photo_url'] ??
            json['image_url'] ??
            json['image'] ??
            json['face_image'] ??
            json['face_image_url'] ??
            json['user_face_image'],
      ),
      hasProfileImage: _optionalBool(
        json['has_profile_image'] ?? json['has_profile_photo'],
      ),
      fileId: fileId,
      laborIds: TimesheetHrMapping.employeeIdsFromJson(
        json['x_labor_ids'] ?? json['labor_ids'],
      ),
      foremanIds: TimesheetHrMapping.employeeIdsFromJson(
        json['x_foreman_ids'] ?? json['foreman_ids'],
      ),
    );
  }

  /// Legacy ``/employee/list`` used ``"{emp_id} {name}"`` in one field.
  static ({String? fileId, String name}) _splitFileIdFromCombinedName(
    String combined,
  ) {
    final trimmed = combined.trim();
    if (trimmed.isEmpty) {
      return (fileId: null, name: combined);
    }
    final space = trimmed.indexOf(' ');
    if (space <= 0) {
      return (fileId: null, name: combined);
    }
    final prefix = trimmed.substring(0, space).trim();
    final rest = trimmed.substring(space + 1).trim();
    if (prefix.isEmpty || rest.isEmpty) {
      return (fileId: null, name: combined);
    }
    return (fileId: prefix, name: rest);
  }

  static String? _optionalString(Object? value) {
    final text = tmStringFromJson(value);
    return text.isEmpty ? null : text;
  }

  static bool? _optionalBool(Object? value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = tmStringFromJson(value).toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return null;
  }
}
