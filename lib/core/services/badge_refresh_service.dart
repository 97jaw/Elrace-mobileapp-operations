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

  /// Register [callback] to run after a shared badge refresh completes.
  /// Use the widget's `State` object as [key] and call [removeListener]
  /// in `dispose()`.
  static void addListener(Object key, VoidCallback callback) {
    _listeners[key] = callback;
  }

  static void removeListener(Object key) {
    _listeners.remove(key);
  }

  /// One shared server sync for all mounted badge widgets.
  ///
  /// After this completes, `NotificationStorageService.getLocalStoredCount()`
  /// and `ApprovalCountService.getTotalApprovalCount()` return fresh values
  /// from local storage / warm cache, so listener callbacks are cheap.
  static Future<void> refreshOnResume() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      ApprovalCountService.invalidateCache();
      await Future.wait<void>([
        NotificationStorageService.syncBadgeFromServer()
            .timeout(const Duration(seconds: 10), onTimeout: () => 0)
            .then((_) {}),
        ApprovalCountService.getTotalApprovalCount()
            .timeout(const Duration(seconds: 15), onTimeout: () => 0)
            .then((_) {}),
      ]);
      // Align springboard badge even when local count did not change
      // (clears stuck APNs badge:1 from older chat pushes).
      final local = await NotificationStorageService.getLocalStoredCount();
      await AppIconBadgeService.setCount(local, force: true);
    } catch (e) {
      debugPrint('BadgeRefreshService.refreshOnResume failed: $e');
    } finally {
      _inFlight = false;
    }
    notifyListeners();
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
