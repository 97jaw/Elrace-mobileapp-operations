import 'dart:convert';
import 'dart:io';

import 'package:el_race/core/services/mobile_device_id_service.dart';
import 'package:el_race/core/services/notification_api_service.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/data/services/task_notification_service.dart';
import 'package:el_race/utils/string_utils.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Registers and unregisters this install with `/api/v2/notifications/device/*`.
/// Failures are ignored so login, resume, and logout keep their current flow.
class NotificationDeviceService {
  NotificationDeviceService._();

  static DateTime? _lastRegisterAt;
  static String? _lastRegisterToken;

  static Future<void> register({String? fcmToken}) async {
    try {
      if (!SharedPref.isUserAuthenticated()) return;
      final auth = SharedPref.getLoginDataOrNull()?.result?.token?.trim() ?? '';
      if (auth.isEmpty) return;
      final fcm = (fcmToken ?? SharedPref().getPreferenceString(fcm_token)).trim();
      if (fcm.isEmpty) return;
      final now = DateTime.now();
      if (_lastRegisterToken == fcm &&
          _lastRegisterAt != null &&
          now.difference(_lastRegisterAt!) < const Duration(seconds: 15)) {
        return;
      }
      final deviceId = await MobileDeviceIdService.getOrCreate();
      final info = await PackageInfo.fromPlatform();
      final response = await http
          .post(
            Uri.parse('${NotificationApiService.baseUrl}/v2/notifications/device/register'),
            headers: NotificationApiService.headers(),
            body: jsonEncode({
              'jsonrpc': '2.0',
              'method': 'call',
              'params': {
                'device_id': deviceId,
                'fcm_token': fcm,
                'platform': Platform.isIOS ? 'ios' : 'android',
                'app_version': info.version,
              },
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _lastRegisterToken = fcm;
        _lastRegisterAt = now;
      }
    } catch (_) {}
  }

  /// Clears this device's token before the session is revoked.
  static Future<void> unregister() async {
    try {
      final auth = SharedPref.getLoginDataOrNull()?.result?.token?.trim() ?? '';
      if (auth.isEmpty) return;
      final deviceId = await MobileDeviceIdService.getOrCreate();
      await http
          .post(
            Uri.parse('${NotificationApiService.baseUrl}/v2/notifications/device/unregister'),
            headers: NotificationApiService.headers(),
            body: jsonEncode({
              'jsonrpc': '2.0',
              'method': 'call',
              'params': {'device_id': deviceId},
            }),
          )
          .timeout(const Duration(seconds: 8));
      _lastRegisterToken = null;
      _lastRegisterAt = null;
    } catch (_) {}
  }

  /// Drop the push token and cancel local task alerts. Call this before the
  /// session token is cleared.
  static Future<void> onLogout() async {
    await unregister();
    try {
      await TaskNotificationService().cancelAllPendingTaskNotifications();
    } catch (_) {}
  }
}
