import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:el_race/core/timesheet/services/timesheet_approval_feature.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Ids for rows that came from `users/{uid}/app_notifications`.
abstract final class AppNotificationIds {
  static const prefix = 'fs:';

  static String encode(String firestoreId) => '$prefix$firestoreId';

  static bool isFirestore(String id) => id.startsWith(prefix);

  static String decode(String id) {
    if (!isFirestore(id)) return id;
    return id.substring(prefix.length);
  }
}

/// Client access to Cloud Function–written `app_notifications` (results only).
class AppNotificationsRepository {
  AppNotificationsRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    TimesheetApprovalFeature? feature,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _feature = feature ?? TimesheetApprovalFeature.instance;

  static final AppNotificationsRepository instance =
      AppNotificationsRepository();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final TimesheetApprovalFeature _feature;

  String? get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return null;
    return uid;
  }

  CollectionReference<Map<String, dynamic>>? get _collection {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('app_notifications');
  }

  Future<bool> _flagOn() async {
    try {
      return _feature.isEnabled();
    } catch (_) {
      return false;
    }
  }

  /// Newest first, limit 50. Empty when flag off / signed out / error.
  Future<List<Map<String, dynamic>>> listMine({int limit = 50}) async {
    if (!await _flagOn()) return const [];
    final col = _collection;
    if (col == null) return const [];
    try {
      final snap = await col
          .orderBy('created_at', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map(_rowFromDoc).toList();
    } catch (e) {
      debugPrint('AppNotificationsRepository.listMine: $e');
      return const [];
    }
  }

  /// Unread count for the bell; 0 on any error or when flag is off.
  Future<int> unreadCountOrZero() async {
    if (!await _flagOn()) return 0;
    final col = _collection;
    if (col == null) return 0;
    try {
      final snap = await col.where('read', isEqualTo: false).count().get();
      return snap.count ?? 0;
    } catch (e) {
      debugPrint('AppNotificationsRepository.unreadCountOrZero: $e');
      return 0;
    }
  }

  /// Bell / app-icon total = existing unread + Firestore result unread.
  Future<int> addUnreadTo(int base) async {
    final fs = await unreadCountOrZero();
    final total = base + fs;
    return total < 0 ? 0 : total;
  }

  Future<void> markRead(String encodedId) async {
    final col = _collection;
    if (col == null) return;
    final id = AppNotificationIds.decode(encodedId);
    if (id.isEmpty) return;
    try {
      await col.doc(id).update({'read': true});
    } catch (e) {
      debugPrint('AppNotificationsRepository.markRead: $e');
    }
  }

  Future<void> markAllUnreadRead() async {
    final col = _collection;
    if (col == null) return;
    if (!await _flagOn()) return;
    try {
      final snap = await col.where('read', isEqualTo: false).get();
      if (snap.docs.isEmpty) return;
      var batch = _firestore.batch();
      var n = 0;
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'read': true});
        n++;
        if (n >= 400) {
          await batch.commit();
          batch = _firestore.batch();
          n = 0;
        }
      }
      if (n > 0) await batch.commit();
    } catch (e) {
      debugPrint('AppNotificationsRepository.markAllUnreadRead: $e');
    }
  }

  Future<void> delete(String encodedId) async {
    final col = _collection;
    if (col == null) return;
    final id = AppNotificationIds.decode(encodedId);
    if (id.isEmpty) return;
    try {
      await col.doc(id).delete();
    } catch (e) {
      debugPrint('AppNotificationsRepository.delete: $e');
    }
  }

  /// Deletes every `app_notifications` doc for the signed-in user (batched).
  Future<void> deleteAll() async {
    final col = _collection;
    if (col == null) return;
    try {
      while (true) {
        final snap = await col.limit(400).get();
        if (snap.docs.isEmpty) return;
        final batch = _firestore.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        if (snap.docs.length < 400) return;
      }
    } catch (e) {
      debugPrint('AppNotificationsRepository.deleteAll: $e');
    }
  }

  Map<String, dynamic> _rowFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final created = data['created_at'];
    String createdIso = '';
    if (created is Timestamp) {
      createdIso = created.toDate().toUtc().toIso8601String();
    } else if (created != null) {
      createdIso = created.toString();
    }
    final read = data['read'] == true;
    return {
      'id': AppNotificationIds.encode(doc.id),
      'title': data['title']?.toString() ?? 'Notification',
      'body': data['body']?.toString() ?? '',
      'category': data['category']?.toString() ?? 'timesheet_approval',
      'type': data['type']?.toString() ?? '',
      'model': data['model']?.toString() ?? 'firestore.timesheet_approval',
      'res_id': data['res_id']?.toString() ?? '',
      'action': 'open_record',
      'isRead': read,
      'is_read': read,
      'created_at': createdIso,
      'timestamp': createdIso,
      'source': 'firestore_app_notifications',
    };
  }
}
