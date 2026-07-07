import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/core/timesheet/providers/timesheet_hr_scope_provider.dart';
import 'package:el_race/core/timesheet/providers/timesheet_role_provider.dart';
import 'package:el_race/core/timesheet/services/capture_queue_service.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_route_args.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TimesheetWorkerDayStatus {
  notCaptured,
  checkedIn,
  checkedOut,
  flagged,
}

class TimesheetTaskAttendanceSnapshot {
  const TimesheetTaskAttendanceSnapshot({
    required this.capturedToday,
    required this.totalWorkers,
    required this.statusByWorkerId,
    required this.checkInCount,
    required this.checkOutCount,
  });

  final int capturedToday;
  final int totalWorkers;
  final Map<String, TimesheetWorkerDayStatus> statusByWorkerId;
  final int checkInCount;
  final int checkOutCount;
}

final timesheetTaskAttendanceProvider = FutureProvider.autoDispose
    .family<TimesheetTaskAttendanceSnapshot, TimesheetTaskArgs>((ref, args) async {
  final resolution = ref.watch(tmRoleResolutionProvider);
  final scope = await ref.watch(timesheetHrScopeProvider.future);
  final allowedLabor = resolution.canSubmitTimesheet && scope.hasLaborScope
      ? scope.laborEmployeeIds
      : null;

  final workers =
      await ref.watch(timesheetTaskWorkersProvider(args.taskId).future);
  final today = DateTime.now();
  final attendanceEnv = await ref.watch(timesheetApiClientProvider).getTaskAttendance(
        projectId: args.projectId,
        taskId: args.taskId,
        date: today,
        allowedLaborEmployeeIds: allowedLabor,
      );
  final attendance = attendanceEnv.data ?? const [];
  final pendingDrafts = await TimesheetCaptureQueueService().pending();

  final statusByWorkerId = <String, TimesheetWorkerDayStatus>{};
  for (final worker in workers) {
    statusByWorkerId[worker.id] = TimesheetWorkerDayStatus.notCaptured;
  }

  for (final record in attendance) {
    if (record.taskId != args.taskId) continue;
    final workerId = record.workerId;
    if (workerId.isEmpty) continue;
    if (record.manualOverride || record.outsideGeofence) {
      statusByWorkerId[workerId] = TimesheetWorkerDayStatus.flagged;
      continue;
    }
    if (record.event == 'checkOut') {
      statusByWorkerId[workerId] = TimesheetWorkerDayStatus.checkedOut;
    } else {
      statusByWorkerId[workerId] = TimesheetWorkerDayStatus.checkedIn;
    }
  }

  for (final draft in pendingDrafts) {
    if (draft.taskId != args.taskId || draft.workerId == null) continue;
    statusByWorkerId[draft.workerId!] = TimesheetWorkerDayStatus.flagged;
  }

  var checkIn = 0;
  var checkOut = 0;
  for (final status in statusByWorkerId.values) {
    if (status == TimesheetWorkerDayStatus.checkedIn) checkIn += 1;
    if (status == TimesheetWorkerDayStatus.checkedOut) checkOut += 1;
  }

  final captured = statusByWorkerId.values
      .where((s) => s != TimesheetWorkerDayStatus.notCaptured)
      .length;

  return TimesheetTaskAttendanceSnapshot(
    capturedToday: captured,
    totalWorkers: workers.length,
    statusByWorkerId: statusByWorkerId,
    checkInCount: checkIn,
    checkOutCount: checkOut,
  );
});
