import 'package:el_race/core/theme/timesheet_attendance_status_colors.dart';
import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_models.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/core/timesheet/providers/timesheet_task_attendance_provider.dart';
import 'package:el_race/core/timesheet/routing/timesheet_route_names.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_route_args.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class Fm3TaskDetail extends ConsumerWidget {
  const Fm3TaskDetail({
    super.key,
    required this.projectId,
    required this.taskId,
  });

  final String projectId;
  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(timesheetTaskProvider(taskId));
    final workersAsync = ref.watch(timesheetTaskWorkersProvider(taskId));
    final attendanceAsync = ref.watch(
      timesheetTaskAttendanceProvider(
        TimesheetTaskArgs(projectId: projectId, taskId: taskId),
      ),
    );

    TimesheetCaptureArgs captureArgs(Task task, {Worker? worker}) {
      return TimesheetCaptureArgs(
        projectId: projectId,
        taskId: taskId,
        taskName: task.name,
        targetWorkerId: worker?.id,
        targetWorkerName: worker?.name,
        targetEmployeeOdooId: worker?.odooEmployeeId,
      );
    }

    return TmScaffold(
      glassTitle: 'Task detail',
      body: taskAsync.when(
        loading: () => const TimesheetLoadingState(
          style: TimesheetLoadingStyle.list,
          itemCount: 4,
        ),
        error: (_, __) =>
            const TimesheetErrorState(message: 'Could not load task'),
        data: (task) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.name, style: TimesheetModuleTypography.display()),
              const SizedBox(height: 6),
              Text(task.description, style: TimesheetModuleTypography.body()),
              const SizedBox(height: TimesheetModuleLayout.cardSpacing),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: TimesheetModuleColors.primaryTint,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${task.status} · ${task.percentComplete.toStringAsFixed(0)}%',
                  style: TimesheetModuleTypography.caption().copyWith(
                    color: TimesheetModuleColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: TimesheetModuleLayout.sectionGap),
              attendanceAsync.when(
                // Compact placeholder: workers section below already shows a
                // skeleton, no need to stack a second full-height one.
                loading: () => const TmSectionHeader(
                  title: 'Assigned workers',
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (snapshot) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TmSectionHeader(
                      title:
                          'Assigned workers (${snapshot.capturedToday}/${snapshot.totalWorkers} today)',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Today's attendance: ${snapshot.checkInCount} in / "
                      '${snapshot.checkOutCount} out',
                      style: TimesheetModuleTypography.caption(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: TimesheetModuleLayout.cardSpacing),
              workersAsync.when(
                loading: () => const TimesheetLoadingState(
                  style: TimesheetLoadingStyle.list,
                  itemCount: 2,
                ),
                error: (_, __) => const TimesheetErrorState(
                  message: 'Could not load assigned workers',
                ),
                data: (workers) {
                  final assigned = workers;
                  final snapshot = attendanceAsync.maybeWhen(
                    data: (value) => value,
                    orElse: () => null,
                  );
                  if (assigned.isEmpty) {
                    return const TimesheetEmptyState(
                      message: 'No workers assigned to this task',
                    );
                  }
                  return Column(
                    children: [
                      for (final worker in assigned) ...[
                        _WorkerRow(
                          worker: worker,
                          status: snapshot?.statusByWorkerId[worker.id] ??
                              TimesheetWorkerDayStatus.notCaptured,
                          onTap: () => Navigator.of(context).pushNamed(
                            TimesheetRouteNames.captureMode,
                            arguments: captureArgs(
                              task,
                              worker: worker,
                            ).copyWith(mode: 'individual'),
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
              const SizedBox(height: TimesheetModuleLayout.sectionGap),
              TmPrimaryButton(
                label: 'Take attendance',
                icon: PhosphorIcons.play(),
                onPressed: () => Navigator.of(context).pushNamed(
                  TimesheetRouteNames.projectDates,
                  arguments: TimesheetProjectArgs(
                    projectId: projectId,
                    projectName: task.name,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkerRow extends StatelessWidget {
  const _WorkerRow({
    required this.worker,
    required this.status,
    required this.onTap,
  });

  final Worker worker;
  final TimesheetWorkerDayStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dotColor = _colorsForStatus(status);
    return TmTaskRow(
      title: worker.name,
      subtitle: worker.trade,
      icon: PhosphorIcons.userCircle(),
      onTap: onTap,
      trailing: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: dotColor,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Color _colorsForStatus(TimesheetWorkerDayStatus status) {
    switch (status) {
      case TimesheetWorkerDayStatus.checkedIn:
        return TimesheetAttendanceStatusColors.checkedInFg;
      case TimesheetWorkerDayStatus.checkedOut:
        return TimesheetAttendanceStatusColors.checkedOutFg;
      case TimesheetWorkerDayStatus.flagged:
        return TimesheetAttendanceStatusColors.outsideGeofenceFg;
      case TimesheetWorkerDayStatus.notCaptured:
        return TimesheetAttendanceStatusColors.pendingSyncFg;
    }
  }
}
