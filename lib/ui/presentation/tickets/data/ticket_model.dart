import 'package:cloud_firestore/cloud_firestore.dart';

enum TicketPriority { high, medium, low }

enum TicketStatus { open, inProgress, resolved, closed }

extension TicketPriorityX on TicketPriority {
  String get firestoreValue {
    switch (this) {
      case TicketPriority.high:
        return 'high';
      case TicketPriority.medium:
        return 'medium';
      case TicketPriority.low:
        return 'low';
    }
  }

  String get label {
    switch (this) {
      case TicketPriority.high:
        return 'High';
      case TicketPriority.medium:
        return 'Medium';
      case TicketPriority.low:
        return 'Low';
    }
  }

  static TicketPriority fromString(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'high':
      case '1':
        return TicketPriority.high;
      case 'low':
      case '3':
        return TicketPriority.low;
      default:
        return TicketPriority.medium;
    }
  }
}

extension TicketStatusX on TicketStatus {
  String get firestoreValue {
    switch (this) {
      case TicketStatus.open:
        return 'open';
      case TicketStatus.inProgress:
        return 'in_progress';
      case TicketStatus.resolved:
        return 'resolved';
      case TicketStatus.closed:
        return 'closed';
    }
  }

  String get label {
    switch (this) {
      case TicketStatus.open:
        return 'Open';
      case TicketStatus.inProgress:
        return 'In progress';
      case TicketStatus.resolved:
        return 'Resolved';
      case TicketStatus.closed:
        return 'Closed';
    }
  }

  bool get isTerminal =>
      this == TicketStatus.resolved || this == TicketStatus.closed;

  static TicketStatus fromString(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'in_progress':
      case 'inprogress':
      case 'active':
        return TicketStatus.inProgress;
      case 'resolved':
      case 'done':
      case 'completed':
        return TicketStatus.resolved;
      case 'closed':
      case 'cancelled':
      case 'canceled':
        return TicketStatus.closed;
      default:
        return TicketStatus.open;
    }
  }
}

class TicketModel {
  const TicketModel({
    this.firebaseId,
    this.ownerUid,
    required this.title,
    this.description,
    this.priority = TicketPriority.medium,
    this.status = TicketStatus.open,
    this.assigneeId,
    this.assigneeName,
    this.parentTaskId,
    this.parentTaskTitle,
    this.reportIds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  final String? firebaseId;
  final String? ownerUid;
  final String title;
  final String? description;
  final TicketPriority priority;
  final TicketStatus status;
  final String? assigneeId;
  final String? assigneeName;
  final String? parentTaskId;
  final String? parentTaskTitle;
  final List<String> reportIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isStandalone =>
      parentTaskId == null || parentTaskId!.trim().isEmpty;

  factory TicketModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return TicketModel(
      firebaseId: doc.id,
      ownerUid: data['owner_uid'] as String? ?? doc.reference.parent.parent?.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      priority: TicketPriorityX.fromString(data['priority'] as String?),
      status: TicketStatusX.fromString(data['status'] as String?),
      assigneeId: data['assignee_id']?.toString(),
      assigneeName: data['assignee_name'] as String?,
      parentTaskId: data['parent_task_id'] as String?,
      parentTaskTitle: data['parent_task_title'] as String?,
      reportIds: data['report_ids'] != null
          ? (data['report_ids'] as List).map((e) => e.toString()).toList()
          : const [],
      createdAt: data['created_at'] is Timestamp
          ? (data['created_at'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updated_at'] is Timestamp
          ? (data['updated_at'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore({required String ownerUid}) {
    return {
      'owner_uid': ownerUid,
      'title': title,
      'description': description,
      'priority': priority.firestoreValue,
      'status': status.firestoreValue,
      'assignee_id': assigneeId,
      'assignee_name': assigneeName,
      'parent_task_id': parentTaskId,
      'parent_task_title': parentTaskTitle,
      'report_ids': reportIds,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
    };
  }

  TicketModel copyWith({
    String? firebaseId,
    String? ownerUid,
    String? title,
    String? description,
    TicketPriority? priority,
    TicketStatus? status,
    String? assigneeId,
    String? assigneeName,
    String? parentTaskId,
    String? parentTaskTitle,
    List<String>? reportIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearParent = false,
    bool clearAssignee = false,
  }) {
    return TicketModel(
      firebaseId: firebaseId ?? this.firebaseId,
      ownerUid: ownerUid ?? this.ownerUid,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      assigneeId: clearAssignee ? null : (assigneeId ?? this.assigneeId),
      assigneeName:
          clearAssignee ? null : (assigneeName ?? this.assigneeName),
      parentTaskId: clearParent ? null : (parentTaskId ?? this.parentTaskId),
      parentTaskTitle:
          clearParent ? null : (parentTaskTitle ?? this.parentTaskTitle),
      reportIds: reportIds ?? this.reportIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
