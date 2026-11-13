import 'package:el_race/core/services/app_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Signs the user out silently after [AppConfigService.sessionMaxHours]
/// counted from the last login (Odoo param `elrace.mobile_session_max_hours`,
/// 0 / empty = off). App-side only: the server token lifetime is unchanged.
abstract final class SessionExpiryService {
  static const _keyLoginAt = 'session_login_at_ms';
  static const _keyLastActive = 'session_last_active_ms';

  /// Call when the app goes to background (and after login).
  static Future<void> markActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastActive, DateTime.now().millisecondsSinceEpoch);
  }

  /// True when the app was last used more than [idle] ago (or never stamped).
  /// Used on cold start to decide whether the biometric gate is needed.
  static Future<bool> idleLongerThan(Duration idle) async {
    final prefs = await SharedPreferences.getInstance();
    final at = prefs.getInt(_keyLastActive);
    if (at == null) return true;
    return DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(at)) >=
        idle;
  }

  /// Call right after a successful login (password or UAE PASS).
  static Future<void> markLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLoginAt, DateTime.now().millisecondsSinceEpoch);
  }

  /// True when the session is older than the configured hours.
  /// Sessions from before this feature have no stamp: the clock starts now,
  /// so nobody is signed out the moment the parameter is turned on.
  static Future<bool> isExpired() async {
    final hours = AppConfigService.instance.sessionMaxHours;
    if (hours == null || hours <= 0) return false;
    final prefs = await SharedPreferences.getInstance();
    final at = prefs.getInt(_keyLoginAt);
    if (at == null) {
      await markLogin();
      return false;
    }
    final age = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(at));
    return age >= Duration(minutes: (hours * 60).round());
  }
}
