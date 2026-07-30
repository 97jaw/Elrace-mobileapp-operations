import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:el_race/ui/presentation/tasks/data/assignable_user_model.dart';
import 'package:el_race/ui/presentation/tasks/data/task_model.dart';
import 'package:el_race/ui/presentation/tasks/data/tasks_api_service.dart';
import 'package:el_race/ui/presentation/tasks/data/tasks_repository.dart';
import 'package:el_race/data/services/assignment_push_service.dart';
import 'package:el_race/data/services/task_notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:el_race/core/utils/shared_pref.dart';

enum TasksStatus { initial, loading, loaded, empty, error }

class TasksProvider extends ChangeNotifier {
  final TasksRepository _repository;

  TasksStatus status = TasksStatus.initial;
  List<TaskModel> tasks = const [];
  String? errorMessage;

  List<AssignableUser> assignableUsers = const [];
  bool isLoadingUsers = false;
  bool usersLoaded = false;
  bool isCreating = false;
  final Set<int> completingTaskIds = {};
  final Set<int> linkingTaskIds = {};
  final Set<int> updatingTaskIds = {};
  final Set<int> deletingTaskIds = {};

  TasksProvider(this._repository);

  /// Priority then newest-first (matches productivity Tickets spec).
  static List<TaskModel> _sortTasks(List<TaskModel> items) {
    int priorityRank(String? p) {
      switch (p) {
        case '1':
          return 0;
        case '2':
          return 1;
        case '3':
          return 2;
        default:
          return 3;
      }
    }

    final sorted = List<TaskModel>.from(items);
    sorted.sort((a, b) {
      final byPriority = priorityRank(a.priority).compareTo(priorityRank(b.priority));
      if (byPriority != 0) return byPriority;
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return sorted;
  }

  /// Open helpdesk tickets for the home Tickets widget (same data as [TasksScreen]).
  TicketsWidgetRecord get ticketsWidgetRecord {
    final openTickets = tasks.where((task) => !task.isCompleted).toList();
    final highPriority = openTickets
        .where((task) => task.priority == '1')
        .length;
    final totalOpen = openTickets.length;

    String trendMessage;
    String trendColor;
    if (totalOpen == 0) {
      trendMessage = '';
      trendColor = 'neutral';
    } else if (highPriority == 0) {
      trendMessage = 'All on track';
      trendColor = 'green';
    } else if (highPriority == 1) {
      trendMessage = '1 high priority';
      trendColor = 'red';
    } else {
      trendMessage = '$highPriority high priority';
      trendColor = 'red';
    }

    return TicketsWidgetRecord(
      totalOpen: totalOpen,
      highPriorityCount: highPriority,
      trendMessage: trendMessage,
      trendColor: trendColor,
    );
  }

  Future<void> loadTasks({bool forceRefresh = false}) async {
    if (status == TasksStatus.loading) return;
    status = TasksStatus.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _repository.getUserTasks();
      tasks = _sortTasks(response);
      status = tasks.isEmpty ? TasksStatus.empty : TasksStatus.loaded;
    } on TasksUnauthorizedException {
      errorMessage = 'Your session has expired. Please sign in again.';
      status = TasksStatus.error;
    } on TasksApiException catch (e) {
      errorMessage = e.message;
      status = TasksStatus.error;
    } catch (e) {
      errorMessage = 'Unexpected error. Please try again.';
      status = TasksStatus.error;
    }

    notifyListeners();
  }

  Future<void> refreshTasks() async {
    await loadTasks(forceRefresh: true);
  }

  Future<void> loadAssignableUsers() async {
    if (usersLoaded || isLoadingUsers) return;
    errorMessage = null;
    isLoadingUsers = true;
    notifyListeners();
    try {
      assignableUsers = await _repository.getAssignableUsers();
      usersLoaded = true;
    } on TasksApiException catch (e) {
      errorMessage = e.message;
    } finally {
      isLoadingUsers = false;
      notifyListeners();
    }
  }

  Future<TaskModel?> createTask({
    required String name,
    String? description,
    String? priority,
    int? userId,
    String? attachmentBase64,
    String? attachmentFilename,
    String? comment,
  }) async {
    if (isCreating) return null;
    errorMessage = null;
    isCreating = true;
    notifyListeners();
    try {
      final created = await _repository.createTask(
        name: name,
        description: description,
        priority: priority,
        userId: userId,
        attachmentBase64: attachmentBase64,
        attachmentFilename: attachmentFilename,
        comment: comment ?? description,
      );

      // Ensure task has a creation date and priority
      var taskWithData = created;
      if (created.createdAt == null) {
        taskWithData = taskWithData.copyWith(createdAt: DateTime.now());
      }
      if (created.priority == null && priority != null) {
        taskWithData = taskWithData.copyWith(priority: priority);
      }

      // Add the created task to the beginning of the list immediately
      tasks = _sortTasks([taskWithData, ...tasks]);
      status = TasksStatus.loaded;
      notifyListeners();

      // Notify assignee (FCM via Cloud Function). Local notif only if self-assign.
      try {
        await _notifyTicketAssignment(
          taskId: '${taskWithData.id ?? 0}',
          taskTitle: name,
          assigneeUserId: userId,
        );
      } catch (_) {}

      // Refresh from server after a longer delay to get project/team info
      await Future.delayed(const Duration(milliseconds: 1500));
      await loadTasks(forceRefresh: true);

      return taskWithData;
    } on TasksApiException catch (e) {
      errorMessage = e.message;
      return null;
    } finally {
      isCreating = false;
      notifyListeners();
    }
  }

  Future<TaskModel?> createTaskForReport({
    required String name,
    String? description,
    String? priority,
    int? userId,
    required String reportId,
    String? attachmentBase64,
    String? attachmentFilename,
    String? comment,
  }) async {
    if (isCreating) return null;
    errorMessage = null;
    isCreating = true;
    notifyListeners();

    try {
      // default assignee = current user if none provided
      var resolvedUserId = userId;
      if (resolvedUserId == null) {
        final login = SharedPref.getLoginDataOrNull();
        resolvedUserId = login?.result?.data?.uid;
      }

      var created = await _repository.createTask(
        name: name,
        description: description,
        priority: priority,
        userId: resolvedUserId,
        attachmentBase64: attachmentBase64,
        attachmentFilename: attachmentFilename,
        comment: comment ?? description,
      );

      if (created.createdAt == null) {
        created = created.copyWith(createdAt: DateTime.now());
      }
      if (created.priority == null && priority != null) {
        created = created.copyWith(priority: priority);
      }

      tasks = _sortTasks([created, ...tasks]);
      status = TasksStatus.loaded;
      notifyListeners();

      try {
        await _notifyTicketAssignment(
          taskId: '${created.id ?? 0}',
          taskTitle: name,
          assigneeUserId: resolvedUserId,
        );
        final login = SharedPref.getLoginDataOrNull()?.result?.data;
        await AssignmentPushService.instance.rememberTicketCreator(
          taskId: '${created.id ?? 0}',
          creatorOdooUserId: login?.uid,
          creatorFirebaseUid: login?.firebase_uid,
        );
      } catch (_) {}

      if (created.id != null && reportId.isNotEmpty) {
        await _repository.linkReportToTask(
          taskId: created.id!,
          reportId: reportId,
        );
      }

      await loadTasks(forceRefresh: true);
      return created;
    } on TasksApiException catch (e) {
      errorMessage = e.message;
      return null;
    } catch (e) {
      errorMessage = 'Failed to create task: $e';
      return null;
    } finally {
      isCreating = false;
      notifyListeners();
    }
  }

  Future<String?> completeTask(int taskId) async {
    errorMessage = null;
    completingTaskIds.add(taskId);
    notifyListeners();
    try {
      final message = await _repository.submitTask(taskId: taskId);

      // Find the task name before refreshing the list
      final taskName = tasks
              .where((t) => t.id == taskId)
              .map((t) => t.name)
              .firstOrNull ??
          'Task #$taskId';

      // Notify ticket creator (not the completer) via FCM when someone else submits.
      try {
        final login = SharedPref.getLoginDataOrNull()?.result?.data;
        final completedBy = login?.name ?? 'Someone';
        await AssignmentPushService.instance.enqueueTicketCompleted(
          taskId: '$taskId',
          taskTitle: taskName,
          completedBy: completedBy,
          completerOdooUserId: login?.uid,
          completerFirebaseUid: login?.firebase_uid,
        );
      } catch (_) {}

      await loadTasks(forceRefresh: true);
      return message;
    } on TasksApiException catch (e) {
      errorMessage = e.message;
      return null;
    } finally {
      completingTaskIds.remove(taskId);
      notifyListeners();
    }
  }

  Future<String?> linkReport({
    required int taskId,
    required String reportId,
  }) async {
    errorMessage = null;
    linkingTaskIds.add(taskId);
    notifyListeners();
    try {
      final message = await _repository.linkReportToTask(
        taskId: taskId,
        reportId: reportId,
      );

      // Refresh tasks to show the linked report
      await loadTasks(forceRefresh: true);

      return message;
    } on TasksApiException catch (e) {
      errorMessage = e.message;
      return null;
    } finally {
      linkingTaskIds.remove(taskId);
      notifyListeners();
    }
  }

  Future<String?> updateTask({
    required int taskId,
    String? name,
    String? description,
    String? priority,
  }) async {
    // Require at least one updatable field
    if ((name == null || name.trim().isEmpty) &&
        (description == null || description.trim().isEmpty) &&
        (priority == null || priority.trim().isEmpty)) {
      errorMessage = 'Please change a field before saving.';
      return null;
    }

    errorMessage = null;
    updatingTaskIds.add(taskId);
    notifyListeners();

    try {
      final message = await _repository.updateTask(
        taskId: taskId,
        name: name?.trim(),
        description: description?.trim(),
        priority: priority?.trim(),
      );

      // Refresh tasks to reflect server state
      await loadTasks(forceRefresh: true);

      return message;
    } on TasksApiException catch (e) {
      errorMessage = e.message;
      return null;
    } finally {
      updatingTaskIds.remove(taskId);
      notifyListeners();
    }
  }

  Future<String?> deleteTask(int taskId) async {
    errorMessage = null;
    deletingTaskIds.add(taskId);
    notifyListeners();

    try {
      final message = await _repository.deleteTask(taskId: taskId);

      // Remove locally immediately
      tasks = tasks.where((t) => t.id != taskId).toList();
      if (tasks.isEmpty) {
        status = TasksStatus.empty;
      }
      notifyListeners();

      // Refresh from server to stay in sync
      await loadTasks(forceRefresh: true);

      return message;
    } on TasksApiException catch (e) {
      errorMessage = e.message;
      return null;
    } finally {
      deletingTaskIds.remove(taskId);
      notifyListeners();
    }
  }

  /// Push to assignee via Cloud Function; local notif only for self-assign.
  Future<void> _notifyTicketAssignment({
    required String taskId,
    required String taskTitle,
    int? assigneeUserId,
  }) async {
    final login = SharedPref.getLoginDataOrNull()?.result?.data;
    final currentUserName = login?.name ?? '';
    final currentUid = login?.uid;

    final resolvedAssignee = assigneeUserId ?? currentUid;
    final isSelfAssign =
        resolvedAssignee == null || resolvedAssignee == currentUid;

    if (isSelfAssign) {
      // Self-assign: keep a quiet local reminder only.
      await TaskNotificationService().showNewTaskNotification(
        taskId: taskId,
        taskTitle: taskTitle,
        assignedBy: null,
        isFirebaseTask: false,
        category: TaskNotificationService.categoryTicket,
      );
      return;
    }

    await AssignmentPushService.instance.enqueue(
      taskId: taskId,
      taskTitle: taskTitle,
      assignedBy: currentUserName,
      assigneeOdooUserId: resolvedAssignee,
      isFirebaseTask: false,
      category: TaskNotificationService.categoryTicket,
    );
  }
}
