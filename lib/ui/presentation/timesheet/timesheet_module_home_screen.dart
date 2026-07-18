import 'package:el_race/core/timesheet/providers/timesheet_role_provider.dart';
import 'package:el_race/ui/presentation/timesheet/foreman/fm1_foreman_dashboard.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_role_restricted_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Timesheet home card — foreman-only labor hours capture.
///
/// PM / HR review flows now live under the Site Management module. Any
/// non-foreman opening Timesheet is shown a role-restricted notice.
class TimesheetModuleHomeScreen extends ConsumerWidget {
  const TimesheetModuleHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolution = ref.watch(tmRoleResolutionProvider);
    if (resolution.role == TimesheetEffectiveRole.foreman) {
      return const Fm1ForemanDashboard();
    }
    return TimesheetRoleRestrictedScreen(roleLabel: resolution.role.label);
  }
}
