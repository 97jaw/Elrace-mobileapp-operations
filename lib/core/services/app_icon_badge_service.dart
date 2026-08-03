import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Keeps the **outside** app-icon badge in sync with the in-app bell count.
///
/// iOS launcher badges are normally set by APNs `aps.badge` (chat was hardcoding
/// `1`) and were never cleared when the user opened Notification Center.
class AppIconBadgeService {
  AppIconBadgeService._();

  static const MethodChannel _channel =
      MethodChannel('ae.elrace.mobile/app_icon_badge');

  static int? _lastApplied;

  /// Set the springboard / launcher badge. Use `0` to clear.
  ///
  /// Pass [force] to re-apply the same count (clears a stuck APNs badge after
  /// the OS set it outside this channel).
  static Future<void> setCount(int count, {bool force = false}) async {
    final next = count < 0 ? 0 : count;
    if (!force && _lastApplied == next) return;
    try {
      await _channel.invokeMethod<void>('setBadge', {'count': next});
      _lastApplied = next;
    } catch (e) {
      debugPrint('AppIconBadgeService.setCount($next) failed: $e');
    }
  }

  static Future<void> clear() => setCount(0);
}
