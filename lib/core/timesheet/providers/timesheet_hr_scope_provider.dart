import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/timesheet/models/timesheet_hr_mapping.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/core/timesheet/services/timesheet_project_access_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final timesheetHrScopeProvider =
    FutureProvider<TimesheetHrEmployeeScope>((ref) async {
  ref.watch(loginSessionRevisionProvider);
  final client = ref.watch(timesheetApiClientProvider);
  return client.fetchMyHrScope();
});

/// Labor employee ids visible to PM on a project (foremen on site ∩ PM's foremen).
final timesheetPmProjectLaborIdsProvider = FutureProvider.autoDispose
    .family<Set<int>, String>((ref, projectId) async {
  final scope = await ref.watch(timesheetHrScopeProvider.future);
  final client = ref.watch(timesheetApiClientProvider);
  final roster = await client.fetchEmployeeRoster();
  final accessRows = await client.fetchProjectAccessRows();
  TimesheetProjectAccessRow? row;
  for (final candidate in accessRows) {
    if (candidate.projectId == projectId) {
      row = candidate;
      break;
    }
  }
  if (row == null) return scope.laborEmployeeIds;

  final siteForemen = row.supervisorEmployeeIds.toSet();
  final allowedForemen = scope.hasForemanScope
      ? siteForemen.where(scope.foremanEmployeeIds.contains).toSet()
      : siteForemen;

  final laborIds = <int>{...scope.laborEmployeeIds};
  for (final foremanId in allowedForemen) {
    for (final member in roster) {
      if (member.employeeId == foremanId) {
        laborIds.addAll(member.laborIds);
      }
    }
  }
  return laborIds;
});
