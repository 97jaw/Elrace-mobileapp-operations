import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class GanttListView extends ConsumerWidget {
  const GanttListView({
    super.key,
    required this.projectId,
  });

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(timesheetProjectTasksProvider(projectId));

    return TmScaffold(
      glassTitle: 'Gantt View',
      body: tasksAsync.when(
        loading: () => const TimesheetLoadingState(
          style: TimesheetLoadingStyle.list,
          itemCount: 6,
        ),
        error: (_, __) => const TimesheetErrorState(
          message: 'Could not load Gantt tasks',
        ),
        data: (tasks) => ListView.separated(
          itemCount: tasks.length,
          separatorBuilder: (_, __) => const SizedBox(
            height: TimesheetModuleLayout.cardSpacing,
          ),
          itemBuilder: (context, index) {
            final task = tasks[index];
            final offset = (index % 3) * 28.0;
            final widthFactor = (task.percentComplete / 100).clamp(0.18, 1.0);

            return Container(
              padding: const EdgeInsets.all(TimesheetModuleLayout.cardPadding),
              decoration: BoxDecoration(
                color: TimesheetModuleColors.surface,
                borderRadius: BorderRadius.circular(
                  TimesheetModuleLayout.cardRadiusMd,
                ),
                boxShadow: TimesheetModuleShadows.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        PhosphorIcons.calendarDots(),
                        color: TimesheetModuleColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          task.name,
                          style: TimesheetModuleTypography.cardTitle(),
                        ),
                      ),
                      Text(
                        '${task.percentComplete.toStringAsFixed(0)}%',
                        style: TimesheetModuleTypography.caption(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    height: 34,
                    decoration: BoxDecoration(
                      color: TimesheetModuleColors.navyTint,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: widthFactor,
                        child: Padding(
                          padding: EdgeInsets.only(left: offset),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: TimesheetModuleColors.primaryGradient,
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
