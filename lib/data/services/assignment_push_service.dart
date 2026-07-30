import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Queues cross-device assignment / completion pushes for Cloud Functions.
///
/// Collection: `assignment_push_requests/{id}`
/// Function: `onAssignmentPushRequest` sends FCM to the recipient
/// (`assignee_*` fields = who receives the push).
class AssignmentPushService {
  AssignmentPushService._();
  static final AssignmentPushService instance = AssignmentPushService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String actionNewTask = 'new_task';
  static const String actionTaskCompleted = 'task_completed';

  /// Ask the backend to FCM-notify a user about a task/ticket event.
  Future<void> enqueue({
    required String taskId,
    required String taskTitle,
    required String assignedBy,
    int? assigneeOdooUserId,
    String? assigneeFirebaseUid,
    bool isFirebaseTask = true,
    String category = 'task',
    String action = actionNewTask,
    String? completedBy,
  }) async {
    if ((assigneeOdooUserId == null || assigneeOdooUserId <= 0) &&
        (assigneeFirebaseUid == null || assigneeFirebaseUid.isEmpty)) {
      debugPrint('⚠️ AssignmentPushService: no recipient identity; skip');
      return;
    }

    try {
      await _db.collection('assignment_push_requests').add({
        'task_id': taskId,
        'task_title': taskTitle,
        'assigned_by': assignedBy,
        'action': action,
        if (completedBy != null && completedBy.isNotEmpty)
          'completed_by': completedBy,
        if (assigneeOdooUserId != null && assigneeOdooUserId > 0)
          'assignee_odoo_user_id': assigneeOdooUserId,
        if (assigneeFirebaseUid != null && assigneeFirebaseUid.isNotEmpty)
          'assignee_firebase_uid': assigneeFirebaseUid,
        'is_firebase_task': isFirebaseTask,
        'category': category,
        'created_at': FieldValue.serverTimestamp(),
      });
      debugPrint(
        '✅ AssignmentPushService: queued action=$action for task=$taskId '
        'odoo=$assigneeOdooUserId uid=$assigneeFirebaseUid',
      );
    } catch (e) {
      debugPrint('⚠️ AssignmentPushService: enqueue failed: $e');
    }
  }

  /// Remember who created an Odoo ticket so completion can notify them.
  Future<void> rememberTicketCreator({
    required String taskId,
    int? creatorOdooUserId,
    String? creatorFirebaseUid,
  }) async {
    if ((creatorOdooUserId == null || creatorOdooUserId <= 0) &&
        (creatorFirebaseUid == null || creatorFirebaseUid.isEmpty)) {
      return;
    }
    try {
      await _db.collection('ticket_creators').doc(taskId).set({
        if (creatorOdooUserId != null && creatorOdooUserId > 0)
          'creator_odoo_user_id': creatorOdooUserId,
        if (creatorFirebaseUid != null && creatorFirebaseUid.isNotEmpty)
          'creator_firebase_uid': creatorFirebaseUid,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ AssignmentPushService: rememberTicketCreator failed: $e');
    }
  }

  /// Notify the stored ticket creator that someone completed the ticket.
  Future<void> enqueueTicketCompleted({
    required String taskId,
    required String taskTitle,
    required String completedBy,
    int? completerOdooUserId,
    String? completerFirebaseUid,
  }) async {
    try {
      final doc = await _db.collection('ticket_creators').doc(taskId).get();
      if (!doc.exists) {
        debugPrint(
          '⚠️ AssignmentPushService: no ticket_creators/$taskId; skip complete push',
        );
        return;
      }
      final data = doc.data() ?? {};
      final odooId = data['creator_odoo_user_id'];
      final fbUid = data['creator_firebase_uid']?.toString();
      final creatorOdoo = odooId is int
          ? odooId
          : int.tryParse(odooId?.toString() ?? '');
      final creatorFb = (fbUid ?? '').trim();

      // Skip when the creator completes their own ticket.
      if (completerFirebaseUid != null &&
          completerFirebaseUid.isNotEmpty &&
          creatorFb.isNotEmpty &&
          completerFirebaseUid == creatorFb) {
        return;
      }
      if (completerOdooUserId != null &&
          completerOdooUserId > 0 &&
          creatorOdoo != null &&
          completerOdooUserId == creatorOdoo) {
        return;
      }

      await enqueue(
        taskId: taskId,
        taskTitle: taskTitle,
        assignedBy: completedBy,
        completedBy: completedBy,
        assigneeOdooUserId: creatorOdoo,
        assigneeFirebaseUid: creatorFb.isEmpty ? null : creatorFb,
        isFirebaseTask: false,
        category: 'ticket',
        action: actionTaskCompleted,
      );
    } catch (e) {
      debugPrint('⚠️ AssignmentPushService: enqueueTicketCompleted failed: $e');
    }
  }
}
