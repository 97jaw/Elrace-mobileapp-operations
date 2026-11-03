import 'package:el_race/core/notifications/app_notifications_repository.dart';
import 'package:el_race/core/notifications/notification_list_merge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NotificationListMerge.mergeAndSort', () {
    test('interleaves by date and applies limit', () {
      final merged = NotificationListMerge.mergeAndSort(
        primary: [
          {
            'id': 'local-1',
            'created_at': '2026-01-01T10:00:00.000Z',
            'title': 'Local older',
          },
          {
            'id': 'local-2',
            'created_at': '2026-01-03T10:00:00.000Z',
            'title': 'Local newest',
          },
        ],
        firestoreRows: [
          {
            'id': AppNotificationIds.encode('evt-1'),
            'created_at': '2026-01-02T10:00:00.000Z',
            'title': 'FS mid',
          },
        ],
        limit: 2,
      );
      expect(merged.map((e) => e['id']), [
        'local-2',
        AppNotificationIds.encode('evt-1'),
      ]);
    });
  });

  group('NotificationListMerge.deleteTargetFor', () {
    test('routes Firestore ids to app_notifications', () {
      expect(
        NotificationListMerge.deleteTargetFor(
          id: AppNotificationIds.encode('ta-1:approved:all'),
          inboxV2Enabled: false,
        ),
        NotificationDeleteTarget.firestoreAppNotifications,
      );
      expect(
        NotificationListMerge.deleteTargetFor(
          id: AppNotificationIds.encode('ta-1:approved:all'),
          inboxV2Enabled: true,
        ),
        NotificationDeleteTarget.firestoreAppNotifications,
      );
    });

    test('routes non-FS ids to inbox v2 or local storage', () {
      expect(
        NotificationListMerge.deleteTargetFor(
          id: '42',
          inboxV2Enabled: true,
        ),
        NotificationDeleteTarget.inboxV2,
      );
      expect(
        NotificationListMerge.deleteTargetFor(
          id: '42',
          inboxV2Enabled: false,
        ),
        NotificationDeleteTarget.localStorage,
      );
    });
  });

  group('NotificationListMerge.shouldOpenViaRouter', () {
    test('Firestore rows always open via router', () {
      expect(
        NotificationListMerge.shouldOpenViaRouter(
          id: AppNotificationIds.encode('x'),
          inboxV2Enabled: false,
        ),
        isTrue,
      );
    });

    test('local rows only open when inbox v2 is on', () {
      expect(
        NotificationListMerge.shouldOpenViaRouter(
          id: '42',
          inboxV2Enabled: false,
        ),
        isFalse,
      );
      expect(
        NotificationListMerge.shouldOpenViaRouter(
          id: '42',
          inboxV2Enabled: true,
        ),
        isTrue,
      );
    });
  });
}
