import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Queues cross-device assignment pushes for Cloud Functions.
///
/// Collection: `assignment_push_requests/{id}`
/// Function: `onAssignmentPushRequest` sends FCM to the assignee.
class AssignmentPushService {
  AssignmentPushService._();
  static final AssignmentPushService instance = AssignmentPushService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Ask the backend to FCM-notify an assignee about a new task/ticket.
  Future<void> enqueue({
    required String taskId,
    required String taskTitle,
    required String assignedBy,
    int? assigneeOdooUserId,
    String? assigneeFirebaseUid,
    bool isFirebaseTask = true,
    String category = 'task',
  }) async {
    if ((assigneeOdooUserId == null || assigneeOdooUserId <= 0) &&
        (assigneeFirebaseUid == null || assigneeFirebaseUid.isEmpty)) {
      debugPrint('⚠️ AssignmentPushService: no assignee identity; skip');
      return;
    }

    try {
      await _db.collection('assignment_push_requests').add({
        'task_id': taskId,
        'task_title': taskTitle,
        'assigned_by': assignedBy,
        if (assigneeOdooUserId != null && assigneeOdooUserId > 0)
          'assignee_odoo_user_id': assigneeOdooUserId,
        if (assigneeFirebaseUid != null && assigneeFirebaseUid.isNotEmpty)
          'assignee_firebase_uid': assigneeFirebaseUid,
        'is_firebase_task': isFirebaseTask,
        'category': category,
        'created_at': FieldValue.serverTimestamp(),
      });
      debugPrint(
        '✅ AssignmentPushService: queued push for task=$taskId '
        'odoo=$assigneeOdooUserId uid=$assigneeFirebaseUid',
      );
    } catch (e) {
      debugPrint('⚠️ AssignmentPushService: enqueue failed: $e');
    }
  }
}
