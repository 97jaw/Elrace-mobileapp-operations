import 'package:el_race/core/timesheet/models/timesheet_models.dart';

/// Site Management defaults (Phase 1).
abstract final class TimesheetDefaults {
  /// Default Odoo task name for foreman/PM capture until task planning is live.
  static const String maintenanceTaskName = 'Maintenance and development';

  static const String maintenanceTaskLabel =
      'Task: Maintenance and development';

  static const List<String> maintenanceTaskAliases = [
    'maintenance',
    'maintainance',
    'maintainence',
    'development',
  ];

  /// True when [id] is a numeric Odoo primary key (safe for task_id APIs).
  static bool isOdooIntegerId(String? id) {
    if (id == null || id.isEmpty) return false;
    return int.tryParse(id) != null;
  }

  static bool isMaintenanceTaskName(String name) {
    final normalized = name.trim().toLowerCase();
    return maintenanceTaskAliases.any(normalized.contains);
  }

  static String _normalizePersonName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Foreman assignment task (`project.task` where `user_id` = logged-in FM).
  static Task? tryResolveForemanTask({
    required String projectId,
    required List<Task> projectTasks,
    int? odooUserId,
    String? displayName,
  }) {
    final candidates = projectTasks
        .where(
          (t) =>
              isOdooIntegerId(t.id) &&
              t.projectId == projectId &&
              !isMaintenanceTaskName(t.name),
        )
        .toList();
    if (candidates.isEmpty) return null;

    if (odooUserId != null) {
      final byUser =
          candidates.where((t) => t.odooAssigneeUserId == odooUserId).toList();
      if (byUser.length == 1) return byUser.first;
      if (byUser.isNotEmpty) return byUser.first;
    }

    if (displayName != null && displayName.trim().isNotEmpty) {
      final norm = _normalizePersonName(displayName);
      for (final task in candidates) {
        if (_normalizePersonName(task.name) == norm) return task;
      }
    }

    if (candidates.length == 1) return candidates.first;
    return null;
  }

  /// Resolves the Maintenance task for a project from live task rows only.
  /// Never synthesizes placeholder ids — those break Odoo SQL (`maintenance_15153`).
  static Task? tryResolveMaintenanceTask({
    required String projectId,
    required List<Task> projectTasks,
  }) {
    for (final task in projectTasks) {
      if (!isOdooIntegerId(task.id)) continue;
      if (isMaintenanceTaskName(task.name)) {
        return task;
      }
    }
    return null;
  }

  /// @deprecated Use [tryResolveMaintenanceTask]. Kept for callers that expect a Task.
  static Task resolveMaintenanceTask({
    required String projectId,
    required List<Task> projectTasks,
  }) {
    return tryResolveMaintenanceTask(
          projectId: projectId,
          projectTasks: projectTasks,
        ) ??
        Task(
          id: '',
          projectId: projectId,
          name: maintenanceTaskName,
          description: 'Configure a Maintenance task on this project in Odoo',
          plannedStart: null,
          plannedEnd: null,
          status: 'IN_PROGRESS',
          percentComplete: 0,
          assignedForemanId: '',
          workerIds: const [],
        );
  }

  /// Value for `task_id` on submit when no real Odoo task exists.
  static Object submitTaskIdParam(String taskId) {
    if (isOdooIntegerId(taskId)) {
      return int.parse(taskId);
    }
    return false;
  }
}
