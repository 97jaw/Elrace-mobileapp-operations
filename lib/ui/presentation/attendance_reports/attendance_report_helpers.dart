import 'package:el_race/core/theme/day_status_colors.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/Attendace_list/model/attendance_model.dart';

/// Maps API records to calendar days (local date, no time).
Map<DateTime, AttendanceRecord> recordsByCalendarDay(
  List<AttendanceRecord> records,
) {
  final out = <DateTime, AttendanceRecord>{};
  for (final r in records) {
    final d = DateTime.tryParse(r.date);
    if (d == null) continue;
    final key = DateTime(d.year, d.month, d.day);
    out[key] = r;
  }
  return out;
}

/// Drops rows dated after today (local) so daily lists do not show future days.
List<AttendanceRecord> attendanceRecordsUpToToday(List<AttendanceRecord> records) {
  final t = DateTime.now();
  final end = DateTime(t.year, t.month, t.day);
  return records.where((r) {
    final d = DateTime.tryParse(r.date);
    if (d == null) return false;
    final key = DateTime(d.year, d.month, d.day);
    return !key.isAfter(end);
  }).toList();
}

/// Log rows for the **logged-in user** — grouped [Result.records] or flat [Result.data].
List<AttendanceRecord> personalRecordsForAttendanceLog(Result result) {
  final records = result.records;
  if (records != null && records.isNotEmpty) {
    return attendanceRecordsUpToToday(records);
  }
  final flat = result.data;
  if (flat == null || flat.isEmpty) return [];
  final myId = SharedPref.getLoginDataOrNull()?.result?.data?.employee_id;
  if (myId == null) return [];
  final idStr = myId.toString();
  final mine = flat.where((r) {
    final eid = r.empId.trim();
    return eid == idStr || int.tryParse(eid) == myId;
  }).map(_attendanceRecordFromFlatRow).where((r) => r.date.isNotEmpty).toList();
  mine.sort((a, b) => b.date.compareTo(a.date));
  return attendanceRecordsUpToToday(mine);
}

AttendanceRecord _attendanceRecordFromFlatRow(FlatAttendanceData f) {
  var dateStr = '';
  final ci = DateTime.tryParse(f.checkIn);
  if (ci != null) {
    dateStr =
        '${ci.year.toString().padLeft(4, '0')}-${ci.month.toString().padLeft(2, '0')}-${ci.day.toString().padLeft(2, '0')}';
  }
  return AttendanceRecord(
    date: dateStr,
    checkIn: f.checkIn,
    checkOut: f.checkOut,
    workedHours: f.workedHours,
    status: f.status,
    checkInStatus: f.checkInStatus,
    checkOutStatus: f.checkOutStatus,
    attendanceType: f.attendanceType,
    dayStatus: f.dayStatus,
  );
}

/// Display status for a row — prefers `day_status` from backend (TASKS §1).
String displayStatusKey(AttendanceRecord r) {
  final ds = r.dayStatus?.trim();
  if (ds != null && ds.isNotEmpty) return ds;
  final t = r.attendanceType?.trim();
  if (t != null && t.isNotEmpty) return t;
  return r.status ?? r.checkInStatus ?? '';
}

class AttendanceKpiView {
  const AttendanceKpiView({
    required this.attendancePercent,
    required this.lateCount,
    required this.otHours,
    required this.workedHours,
    required this.requiredHours,
    required this.absentCount,
  });

  final double attendancePercent;
  final int lateCount;
  final double otHours;
  final double workedHours;
  final double requiredHours;
  final int absentCount;
}

AttendanceKpiView computeKpisFromResult(Result result, List<AttendanceRecord> records) {
  final working = result.totalWorkingDays ?? 0;
  final present = result.totalPresentDays ?? 0;
  final attPct = working > 0
      ? (present / working * 100).clamp(0, 100).toDouble()
      : 0.0;

  var late = 0;
  var absent = 0;
  var worked = 0.0;
  for (final r in records) {
    worked += r.workedHours;
    final key = DayStatusTokens.normalize(displayStatusKey(r));
    if (key.contains('LATE')) late++;
    if (key.contains('ABSENT')) absent++;
  }

  final requiredHrs = working > 0 ? working * 8.0 : 0.0;

  return AttendanceKpiView(
    attendancePercent: attPct,
    lateCount: late,
    otHours: 0,
    workedHours: worked,
    requiredHours: requiredHrs,
    absentCount: absent,
  );
}

/// Sunday = 0 … Saturday = 6 (Dart weekday: Mon=1 … Sun=7).
int weekdaySundayFirst(DateTime d) => d.weekday % 7;

/// Flat row status key (mirrors [displayStatusKey] for [AttendanceRecord]).
String displayStatusKeyFlat(FlatAttendanceData r) {
  final ds = r.dayStatus?.trim();
  if (ds != null && ds.isNotEmpty) return ds;
  final t = r.attendanceType?.trim();
  if (t != null && t.isNotEmpty) return t;
  return r.status ?? r.checkInStatus ?? '';
}

/// Team list for M1 — prefers `employees` from list API; falls back to unique staff from flat `data`.
List<EmployeeMonthlyAttendance> managerTeamRowsFromResult(
  Result result, {
  required int month,
  required int year,
}) {
  final monthly = result.monthlyEmployees;
  if (monthly != null && monthly.isNotEmpty) {
    return monthly;
  }
  final flat = result.data;
  if (flat == null || flat.isEmpty) return [];

  final byEmp = <String, List<FlatAttendanceData>>{};
  for (final row in flat) {
    final key = row.empId.trim().isNotEmpty ? row.empId.trim() : row.employeeName;
    byEmp.putIfAbsent(key, () => []).add(row);
  }

  final out = <EmployeeMonthlyAttendance>[];
  for (final entry in byEmp.entries) {
    final rows = entry.value;
    final head = rows.first;
    final empId = int.tryParse(entry.key) ?? int.tryParse(head.empId) ?? 0;
    var present = 0;
    var absent = 0;
    for (final row in rows) {
      final k = DayStatusTokens.normalize(displayStatusKeyFlat(row));
      if (k.contains('ABSENT')) {
        absent++;
      } else {
        present++;
      }
    }
    final url = head.employeeImageUrl.trim();
    out.add(
      EmployeeMonthlyAttendance(
        employeeId: empId,
        employeeName: head.employeeName,
        employeeImageUrl: url.isEmpty ? null : url,
        empId: head.empId.trim().isNotEmpty ? head.empId.trim() : null,
        month: month,
        year: year,
        totalWorkingDays: rows.length,
        totalPresentDays: present,
        totalAbsentDays: absent,
      ),
    );
  }
  out.sort((a, b) => a.employeeName.compareTo(b.employeeName));
  return out;
}

/// Rollup KPIs across the team (TASKS §7.1 / M1); `late` not available on monthly summary rows.
AttendanceKpiView computeManagerRollupKpis(List<EmployeeMonthlyAttendance> team) {
  if (team.isEmpty) {
    return AttendanceKpiView(
      attendancePercent: 0,
      lateCount: 0,
      otHours: 0,
      workedHours: 0,
      requiredHours: 0,
      absentCount: 0,
    );
  }
  var working = 0;
  var present = 0;
  var absent = 0;
  for (final e in team) {
    working += e.totalWorkingDays;
    present += e.totalPresentDays;
    absent += e.totalAbsentDays;
  }
  final attPct =
      working > 0 ? (present / working * 100).clamp(0, 100).toDouble() : 0.0;

  return AttendanceKpiView(
    attendancePercent: attPct,
    lateCount: 0,
    otHours: 0,
    workedHours: present * 8.0,
    requiredHours: working * 8.0,
    absentCount: absent,
  );
}

class TeamMonthlySummary {
  const TeamMonthlySummary({
    required this.presentDays,
    required this.absentDays,
    required this.lateCount,
  });

  final int presentDays;
  final int absentDays;
  final int lateCount;
}

TeamMonthlySummary computeTeamMonthlySummary(
  Result result,
  List<EmployeeMonthlyAttendance> team,
) {
  var present = 0;
  var absent = 0;
  for (final e in team) {
    present += e.totalPresentDays;
    absent += e.totalAbsentDays;
  }

  var late = 0;
  final flat = result.data;
  if (flat != null) {
    for (final row in flat) {
      final key = DayStatusTokens.normalize(displayStatusKeyFlat(row));
      if (key.contains('LATE')) late++;
    }
  }

  return TeamMonthlySummary(
    presentDays: present,
    absentDays: absent,
    lateCount: late,
  );
}
