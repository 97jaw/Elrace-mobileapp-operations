import 'package:el_race/ui/presentation/attendance_reports/utils/attendance_format_utils.dart';
import 'package:flutter/material.dart';

class AttendanceRecordDetailRow {
  const AttendanceRecordDetailRow(this.label, this.value);
  final String label;
  final String value;
}

/// Single row from POST /api/attendance/records.
class AttendanceRecordItem {
  const AttendanceRecordItem({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.employeeImageUrl,
    required this.checkIn,
    this.checkOut,
    required this.checkDate,
    required this.workedHours,
    required this.attendanceType,
    required this.statusClock,
    required this.dayStatus,
    required this.needsReview,
    this.empIdCode,
    this.requestId,
    this.requestName,
    this.requestTypeCode,
    this.requestDate,
    this.requestDateFrom,
    this.requestDateTo,
    this.jmStart,
    this.jmStartLabel,
    this.durationType,
    this.durationTypeLabel,
    this.jobMissionType,
    this.jobMissionTypeLabel,
    this.leaveBalance,
    this.remainingLeaveDays,
    this.startHour,
    this.startHourLabel,
    this.requestedDuration,
  });

  final int id;
  final int employeeId;
  final String employeeName;
  final String employeeImageUrl;
  final DateTime checkIn;
  final DateTime? checkOut;
  final DateTime checkDate;
  final double workedHours;
  final String attendanceType;
  final String statusClock;
  final String dayStatus;
  final bool needsReview;

  final String? empIdCode;
  final int? requestId;
  final String? requestName;
  final String? requestTypeCode;
  final DateTime? requestDate;
  final DateTime? requestDateFrom;
  final DateTime? requestDateTo;
  final String? jmStart;
  final String? jmStartLabel;
  final String? durationType;
  final String? durationTypeLabel;
  final String? jobMissionType;
  final String? jobMissionTypeLabel;
  final double? leaveBalance;
  final double? remainingLeaveDays;
  final String? startHour;
  final String? startHourLabel;
  final int? requestedDuration;

  bool get hasRequestRef =>
      (requestName != null && requestName!.trim().isNotEmpty) ||
      (requestId != null && requestId! > 0);

  String get requestRefLabel {
    if (requestName != null && requestName!.trim().isNotEmpty) {
      return requestName!.trim();
    }
    if (requestId != null && requestId! > 0) return '#$requestId';
    return '';
  }

  factory AttendanceRecordItem.fromMap(Map<String, dynamic> m) {
    DateTime? parseDt(dynamic v) => parseAttendanceDateTime(v);
    DateTime parseDtReq(dynamic v) => parseDt(v) ?? DateTime.now();

    double? parseD(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return AttendanceRecordItem(
      id: m['id'] as int? ?? 0,
      employeeId: m['employee_id'] as int? ?? 0,
      employeeName: m['employee_name'] as String? ?? '',
      employeeImageUrl: m['employee_image_url'] as String? ?? '',
      empIdCode: m['emp_id_code']?.toString(),
      checkIn: parseDtReq(m['check_in']),
      checkOut: parseDt(m['check_out']),
      checkDate: parseDtReq(m['check_date']),
      workedHours: (m['worked_hours'] as num?)?.toDouble() ?? 0,
      attendanceType: m['x_attendance_type'] as String? ?? '',
      statusClock: m['x_status_clock'] as String? ?? '',
      dayStatus: m['day_status'] as String? ?? '',
      needsReview: m['x_needs_review'] == true,
      requestId: m['request_id'] as int?,
      requestName: m['request_name']?.toString(),
      requestTypeCode: m['request_type_code']?.toString(),
      requestDate: parseDt(m['request_date']),
      requestDateFrom: parseDt(m['request_date_from']),
      requestDateTo: parseDt(m['request_date_to']),
      jmStart: m['jm_start']?.toString(),
      jmStartLabel: m['jm_start_label']?.toString(),
      durationType: m['duration_type']?.toString(),
      durationTypeLabel: m['duration_type_label']?.toString(),
      jobMissionType: m['job_mission_type']?.toString(),
      jobMissionTypeLabel: m['job_mission_type_label']?.toString(),
      leaveBalance: parseD(m['leave_balance']),
      remainingLeaveDays: parseD(m['remaining_leave_days']),
      startHour: m['start_hour']?.toString(),
      startHourLabel: m['start_hour_label']?.toString(),
      requestedDuration: _parseRequestedDuration(m),
    );
  }

  static int? _parseRequestedDuration(Map<String, dynamic> m) {
    final raw = m['requested_duration'];
    if (raw is int) return raw > 0 ? raw : null;
    if (raw is num) {
      final v = raw.toInt();
      return v > 0 ? v : null;
    }
    final parsed = int.tryParse(raw?.toString() ?? '');
    if (parsed != null && parsed > 0) return parsed;
    // Legacy: leaves stored days in duration_type before requested_duration key.
    final legacy = int.tryParse(m['duration_type']?.toString() ?? '');
    return legacy != null && legacy > 0 ? legacy : null;
  }
}

class AttendanceRecordBadge {
  const AttendanceRecordBadge(this.label, this.color);
  final String label;
  final Color color;
}

AttendanceRecordBadge attendanceRecordBadge(
  String dayStatus,
  String attendanceType,
  String statusClock,
) {
  final t = attendanceType.toLowerCase();
  final s = dayStatus.toLowerCase();

  if (t == 'absent' || s.contains('absent')) {
    return const AttendanceRecordBadge('Absent', Color(0xFFDC2626));
  }
  if (t == 'jm_morning') {
    return const AttendanceRecordBadge('JM Morning', Color(0xFF0284C7));
  }
  if (t == 'jm_afternoon') {
    return const AttendanceRecordBadge('JM Afternoon', Color(0xFF0284C7));
  }
  if (t == 'temp_permission') {
    return const AttendanceRecordBadge('Temp Permission', Color(0xFF0D9488));
  }
  if (t == 'short') {
    return const AttendanceRecordBadge('Short Leave', Color(0xFF6366F1));
  }
  if (t == 'sick') {
    return const AttendanceRecordBadge('Sick Leave', Color(0xFFEC4899));
  }
  if (t == 'annual') {
    return const AttendanceRecordBadge('Annual Leave', Color(0xFF8B5CF6));
  }
  if (t == 'death') {
    return const AttendanceRecordBadge('Death Leave', Color(0xFF6B7280));
  }
  if (t == 'maternity' || t == 'parental') {
    return const AttendanceRecordBadge('Parental Leave', Color(0xFFEC4899));
  }
  if (t == 'compensation') {
    return const AttendanceRecordBadge('Compensation', Color(0xFF7C3AED));
  }
  if (statusClock == 'late' || s.contains('late')) {
    return const AttendanceRecordBadge('Late', Color(0xFFD97706));
  }
  if (statusClock == 'ontime' ||
      s.contains('on time') ||
      s.contains('present')) {
    return const AttendanceRecordBadge('On Time', Color(0xFF16A34A));
  }
  return const AttendanceRecordBadge('Present', Color(0xFF16A34A));
}

/// Category-aware rows for JM / Temp / default attendance.
List<AttendanceRecordDetailRow> attendanceRecordDetailRows(
  AttendanceRecordItem record,
) {
  final code = (record.requestTypeCode ?? '').toUpperCase();
  final t = record.attendanceType.toLowerCase();
  final isJm = code == 'JM' ||
      t == 'jm_morning' ||
      t == 'jm_afternoon' ||
      record.jobMissionType != null;
  final isTemp = code == 'TEMP' ||
      t == 'temp_permission' ||
      record.startHour != null;

  if (isJm) {
    return [
      if (_hasLabel(record.jmStartLabel, record.jmStart))
        AttendanceRecordDetailRow(
          'Start Date',
          _displayLabel(record.jmStartLabel, record.jmStart),
        ),
      if (_hasLabel(record.durationTypeLabel, record.durationType))
        AttendanceRecordDetailRow(
          'Duration Type',
          _displayLabel(record.durationTypeLabel, record.durationType),
        ),
      if (_hasLabel(record.jobMissionTypeLabel, record.jobMissionType))
        AttendanceRecordDetailRow(
          'Job Mission Type',
          _displayLabel(record.jobMissionTypeLabel, record.jobMissionType),
        ),
    ];
  }

  if (isTemp) {
    return [
      if (_hasLabel(record.jmStartLabel, record.jmStart))
        AttendanceRecordDetailRow(
          'Start Date',
          _displayLabel(record.jmStartLabel, record.jmStart),
        ),
      if (_hasLabel(record.startHourLabel, record.startHour))
        AttendanceRecordDetailRow(
          'Start Hour',
          _displayLabel(record.startHourLabel, record.startHour),
        ),
      if (_hasLabel(record.durationTypeLabel, record.durationType))
        AttendanceRecordDetailRow(
          'Duration',
          _displayLabel(record.durationTypeLabel, record.durationType),
        ),
    ];
  }

  return _defaultAttendanceRows(record);
}

bool _hasLabel(String? label, String? raw) {
  if (label != null && label.trim().isNotEmpty) return true;
  return raw != null && raw.trim().isNotEmpty;
}

String _displayLabel(String? label, String? raw) {
  if (label != null && label.trim().isNotEmpty) return label.trim();
  return humanizeOdooKey(raw);
}

String _leaveDurationLabel(AttendanceRecordItem record) {
  final requested = record.requestedDuration;
  if (requested != null && requested > 0) {
    return requested == 1 ? '1 day' : '$requested days';
  }

  final from = record.requestDateFrom;
  final to = record.requestDateTo;
  if (from != null) {
    final start = DateTime(from.year, from.month, from.day);
    final end = to != null
        ? DateTime(to.year, to.month, to.day)
        : start;
    final days = end.difference(start).inDays + 1;
    if (days > 0) {
      return days == 1 ? '1 day' : '$days days';
    }
  }

  return '';
}

List<AttendanceRecordDetailRow> _defaultAttendanceRows(
  AttendanceRecordItem record,
) {
  final t = record.attendanceType.toLowerCase();
  if (t == 'absent') {
    return const [
      AttendanceRecordDetailRow('Status', 'No check-in recorded'),
    ];
  }

  const leaveTypes = {
    'short',
    'sick',
    'annual',
    'death',
    'maternity',
    'parental',
    'compensation',
  };
  if (leaveTypes.contains(t)) {
    final duration = _leaveDurationLabel(record);
    return [
      if (duration.isNotEmpty)
        AttendanceRecordDetailRow('Duration', duration),
      if (record.requestDateFrom != null)
        AttendanceRecordDetailRow(
          'Start Date',
          formatAttendanceDate(record.requestDateFrom!),
        ),
      if (record.requestDateTo != null)
        AttendanceRecordDetailRow(
          'End Date',
          formatAttendanceDate(record.requestDateTo!),
        ),
    ];
  }

  final rows = <AttendanceRecordDetailRow>[
    AttendanceRecordDetailRow(
      'Check In',
      formatAttendanceTime(record.checkIn),
    ),
  ];
  if (record.checkOut != null) {
    rows.add(AttendanceRecordDetailRow(
      'Check Out',
      formatAttendanceTime(record.checkOut!),
    ));
  }
  if (record.workedHours > 0) {
    rows.add(AttendanceRecordDetailRow(
      'Worked Hours',
      '${record.workedHours.toStringAsFixed(1)}h',
    ));
  }
  return rows;
}

String attendanceStatSheetTitle(String type) {
  switch (type) {
    case 'ontime':
      return 'On Time';
    case 'late':
      return 'Late';
    case 'absent':
      return 'Absent';
    case 'jm_tp':
      return 'Job Mission / Temp Permission';
    case 'leaves':
      return 'Leaves';
    default:
      return 'All Records';
  }
}
