import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/Attendace_list/model/attendance_model.dart';
import 'package:el_race/ui/presentation/Attendace_list/repository/attendance_repository.dart';
import 'package:el_race/ui/presentation/attendance_reports/attendance_reports_period.dart';
import 'package:el_race/ui/presentation/attendance_reports/attendance_reports_scope.dart';
import 'package:el_race/utils/di.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final attendanceRepoForReportsProvider = Provider<AttendanceRepo>(
  (ref) => sl.get<AttendanceRepo>(),
);

/// List + optional employee detail merge — single load per period (Module 5).
class AttendanceSession {
  const AttendanceSession({
    required this.scope,
    required this.result,
    required this.period,
  });

  final AttendanceReportsScope scope;
  final Result result;
  final AttendancePeriod period;
}

final attendanceSessionProvider =
    AsyncNotifierProvider<AttendanceSessionNotifier, AttendanceSession>(
  AttendanceSessionNotifier.new,
);

class AttendanceSessionNotifier extends AsyncNotifier<AttendanceSession> {
  @override
  Future<AttendanceSession> build() async {
    final period = ref.watch(attendanceReportsPeriodProvider);
    final repo = ref.watch(attendanceRepoForReportsProvider);
    return _load(repo, period);
  }

  Future<void> refresh() async {
    // Let [AsyncValue.guard] emit loading without clearing prior data so
    // [AttendanceReportsModuleScreen] can keep the UI (skipLoadingOnRefresh).
    state = await AsyncValue.guard(() async {
      final period = ref.read(attendanceReportsPeriodProvider);
      final repo = ref.read(attendanceRepoForReportsProvider);
      return _load(repo, period);
    });
  }

  Future<AttendanceSession> _load(
    AttendanceRepo repo,
    AttendancePeriod period,
  ) async {
    final listRes = await repo.getAttendanceList(
      month: period.month,
      year: period.year,
      limit: 500,
      offset: 0,
    );
    if (listRes.statusCode != 200) {
      throw Exception('Attendance list failed (${listRes.statusCode})');
    }
    var result = attendanceModelFromJson(listRes.body).result;
    final st = result.status.toLowerCase();
    if (st == 'error') {
      final msg = _errorMessageFromBody(listRes.body);
      throw Exception(msg ?? 'Attendance list error');
    }

    final scope = (result.isManagerRole || attendanceLoginSuggestsManagerScope())
        ? AttendanceReportsScope.manager
        : AttendanceReportsScope.employee;

    if (scope == AttendanceReportsScope.employee) {
      result = await _mergeEmployeeDetailIfNeeded(repo, period, result);
    }

    return AttendanceSession(scope: scope, result: result, period: period);
  }

  Future<Result> _mergeEmployeeDetailIfNeeded(
    AttendanceRepo repo,
    AttendancePeriod period,
    Result listResult,
  ) async {
    if (listResult.records != null && listResult.records!.isNotEmpty) {
      return listResult;
    }
    var empId = listResult.employeeId;
    if (empId == null || empId <= 0) {
      empId = SharedPref.getLoginDataOrNull()?.result?.data?.employee_id;
    }
    if (empId == null || empId <= 0) {
      return listResult;
    }
    final detailRes = await repo.getAttendanceDetail(
      empId: empId,
      month: period.month,
      year: period.year,
    );
    if (detailRes.statusCode != 200) {
      return listResult;
    }
    final detail = attendanceModelFromJson(detailRes.body).result;
    if (detail.status.toLowerCase() == 'error') {
      return listResult;
    }
    return detail;
  }

  String? _errorMessageFromBody(String body) {
    try {
      final decoded = jsonDecode(body);
      final res = decoded is Map ? decoded['result'] : null;
      if (res is Map) {
        return res['message']?.toString();
      }
    } catch (_) {}
    return null;
  }
}

/// Manager M2 — one employee’s month (detail API).
class AttendanceDetailQuery {
  const AttendanceDetailQuery({
    required this.employeeId,
    required this.year,
    required this.month,
  });

  final int employeeId;
  final int year;
  final int month;

  @override
  bool operator ==(Object other) =>
      other is AttendanceDetailQuery &&
      other.employeeId == employeeId &&
      other.year == year &&
      other.month == month;

  @override
  int get hashCode => Object.hash(employeeId, year, month);
}

final attendanceEmployeeDetailProvider =
    FutureProvider.autoDispose.family<Result, AttendanceDetailQuery>(
  (ref, q) async {
    final repo = ref.watch(attendanceRepoForReportsProvider);
    final res = await repo.getAttendanceDetail(
      empId: q.employeeId,
      month: q.month,
      year: q.year,
    );
    if (res.statusCode != 200) {
      throw Exception('Detail failed (${res.statusCode})');
    }
    final result = attendanceModelFromJson(res.body).result;
    if (result.status.toLowerCase() == 'error') {
      throw Exception('Attendance detail error');
    }
    return result;
  },
);
