import 'timesheet_model_parsers.dart';

class Task {
  const Task({
    required this.id,
    required this.projectId,
    required this.name,
    required this.description,
    required this.plannedStart,
    required this.plannedEnd,
    required this.status,
    required this.percentComplete,
    required this.assignedForemanId,
    required this.workerIds,
    this.odooAssigneeUserId,
  });

  final String id;
  final String projectId;
  final String name;
  final String description;
  final DateTime? plannedStart;
  final DateTime? plannedEnd;
  final String status;
  final double percentComplete;
  final String assignedForemanId;
  final List<String> workerIds;
  /// Odoo `project.task.user_id` — foreman assignment for this task.
  final int? odooAssigneeUserId;

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: tmStringFromJson(json['id']),
      projectId: tmStringFromJson(json['project_id']),
      name: tmStringFromJson(json['name']),
      description: tmStringFromJson(json['description']),
      plannedStart: tmDateTimeFromJson(json['planned_start']),
      plannedEnd: tmDateTimeFromJson(json['planned_end']),
      status: tmStringFromJson(json['status']),
      percentComplete: tmDoubleFromJson(json['percent_complete']),
      assignedForemanId: tmStringFromJson(json['assigned_foreman_id']),
      workerIds: tmStringListFromJson(json['worker_ids']),
      odooAssigneeUserId: tmIntOrNullFromJson(
        json['user_id'] ?? json['assign_to_id'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'name': name,
      'description': description,
      'planned_start': tmDateTimeToJson(plannedStart),
      'planned_end': tmDateTimeToJson(plannedEnd),
      'status': status,
      'percent_complete': percentComplete,
      'assigned_foreman_id': assignedForemanId,
      'worker_ids': workerIds,
      if (odooAssigneeUserId != null) 'user_id': odooAssigneeUserId,
    };
  }
}
