import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/core/timesheet/providers/timesheet_hr_scope_provider.dart';
import 'package:el_race/core/timesheet/providers/timesheet_role_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Clears timesheet caches and dev overrides after login / logout so the next
/// session reflects the current user (role, profile, x_labor_ids / foremen).
void resetTimesheetSession(ProviderContainer container) {
  try {
    container.read(tmDevRoleOverrideProvider.notifier).setOverride(null);
    container.read(tmDevHrWideScopeProvider.notifier).setWideScope(false);
  } catch (_) {}

  try {
    container.read(hrDevViewOverrideProvider.notifier).setOverride(null);
  } catch (_) {}

  bumpLoginSessionRiverpod(container);

  container.invalidate(timesheetHrScopeProvider);
  container.invalidate(timesheetForemanLaborsProvider);
  container.invalidate(timesheetPmForemenProvider);
  container.invalidate(timesheetProjectBucketsProvider);
  container.invalidate(timesheetProjectsProvider);
}
