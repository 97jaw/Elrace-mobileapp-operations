import 'package:el_race/core/timesheet/providers/timesheet_role_provider.dart';
import 'package:el_race/ui/presentation/timesheet/foreman/fm1_foreman_dashboard.dart';
import 'package:el_race/ui/presentation/timesheet/pm/pm_timesheet_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Timesheet home card — labor hours capture (FM) or review (PM).
class TimesheetModuleHomeScreen extends ConsumerWidget {
  const TimesheetModuleHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolution = ref.watch(tmRoleResolutionProvider);
    if (resolution.role == TimesheetEffectiveRole.pm) {
      return const PmTimesheetHomeScreen();
    }
    return const Fm1ForemanDashboard();
  }
}
