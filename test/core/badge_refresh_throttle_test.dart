import 'package:el_race/core/services/badge_refresh_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BadgeRefreshService.shouldRunThrottled', () {
    test('runs when never run before', () {
      expect(
        BadgeRefreshService.shouldRunThrottled(
          lastRun: null,
          now: DateTime(2026, 1, 1, 12),
        ),
        isTrue,
      );
    });

    test('blocks within 30 seconds', () {
      final last = DateTime(2026, 1, 1, 12, 0, 0);
      expect(
        BadgeRefreshService.shouldRunThrottled(
          lastRun: last,
          now: last.add(const Duration(seconds: 29)),
        ),
        isFalse,
      );
    });

    test('allows after 30 seconds', () {
      final last = DateTime(2026, 1, 1, 12, 0, 0);
      expect(
        BadgeRefreshService.shouldRunThrottled(
          lastRun: last,
          now: last.add(const Duration(seconds: 30)),
        ),
        isTrue,
      );
    });
  });

  group('BadgeRefreshService.isApprovalBadgePush', () {
    test('detects timesheet approval categories and types', () {
      expect(
        BadgeRefreshService.isApprovalBadgePush(
          category: 'timesheet_approval',
          data: const {},
        ),
        isTrue,
      );
      expect(
        BadgeRefreshService.isApprovalBadgePush(
          category: 'notification',
          data: const {'type': 'timesheet_approval.waiting'},
        ),
        isTrue,
      );
      expect(
        BadgeRefreshService.isApprovalBadgePush(
          category: 'chat_message',
          data: const {},
        ),
        isFalse,
      );
    });

    test('detects Odoo waiting models', () {
      expect(
        BadgeRefreshService.isApprovalBadgePush(
          category: 'employee.requests',
          data: const {},
        ),
        isTrue,
      );
      expect(
        BadgeRefreshService.isApprovalBadgePush(
          category: 'account.move',
          data: const {},
        ),
        isTrue,
      );
    });
  });
}
