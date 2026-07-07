import 'package:el_race/core/timesheet/providers/timesheet_role_provider.dart';
import 'package:el_race/ui/presentation/timesheet/foreman/fm_site_management_home_screen.dart';
import 'package:el_race/ui/presentation/timesheet/pm/pm1_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Site Management home card — site operations (reports, teams, live, chat).
class SiteManagementModuleEntryScreen extends ConsumerWidget {
  const SiteManagementModuleEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolution = ref.watch(tmRoleResolutionProvider);
    if (resolution.role == TimesheetEffectiveRole.pm) {
      return const Pm1Dashboard(siteManagementMode: true);
    }
    return const FmSiteManagementHomeScreen();
  }
}
