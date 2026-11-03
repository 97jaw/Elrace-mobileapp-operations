import 'package:el_race/core/notifications/app_notifications_repository.dart';

/// Where a Notification Center row's delete / clear should go.
enum NotificationDeleteTarget {
  localStorage,
  inboxV2,
  firestoreAppNotifications,
}

/// Pure helpers for merging Firestore `app_notifications` into the center list.
abstract final class NotificationListMerge {
  /// Newest first by `timestamp` / `created_at`, then [limit].
  static List<Map<String, dynamic>> mergeAndSort({
    required List<Map<String, dynamic>> primary,
    required List<Map<String, dynamic>> firestoreRows,
    int limit = 50,
  }) {
    final merged = <Map<String, dynamic>>[
      ...primary.map((e) => Map<String, dynamic>.from(e)),
      ...firestoreRows.map((e) => Map<String, dynamic>.from(e)),
    ];
    merged.sort(compareNewestFirst);
    if (merged.length <= limit) return merged;
    return merged.take(limit).toList();
  }

  static int compareNewestFirst(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final aTime = _parseTime(a);
    final bTime = _parseTime(b);
    return bTime.compareTo(aTime);
  }

  static DateTime _parseTime(Map<String, dynamic> item) {
    return DateTime.tryParse(
          (item['timestamp'] ?? item['created_at'] ?? '').toString(),
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  static NotificationDeleteTarget deleteTargetFor({
    required String id,
    required bool inboxV2Enabled,
  }) {
    if (AppNotificationIds.isFirestore(id)) {
      return NotificationDeleteTarget.firestoreAppNotifications;
    }
    if (inboxV2Enabled) return NotificationDeleteTarget.inboxV2;
    return NotificationDeleteTarget.localStorage;
  }

  static bool shouldOpenViaRouter({
    required String id,
    required bool inboxV2Enabled,
  }) {
    if (AppNotificationIds.isFirestore(id)) return true;
    return inboxV2Enabled;
  }
}
