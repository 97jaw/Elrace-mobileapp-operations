import 'package:dio/dio.dart';
import 'package:el_race/core/timesheet/models/timesheet_models.dart';
import 'package:el_race/core/timesheet/network/timesheet_api_client.dart';
import 'package:el_race/core/timesheet/network/timesheet_functions_client.dart';
import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/timesheet/providers/timesheet_hr_scope_provider.dart';
import 'package:el_race/core/timesheet/providers/timesheet_role_provider.dart';
import 'package:el_race/core/timesheet/timesheet_defaults.dart';
import 'package:el_race/core/timesheet/services/capture_queue_service.dart';
import 'package:el_race/core/timesheet/services/timesheet_offline_queue_service.dart';
import 'package:el_race/core/timesheet/models/timesheet_project_status.dart';
import 'package:el_race/core/timesheet/models/timesheet_team_member.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/core/site_management/face_recognition/face_recognition_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:el_race/core/site_management/face_recognition/face_recognition_provider.dart';

final timesheetDioProvider = Provider<Dio>((ref) => Dio());

final timesheetApiClientProvider = Provider<TimesheetApiClient>((ref) {
  ref.watch(loginSessionRevisionProvider);
  return TimesheetApiClient(
    dio: ref.watch(timesheetDioProvider),
    useMockData: false,
    useMockSubmit: false,
    fallbackToMockOnError: true,
  );
});

final timesheetFunctionsClientProvider =
    Provider<TimesheetFunctionsClient>((ref) {
  return TimesheetFunctionsClient();
});

final timesheetPendingSyncCountProvider = FutureProvider<int>((ref) async {
  final captureCount = await TimesheetCaptureQueueService().pendingCount();
  final extrasCount = await TimesheetOfflineQueueService().pendingCount();
  return captureCount + extrasCount;
});

final timesheetMaintenanceTaskProvider = FutureProvider.autoDispose
    .family<Task, String>((ref, projectId) async {
  final profile = ref.watch(timesheetLoginProfileProvider);
  final env = await ref.watch(timesheetApiClientProvider).getTimesheetTaskForProject(
        projectId,
        displayName: profile.displayName,
      );
  final task = env.data;
  if (task == null || !TimesheetDefaults.isOdooIntegerId(task.id)) {
    throw Exception(env.error ?? 'Foreman or maintenance task not found');
  }
  return task;
});

final timesheetTaskDayCountsProvider = FutureProvider.autoDispose
    .family<List<TimesheetDayCountRow>, TimesheetTaskDayCountsQuery>(
        (ref, query) async {
  final env = await ref.watch(timesheetApiClientProvider).getTaskDayCounts(
        taskId: query.taskId,
        startDate: query.startDate,
        endDate: query.endDate,
      );
  return env.data ?? const [];
});

class TimesheetTaskDayCountsQuery {
  const TimesheetTaskDayCountsQuery({
    required this.taskId,
    required this.startDate,
    required this.endDate,
  });

  final String taskId;
  final DateTime startDate;
  final DateTime endDate;

  @override
  bool operator ==(Object other) {
    return other is TimesheetTaskDayCountsQuery &&
        other.taskId == taskId &&
        other.startDate == startDate &&
        other.endDate == endDate;
  }

  @override
  int get hashCode => Object.hash(taskId, startDate, endDate);
}

final timesheetProjectProvider =
    FutureProvider.autoDispose.family<Project, String>((ref, projectId) async {
  final env = await ref.watch(timesheetApiClientProvider).getProject(projectId);
  final project = env.data;
  if (project == null) throw Exception(env.error ?? 'Project not found');
  return project;
});

final timesheetProjectTasksProvider = FutureProvider.autoDispose
    .family<List<Task>, String>((ref, projectId) async {
  final env = await ref.watch(timesheetApiClientProvider).getProjectTasks(
        projectId: projectId,
      );
  return env.data ?? const [];
});

final timesheetTaskProvider =
    FutureProvider.autoDispose.family<Task, String>((ref, taskId) async {
  final env = await ref.watch(timesheetApiClientProvider).getTask(taskId);
  final task = env.data;
  if (task == null) throw Exception(env.error ?? 'Task not found');
  return task;
});

final timesheetTaskWorkersProvider = FutureProvider.autoDispose
    .family<List<Worker>, String>((ref, taskId) async {
  final resolution = ref.watch(tmRoleResolutionProvider);
  final scope = await ref.watch(timesheetHrScopeProvider.future);
  final allowed = resolution.canSubmitTimesheet && scope.hasLaborScope
      ? scope.laborEmployeeIds
      : null;
  final env = await ref.watch(timesheetApiClientProvider).getTaskWorkers(
        taskId,
        allowedLaborEmployeeIds: allowed,
      );
  return env.data ?? const [];
});

final timesheetAttendanceProvider = FutureProvider.autoDispose
    .family<List<AttendanceRecord>, TimesheetAttendanceQuery>(
        (ref, query) async {
  final resolution = ref.watch(tmRoleResolutionProvider);
  Set<int>? allowed;
  if (resolution.canReviewTimesheetReports) {
    allowed = await ref.watch(
      timesheetPmProjectLaborIdsProvider(query.projectId).future,
    );
  }
  final env = await ref.watch(timesheetApiClientProvider).getAttendance(
        projectId: query.projectId,
        date: query.date,
        allowedLaborEmployeeIds: allowed,
      );
  return env.data ?? const [];
});

/// Project staff (`staff_list_ids` + supervisors) for chat / pickers.
final timesheetProjectStaffProvider =
    FutureProvider.family<List<TimesheetTeamMember>, String>((ref, projectId) async {
  if (projectId.trim().isEmpty) return const [];
  return ref.watch(timesheetApiClientProvider).fetchProjectStaff(projectId);
});

/// PM read-only: submitted timesheet lines for foremen's labors on a project.
final timesheetPmSubmittedRowsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, TimesheetAttendanceQuery>(
        (ref, query) async {
  final allowed = await ref.watch(
    timesheetPmProjectLaborIdsProvider(query.projectId).future,
  );
  return ref.watch(timesheetApiClientProvider).fetchProjectTimesheetRows(
        projectId: query.projectId,
        date: query.date,
        allowedLaborEmployeeIds: allowed,
      );
});

class TimesheetAttendanceQuery {
  const TimesheetAttendanceQuery({
    required this.projectId,
    required this.date,
  });

  final String projectId;
  final DateTime date;

  @override
  bool operator ==(Object other) {
    return other is TimesheetAttendanceQuery &&
        other.projectId == projectId &&
        other.date == date;
  }

  @override
  int get hashCode => Object.hash(projectId, date);
}

// ---------------------------------------------------------------------------
// Dashboard (FM / PM home)
// ---------------------------------------------------------------------------

class TimesheetLoginProfile {
  const TimesheetLoginProfile({
    required this.displayName,
    required this.fileId,
    this.imageUrl,
  });

  final String displayName;
  final String fileId;
  final String? imageUrl;
}

class TimesheetProjectBuckets {
  const TimesheetProjectBuckets({
    required this.inProgress,
    required this.completed,
    this.completedCount,
  });

  final List<Project> inProgress;
  final List<Project> completed;
  final int? completedCount;

  int get completedTotal => completedCount ?? completed.length;
}

final timesheetLoginProfileProvider = Provider<TimesheetLoginProfile>((ref) {
  ref.watch(loginSessionRevisionProvider);
  final data = SharedPref.getLoginDataOrNull()?.result?.data;
  final name = (data?.emp_name?.trim().isNotEmpty == true)
      ? data!.emp_name!.trim()
      : (data?.name?.trim().isNotEmpty == true)
          ? data!.name!.trim()
          : 'User';
  final fileId = (data?.emp_profile_id?.trim().isNotEmpty == true)
      ? data!.emp_profile_id!.trim()
      : (data?.emp_id?.trim().isNotEmpty == true)
          ? data!.emp_id!.trim()
          : (data?.employee_id?.toString() ?? '');
  return TimesheetLoginProfile(
    displayName: name,
    fileId: fileId,
    imageUrl: data?.image_url,
  );
});

final timesheetProjectBucketsProvider =
    FutureProvider<TimesheetProjectBuckets>((ref) async {
  final resolution = ref.watch(tmRoleResolutionProvider);
  final role = resolution.role == TimesheetEffectiveRole.pm ? 'pm' : 'foreman';
  final client = ref.watch(timesheetApiClientProvider);
  final env = await client.getProjects(
    role: role,
    hrWideScope: resolution.hrWideScope,
    status: 'in_progress',
  );
  final all = env.data ?? const <Project>[];
  final inProgress = <Project>[];
  final completed = <Project>[];
  for (final project in all) {
    if (TimesheetProjectStatus.isInProgress(project.status)) {
      inProgress.add(project);
    } else if (TimesheetProjectStatus.isCompleted(project.status)) {
      completed.add(project);
    }
  }
  final listed = inProgress.isNotEmpty ? inProgress : all;
  return TimesheetProjectBuckets(
    inProgress: listed,
    completed: completed,
    completedCount: client.siteCompletedProjectCount,
  );
});

/// In-progress projects only (supervisor / PM staff access applied in API).
final timesheetProjectsProvider = FutureProvider<List<Project>>((ref) async {
  final buckets = await ref.watch(timesheetProjectBucketsProvider.future);
  return buckets.inProgress;
});

final timesheetForemanLaborsProvider =
    FutureProvider<List<TimesheetTeamMember>>((ref) async {
  final scope = await ref.watch(timesheetHrScopeProvider.future);
  if (scope.laborMembers.isNotEmpty) {
    return List<TimesheetTeamMember>.from(scope.laborMembers)
      ..sort((a, b) => a.name.compareTo(b.name));
  }
  if (scope.laborEmployeeIds.isEmpty) return const [];
  final roster = await ref.watch(timesheetApiClientProvider).fetchEmployeeRoster();
  final members = <TimesheetTeamMember>[];
  for (final id in scope.laborEmployeeIds) {
    TimesheetOdooEmployee? match;
    for (final employee in roster) {
      if (employee.employeeId == id) {
        match = employee;
        break;
      }
    }
    if (match != null) {
      members.add(TimesheetTeamMember.fromEmployee(match));
    }
  }
  members.sort((a, b) => a.name.compareTo(b.name));
  return members;
});

final timesheetPmForemenProvider =
    FutureProvider<List<TimesheetTeamMember>>((ref) async {
  final scope = await ref.watch(timesheetHrScopeProvider.future);
  if (scope.foremanMembers.isNotEmpty) {
    return List<TimesheetTeamMember>.from(scope.foremanMembers)
      ..sort((a, b) => a.name.compareTo(b.name));
  }
  if (scope.foremanEmployeeIds.isEmpty) return const [];
  final roster = await ref.watch(timesheetApiClientProvider).fetchEmployeeRoster();
  final members = <TimesheetTeamMember>[];
  for (final id in scope.foremanEmployeeIds) {
    TimesheetOdooEmployee? match;
    for (final employee in roster) {
      if (employee.employeeId == id) {
        match = employee;
        break;
      }
    }
    if (match != null) {
      members.add(TimesheetTeamMember.fromEmployee(match));
    }
  }
  members.sort((a, b) => a.name.compareTo(b.name));
  return members;
});
