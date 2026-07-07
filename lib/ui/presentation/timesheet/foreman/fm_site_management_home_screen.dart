import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_models.dart';
import 'package:el_race/core/timesheet/models/timesheet_team_member.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/core/timesheet/routing/timesheet_route_names.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_chat_launcher.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_route_args.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_dashboard_header.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_dashboard_projects_section.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_team_members_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// FM Site Management hub — projects, reports, teams, live map (no timesheet capture).
class FmSiteManagementHomeScreen extends ConsumerWidget {
  const FmSiteManagementHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(timesheetLoginProfileProvider);
    final bucketsAsync = ref.watch(timesheetProjectBucketsProvider);
    final projectsAsync = ref.watch(timesheetProjectsProvider);
    final laborsAsync = ref.watch(timesheetForemanLaborsProvider);

    final laborCount = laborsAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );

    return TmScaffold(
      padding: const EdgeInsets.symmetric(
        horizontal: TimesheetModuleLayout.screenPaddingH,
        vertical: 12,
      ),
      appBar: AppBar(
        title: Text('Site Management', style: TimesheetModuleTypography.h2()),
        backgroundColor: TimesheetModuleColors.surface,
        foregroundColor: TimesheetModuleColors.text,
        elevation: 0,
      ),
      bottomNavigationBar: TmBottomNavBar(
        dark: true,
        fabIcon: PhosphorIcons.chatCircleText(),
        items: [
          TmBottomNavItem(label: 'Home', icon: PhosphorIcons.house()),
          TmBottomNavItem(label: 'Projects', icon: PhosphorIcons.briefcase()),
        ],
        currentIndex: 0,
        onItemTap: (index) {
          if (index == 1) {
            Navigator.of(context).pushNamed(TimesheetRouteNames.projectPicker);
          }
        },
        onFabTap: () => TimesheetChatLauncher.open(context, ref),
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
          return projectsAsync.when(
            loading: () => const TimesheetLoadingState(
              style: TimesheetLoadingStyle.list,
              itemCount: 4,
            ),
            error: (_, __) => const TimesheetErrorState(
              message: 'Could not load active projects',
            ),
            data: (projects) {
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
                    Text(
                      'Site reports, teams, photos, and live map per project.',
                      style: TimesheetModuleTypography.caption(),
                    ),
                    const SizedBox(height: TimesheetModuleLayout.sectionGap),
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
                          TimesheetRouteNames.projectDetail,
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
