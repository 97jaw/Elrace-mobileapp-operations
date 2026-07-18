import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/core/timesheet/routing/timesheet_route_names.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_route_args.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Foreman bottom-nav Tasks hub — lists today's tasks across projects.
class FmTasksHubScreen extends ConsumerWidget {
  const FmTasksHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(timesheetProjectsProvider);

    return TmScaffold(
      glassTitle: "Today's tasks",
      body: projectsAsync.when(
        loading: () => const TimesheetLoadingState(
          style: TimesheetLoadingStyle.list,
          itemCount: 6,
        ),
        error: (_, __) => TimesheetErrorState(
          message: 'Could not load tasks',
          onRetry: () => ref.invalidate(timesheetProjectsProvider),
        ),
        data: (projects) {
          if (projects.isEmpty) {
            return const TimesheetEmptyState(message: 'No projects assigned');
          }
          return ListView.separated(
            itemCount: projects.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: TimesheetModuleLayout.sectionGap),
            itemBuilder: (context, index) {
              final project = projects[index];
              final tasksAsync =
                  ref.watch(timesheetProjectTasksProvider(project.id));
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TmSectionHeader(title: project.name),
                  const SizedBox(height: TimesheetModuleLayout.cardSpacing),
                  tasksAsync.when(
                    loading: () => const TimesheetLoadingState(
          style: TimesheetLoadingStyle.list,
          itemCount: 6,
        ),
                    error: (_, __) => const TimesheetErrorState(
                      message: 'Could not load project tasks',
                    ),
                    data: (tasks) {
                      if (tasks.isEmpty) {
                        return Text(
                          'No tasks',
                          style: TimesheetModuleTypography.caption(),
                        );
                      }
                      return Column(
                        children: [
                          for (final task in tasks) ...[
                            TmTaskRow(
                              title: task.name,
                              subtitle: task.status,
                              icon: PhosphorIcons.clipboardText(),
                              onTap: () => Navigator.of(context).pushNamed(
                                TimesheetRouteNames.taskDetail,
                                arguments: TimesheetTaskArgs(
                                  projectId: project.id,
                                  taskId: task.id,
                                  taskName: task.name,
                                ),
                              ),
                            ),
                            const SizedBox(
                              height: TimesheetModuleLayout.cardSpacing,
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
