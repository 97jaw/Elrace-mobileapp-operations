import 'package:el_race/core/timesheet/providers/timesheet_acting_session_provider.dart';
import 'package:el_race/core/timesheet/providers/timesheet_role_provider.dart';
import 'package:el_race/ui/presentation/timesheet/foreman/fm1_foreman_dashboard.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_role_restricted_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Timesheet home card — foreman-only labor hours capture.
///
/// PM / HR review flows live under the Site Management module. A non-foreman
/// opening Timesheet sees the role-restricted notice, from where they may
/// start a read-only acting session as one of their own foremen.
class TimesheetModuleHomeScreen extends ConsumerWidget {
  const TimesheetModuleHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Raw resolution on purpose: only a genuine foreman login reaches the
    // dashboard directly, and only a non-foreman may start an acting session.
    final resolution = ref.watch(tmRoleResolutionProvider);
    if (resolution.role == TimesheetEffectiveRole.foreman) {
      return const Fm1ForemanDashboard();
    }
    if (ref.watch(tmActingSessionProvider) != null) {
      return const Fm1ForemanDashboard();
    }
    return TimesheetRoleRestrictedScreen(roleLabel: resolution.role.label);
  }
}
