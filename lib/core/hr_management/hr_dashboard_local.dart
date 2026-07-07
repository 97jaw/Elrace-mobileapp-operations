import 'package:el_race/core/hr_management/models/hr_dashboard_data.dart';

/// Builds dashboard chart data from team request rows when `/api/hr/dashboard` is unavailable.
HrDashboardData buildLocalDashboardFromTeamRows(
  List<Map<String, dynamic>> rows, {
  bool includeDepartments = true,
}) {
  final typeCounts = <String, int>{};
  final requesterCounts = <String, int>{};
  final deptCounts = <String, int>{};

  for (final row in rows) {
    final type = row['type']?.toString() ?? 'Request';
    typeCounts[type] = (typeCounts[type] ?? 0) + 1;

    final name = row['employee_name']?.toString() ?? '';
    if (name.isNotEmpty) {
      requesterCounts[name] = (requesterCounts[name] ?? 0) + 1;
    }

    final dept = row['department']?.toString() ?? '';
    if (dept.isNotEmpty) {
      deptCounts[dept] = (deptCounts[dept] ?? 0) + 1;
    }
  }

  int pending = 0;
  int approved = 0;
  for (final row in rows) {
    final s = (row['ui_status'] ?? '').toString().toUpperCase();
    if (s == 'PENDING') pending++;
    if (s == 'APPROVED') approved++;
  }

  final byType = typeCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final topRequesters = requesterCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final deptTotal = deptCounts.values.fold<int>(0, (a, b) => a + b);

  return HrDashboardData(
    total: rows.length,
    pending: pending,
    approved: approved,
    byType: byType
        .take(12)
        .map(
          (e) => HrDashboardTypeSlice(
            filterType: e.key,
            label: e.key.length > 12 ? '${e.key.substring(0, 12)}…' : e.key,
            count: e.value,
          ),
        )
        .toList(),
    byMonth: const [],
    topRequesters: topRequesters
        .take(5)
        .map(
          (e) => HrDashboardRequester(name: e.key, count: e.value),
        )
        .toList(),
    byDepartment: deptTotal == 0
        ? const []
        : deptCounts.entries
            .map(
              (e) => HrDashboardDepartmentShare(
                label: e.key,
                share: e.value / deptTotal,
              ),
            )
            .toList()
          ..sort((a, b) => b.share.compareTo(a.share)),
    includeDepartments: includeDepartments && deptCounts.isNotEmpty,
  );
}

Map<String, int> countTeamKpisFromRows(List<Map<String, dynamic>> rows) {
  var pending = 0;
  var approved = 0;
  for (final row in rows) {
    final s = (row['ui_status'] ?? '').toString().toUpperCase();
    if (s == 'PENDING') pending++;
    if (s == 'APPROVED') approved++;
  }
  return {
    'pending': pending,
    'approved': approved,
    'total': rows.length,
  };
}
