import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_models.dart';
import 'package:el_race/core/timesheet/models/timesheet_team_member.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/core/timesheet/routing/timesheet_route_names.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_route_args.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_dashboard_header.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_dashboard_projects_section.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_team_members_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class Fm1ForemanDashboard extends ConsumerWidget {
  const Fm1ForemanDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(timesheetLoginProfileProvider);
    final bucketsAsync = ref.watch(timesheetProjectBucketsProvider);
    final laborsAsync = ref.watch(timesheetForemanLaborsProvider);
    final pendingSyncAsync = ref.watch(timesheetPendingSyncCountProvider);

    final laborCount = laborsAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );

    return TmScaffold(
      padding: const EdgeInsets.symmetric(
        horizontal: TimesheetModuleLayout.screenPaddingH,
        vertical: 12,
      ),
      glassTitle: 'Timesheet',
      bottomNavigationBar: TmBottomNavBar(
        dark: true,
        fabIcon: PhosphorIcons.chatCircleText(),
        items: [
          TmBottomNavItem(label: 'Home', icon: PhosphorIcons.house()),
          TmBottomNavItem(label: 'Report', icon: PhosphorIcons.clipboardText()),
        ],
        currentIndex: 0,
        onItemTap: (index) {
          if (index == 1) {
            Navigator.of(context).pushNamed(
              TimesheetRouteNames.foremanTimesheetRecords,
            );
          }
        },
        onFabTap: () {},
      ),
      body: bucketsAsync.when(
        loading: () => const TimesheetLoadingState(
          style: TimesheetLoadingStyle.list,
          itemCount: 4,
        ),
        error: (_, __) => TimesheetErrorState(
          message: 'Could not load projects',
          onRetry: () => ref.invalidate(timesheetProjectBucketsProvider),
        ),
        data: (buckets) {
          // Derived directly from buckets — avoids a second skeleton flash
          // from the redundant timesheetProjectsProvider watch.
          final projects = buckets.inProgress;
          if (projects.isEmpty && buckets.completed.isEmpty) {
            return const TimesheetEmptyState(
              message: 'No projects assigned',
            );
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TmDashboardHeader(
                  key: ValueKey(
                    '${profile.fileId}|${profile.displayName}|${profile.imageUrl}',
                  ),
                  profile: profile,
                  counterLabel: 'Labors',
                  counterValue: laborCount,
                  onCounterTap: () => _showLabors(context, ref),
                ),
                const SizedBox(height: TimesheetModuleLayout.sectionGap),
                pendingSyncAsync.when(
                  data: (count) {
                    if (count == 0) return const SizedBox.shrink();
                    return Column(
                      children: [
                        TmTaskRow(
                          title: '$count pending sync',
                          subtitle: 'Captures waiting to upload',
                          icon: PhosphorIcons.cloudArrowUp(),
                          onTap: () => Navigator.of(context).pushNamed(
                            TimesheetRouteNames.syncQueue,
                          ),
                        ),
                        const SizedBox(
                          height: TimesheetModuleLayout.sectionGap,
                        ),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: TmStatTile(
                          value: '${buckets.completedTotal}',
                          label: 'Projects (completed)',
                          icon: PhosphorIcons.checkCircle(),
                          badgeTone: TmStatBadgeTone.completed,
                          onTap: () => _showCompletedProjects(
                            context,
                            buckets.completed,
                            buckets.completedTotal,
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: TimesheetModuleLayout.cardSpacing,
                      ),
                      Expanded(
                        child: TmStatTile(
                          value: '${buckets.inProgress.length}',
                          label: 'Projects (in progress)',
                          icon: PhosphorIcons.briefcase(),
                          badgeTone: TmStatBadgeTone.inProgress,
                          onTap: () => Navigator.of(context).pushNamed(
                            TimesheetRouteNames.projectPicker,
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: TimesheetModuleLayout.cardSpacing,
                      ),
                      Expanded(
                        child: TmStatTile(
                          value: '$laborCount',
                          label: 'Teams',
                          icon: PhosphorIcons.usersThree(),
                          badgeTone: TmStatBadgeTone.neutral,
                          onTap: () => _showLabors(context, ref),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: TimesheetModuleLayout.sectionGap),
                if (projects.isEmpty)
                  const TimesheetEmptyState(
                    message: 'No in-progress projects',
                  )
                else
                  TmDashboardProjectsSection(
                    projects: projects,
                    onProjectTap: (project) =>
                        Navigator.of(context).pushNamed(
                      TimesheetRouteNames.projectDates,
                      arguments: TimesheetProjectArgs(
                        projectId: project.id,
                        projectName: project.name,
                        clientImageUrl: project.clientImageUrl,
                        woRefNo: project.woRefNo,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showLabors(BuildContext context, WidgetRef ref) {
    final members = ref.read(timesheetForemanLaborsProvider).maybeWhen(
          data: (value) => value,
          orElse: () => <TimesheetTeamMember>[],
        );
    TmTeamMembersSheet.show(
      context,
      title: 'My labors',
      members: members,
    );
  }

  void _showCompletedProjects(
    BuildContext context,
    List<Project> completed,
    int completedTotal,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: TimesheetModuleColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Completed projects',
                  style: TimesheetModuleTypography.h2(),
                ),
                const SizedBox(height: 12),
                if (completed.isEmpty)
                  Text(
                    completedTotal > 0
                        ? '$completedTotal completed project(s)'
                        : 'None',
                    style: TimesheetModuleTypography.body(),
                  )
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final project in completed)
                          ListTile(
                            title: Text(project.name),
                            subtitle: Text(project.status),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
