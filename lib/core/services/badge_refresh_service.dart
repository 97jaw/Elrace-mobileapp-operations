import 'package:el_race/core/notifications/app_notifications_repository.dart';
import 'package:el_race/core/diagnostics/counter_refresh_trace.dart';
import 'package:el_race/core/services/app_icon_badge_service.dart';
import 'package:el_race/core/services/approval_count_service.dart';
import 'package:el_race/core/services/notification_storage_service.dart';
import 'package:flutter/foundation.dart';

/// Single owner of the resume-time badge refresh (notification + approval
/// counts).
///
/// Before this service, three header widgets (`HomeGlassAppBar`,
/// `HeaderWidget`, `ProjectsGreetingHeader`) each registered their own
/// `WidgetsBindingObserver` and independently hit the notification and
/// approval APIs on every app resume — duplicate network calls racing the
/// rest of the resume fan-out. Now `ResumeCoordinator` calls
/// [refreshOnResume] exactly once; widgets register a listener and re-read
/// the (now warm) local/cached values, which costs no extra network calls.
class BadgeRefreshService {
  BadgeRefreshService._();

  static final Map<Object, VoidCallback> _listeners = {};
  static bool _inFlight = false;
  static DateTime? _lastThrottledRefresh;

  static const Duration homeReturnThrottle = Duration(seconds: 30);

  /// Register [callback] to run after a shared badge refresh completes.
  /// Use the widget's `State` object as [key] and call [removeListener]
  /// in `dispose()`.
  static void addListener(Object key, VoidCallback callback) {
    _listeners[key] = callback;
  }

  static void removeListener(Object key) {
    _listeners.remove(key);
  }

  /// Pure throttle gate (unit-tested).
  static bool shouldRunThrottled({
    required DateTime? lastRun,
    required DateTime now,
    Duration minInterval = homeReturnThrottle,
  }) {
    if (lastRun == null) return true;
    return now.difference(lastRun) >= minInterval;
  }

  /// Waiting + bell refresh, at most once per [minInterval].
  ///
  /// Used when returning to home or on approval FCM so back-and-forth does
  /// not spam Odoo. Live Firestore SD / unread still update via the watcher.
  static Future<void> refreshWaitingAndBellThrottled({
    Duration minInterval = homeReturnThrottle,
    String reason = '',
  }) async {
    CounterRefreshTrace.trigger(
      'global_badges',
      reason.isEmpty ? 'throttled_request' : reason,
      fields: <String, Object?>{
        'minimum_interval_ms': minInterval.inMilliseconds,
      },
    );
    final now = DateTime.now();
    if (!shouldRunThrottled(
      lastRun: _lastThrottledRefresh,
      now: now,
      minInterval: minInterval,
    )) {
      debugPrint('BadgeRefreshService throttled ($reason)');
      CounterRefreshTrace.state(
        'global_badges',
        'throttled',
        fields: <String, Object?>{'trigger': reason},
      );
      notifyListeners();
      return;
    }
    _lastThrottledRefresh = now;
    await refreshOnResume(
        trigger: reason.isEmpty ? 'throttled_request' : reason);
  }

  /// One shared server sync for all mounted badge widgets.
  ///
  /// After this completes, `NotificationStorageService.getLocalStoredCount()`
  /// and `ApprovalCountService.getTotalApprovalCount()` return fresh values
  /// from local storage / warm cache, so listener callbacks are cheap.
  static Future<void> refreshOnResume({String trigger = 'app_resume'}) async {
    CounterRefreshTrace.trigger('global_badges', trigger);
    if (_inFlight) {
      CounterRefreshTrace.state(
        'global_badges',
        'coalesced_in_flight',
        fields: <String, Object?>{'trigger': trigger},
      );
      return;
    }
    _inFlight = true;
    try {
      ApprovalCountService.invalidateCache();
      await Future.wait<void>([
        CounterRefreshTrace.io<int>(
          domain: 'notification_bell',
          operation: 'syncBadgeFromServer',
          trigger: trigger,
          call: NotificationStorageService.syncBadgeFromServer,
        ).timeout(const Duration(seconds: 10), onTimeout: () => 0).then((_) {}),
        ApprovalCountService.getTotalApprovalCount(trigger: trigger)
            .timeout(const Duration(seconds: 15), onTimeout: () => 0)
            .then((_) {}),
      ]);
      // Align springboard badge even when local count did not change
      // (clears stuck APNs badge:1 from older chat pushes). Include Firestore
      // timesheet-approval result unread (0 when flag off / error).
      final local = await NotificationStorageService.getLocalStoredCount();
      final total =
          await AppNotificationsRepository.instance.addUnreadTo(local);
      await AppIconBadgeService.setCount(total, force: true);
      CounterRefreshTrace.state(
        'launcher_badge',
        'set_after_global_refresh',
        fields: <String, Object?>{'count': total, 'trigger': trigger},
      );
    } catch (e) {
      debugPrint('BadgeRefreshService.refreshOnResume failed: $e');
    } finally {
      _inFlight = false;
      CounterRefreshTrace.state(
        'global_badges',
        'refresh_finished',
        fields: <String, Object?>{'trigger': trigger},
      );
    }
    notifyListeners();
  }

  /// True for Odoo waiting approvals and timesheet approval pushes.
  static bool isApprovalBadgePush({
    required String category,
    Map<String, dynamic>? data,
  }) {
    final candidates = <String>[
      category,
      if (data != null) ...[
        '${data['category'] ?? ''}',
        '${data['type'] ?? ''}',
        '${data['model'] ?? ''}',
      ],
    ];
    for (final raw in candidates) {
      final key = raw.trim().toLowerCase();
      if (key.isEmpty) continue;
      if (key.startsWith('timesheet_approval')) return true;
      if (key == 'waiting' ||
          key == 'employee.requests' ||
          key == 'account.move' ||
          key == 'purchase.order' ||
          key == 'hr.expense.sheet' ||
          key == 'it.hardware.request') {
        return true;
      }
    }
    return false;
  }

  /// Re-run all registered widget callbacks (cheap local reads).
  static void notifyListeners() {
    for (final callback in List.of(_listeners.values)) {
      try {
        callback();
      } catch (e) {
        debugPrint('BadgeRefreshService listener failed: $e');
      }
    }
  }
}
