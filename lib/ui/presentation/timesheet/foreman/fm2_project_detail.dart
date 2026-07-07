import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/core/timesheet/routing/timesheet_route_names.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/project_record_card.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_route_args.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_project_face_enroll_tab.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_project_site_reports_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class Fm2ProjectDetail extends ConsumerWidget {
  const Fm2ProjectDetail({
    super.key,
    required this.projectId,
  });

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(timesheetProjectProvider(projectId));
    final tasksAsync = ref.watch(timesheetProjectTasksProvider(projectId));

    return TmScaffold(
      padding: EdgeInsets.zero,
      appBar: AppBar(
        title: Text('Project Detail', style: TimesheetModuleTypography.h2()),
        backgroundColor: TimesheetModuleColors.surface,
        foregroundColor: TimesheetModuleColors.text,
        elevation: 0,
      ),
      bottomNavigationBar: _ProjectActionsBar(projectId: projectId),
      body: projectAsync.when(
        loading: () => const TimesheetLoadingState(
          style: TimesheetLoadingStyle.list,
          itemCount: 4,
        ),
        error: (_, __) => const TimesheetErrorState(
          message: 'Could not load project detail',
        ),
        data: (project) => DefaultTabController(
          length: 5,
          child: Column(
            children: [
              Container(
                color: TimesheetModuleColors.surface,
                child: const TabBar(
                  labelColor: TimesheetModuleColors.primary,
                  unselectedLabelColor: TimesheetModuleColors.mutedText,
                  indicatorColor: TimesheetModuleColors.primary,
                  isScrollable: true,
                  tabs: [
                    Tab(text: 'Overview'),
                    Tab(text: 'Tasks'),
                    Tab(text: 'Site Reports'),
                    Tab(text: 'Teams'),
                    Tab(text: 'Enroll'),
                  ],
                ),
              ),
              const SizedBox(height: TimesheetModuleLayout.cardSpacing),
              Expanded(
                child: TabBarView(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: TimesheetModuleLayout.screenPaddingH,
                        vertical: TimesheetModuleLayout.cardSpacing,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ProjectRecordCard(project: project),
                          const SizedBox(
                            height: TimesheetModuleLayout.sectionGap,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TmSecondaryButton(
                                label: 'Take Attendance',
                                icon: PhosphorIcons.camera(),
                                onPressed: () {
                                  Navigator.of(context).pushNamed(
                                    TimesheetRouteNames.projectDates,
                                    arguments: TimesheetProjectArgs(
                                      projectId: project.id,
                                      projectName: project.name,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(
                                height: TimesheetModuleLayout.cardSpacing,
                              ),
                              TmSecondaryButton(
                                label: 'Timesheet report',
                                icon: PhosphorIcons.fileText(),
                                onPressed: () =>
                                    Navigator.of(context).pushNamed(
                                  TimesheetRouteNames.foremanTimesheetRecords,
                                  arguments: TimesheetProjectArgs(
                                    projectId: project.id,
                                    projectName: project.name,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _TasksTab(projectId: project.id, tasksAsync: tasksAsync),
                    TmProjectSiteReportsTab(
                      projectId: project.id,
                      projectName: project.name,
                    ),
                    _TeamsTab(projectId: project.id),
                    TmProjectFaceEnrollTab(
                      projectId: project.id,
                      projectName: project.name,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectActionsBar extends ConsumerWidget {
  const _ProjectActionsBar({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectName = ref
        .watch(timesheetProjectProvider(projectId))
        .maybeWhen(data: (p) => p.name, orElse: () => null);
    final args = TimesheetProjectArgs(
      projectId: projectId,
      projectName: projectName,
    );
    return TmBottomNavBar(
      dark: true,
      fabIcon: PhosphorIcons.chatCircleText(),
      items: [
        TmBottomNavItem(label: 'Photos', icon: PhosphorIcons.images()),
        TmBottomNavItem(
          label: 'Report',
          icon: PhosphorIcons.clipboardText(),
        ),
        TmBottomNavItem(
            label: 'Gantt', icon: PhosphorIcons.chartBarHorizontal()),
        TmBottomNavItem(label: 'Live', icon: PhosphorIcons.mapTrifold()),
      ],
      currentIndex: -1,
      onItemTap: (index) {
        final routes = [
          TimesheetRouteNames.sitePhotos,
          TimesheetRouteNames.foremanTimesheetRecords,
          TimesheetRouteNames.gantt,
          TimesheetRouteNames.liveMap,
        ];
        Navigator.of(context).pushNamed(routes[index], arguments: args);
      },
      onFabTap: () => Navigator.of(context).pushNamed(
        TimesheetRouteNames.projectChat,
        arguments: args,
      ),
    );
  }
}

class _TasksTab extends StatelessWidget {
  const _TasksTab({
    required this.projectId,
    required this.tasksAsync,
  });

  final String projectId;
  final AsyncValue<dynamic> tasksAsync;

  @override
  Widget build(BuildContext context) {
    return tasksAsync.when(
      loading: () => const TimesheetLoadingState(
        style: TimesheetLoadingStyle.list,
        itemCount: 5,
      ),
      error: (_, __) =>
          const TimesheetErrorState(message: 'Could not load tasks'),
      data: (tasks) {
        if (tasks.isEmpty) {
          return const TimesheetEmptyState(
              message: 'No tasks for this project');
        }
        return ListView.separated(
          itemCount: tasks.length,
          separatorBuilder: (_, __) => const SizedBox(
            height: TimesheetModuleLayout.cardSpacing,
          ),
          itemBuilder: (context, index) {
            final task = tasks[index];
            return TmTaskRow(
              title: task.name,
              subtitle:
                  '${task.status} - ${task.percentComplete.toStringAsFixed(0)}%',
              icon: PhosphorIcons.clipboardText(),
              trailing: TmAvatarStack(labels: task.workerIds),
              onTap: () => Navigator.of(context).pushNamed(
                TimesheetRouteNames.taskDetail,
                arguments: TimesheetTaskArgs(
                  projectId: projectId,
                  taskId: task.id,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TeamsTab extends StatelessWidget {
  const _TeamsTab({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: TimesheetModuleLayout.screenPaddingH,
        vertical: TimesheetModuleLayout.cardSpacing,
      ),
      children: [
        TmTaskRow(
          title: 'Foreman Team',
          subtitle: 'Live location and attendance owner',
          icon: PhosphorIcons.hardHat(),
          trailing: const TmAvatarStack(labels: ['FM', 'A1', 'A2']),
          onTap: () => Navigator.of(context).pushNamed(
            TimesheetRouteNames.liveMap,
            arguments: TimesheetProjectArgs(projectId: projectId),
          ),
        ),
        const SizedBox(height: TimesheetModuleLayout.cardSpacing),
        TmTaskRow(
          title: 'Face enrollment',
          subtitle: 'Enroll labor photos for timesheet capture',
          icon: PhosphorIcons.userFocus(),
          onTap: () => Navigator.of(context).pushNamed(
            TimesheetRouteNames.faceEnrollEntry,
            arguments: TimesheetFaceEnrollArgs(projectId: projectId),
          ),
        ),
        const SizedBox(height: TimesheetModuleLayout.cardSpacing),
        TmTaskRow(
          title: 'Assigned Workers',
          subtitle: 'Open task detail to review assignment',
          icon: PhosphorIcons.usersThree(),
          trailing: const TmAvatarStack(labels: ['12', '8', '4']),
        ),
      ],
    );
  }
}
