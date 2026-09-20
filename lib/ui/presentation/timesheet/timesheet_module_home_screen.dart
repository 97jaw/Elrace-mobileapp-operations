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
///
/// Leaving this route (back to app Home) always clears any acting session so
/// the next open starts from the restricted screen again.
class TimesheetModuleHomeScreen extends ConsumerWidget {
  const TimesheetModuleHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Raw resolution on purpose: only a genuine foreman login reaches the
    // dashboard directly, and only a non-foreman may start an acting session.
    final resolution = ref.watch(tmRoleResolutionProvider);
    final acting = ref.watch(tmActingSessionProvider);

    Widget body;
    if (resolution.role == TimesheetEffectiveRole.foreman || acting != null) {
      body = const Fm1ForemanDashboard();
    } else {
      body = TimesheetRoleRestrictedScreen(roleLabel: resolution.role.label);
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        // Back to app Home closes the Timesheet feature entirely — including
        // any "Access with Foreman" session. Real foremen are unaffected
        // (acting is always null for them).
        ref.read(tmActingSessionProvider.notifier).exit();
      },
      child: body,
    );
  }
}
