import 'package:el_race/ui/presentation/timesheet/site_management/sm_monitor_project_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Site Management home card — site operations (monitor project, reports,
/// teams, live, chat).
class SiteManagementModuleEntryScreen extends ConsumerWidget {
  const SiteManagementModuleEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SmMonitorProjectScreen();
  }
}
