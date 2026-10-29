import 'dart:convert';

import 'package:el_race/core/services/notification_api_service.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:http/http.dart' as http;

class NotificationFlags {
  const NotificationFlags({
    this.enabled = false,
    this.appInboxV2 = false,
    this.serverTaskNotifications = false,
    this.inboxSilentSync = false,
    this.prayerTextV2 = false,
    this.retentionDays = 90,
  });

  final bool enabled;
  final bool appInboxV2;
  final bool serverTaskNotifications;
  final bool inboxSilentSync;
  final bool prayerTextV2;
  final int retentionDays;

  static const defaults = NotificationFlags();

  Map<String, dynamic> toMap() => {
        'enabled': enabled,
        'app_inbox_v2': appInboxV2,
        'server_task_notifications': serverTaskNotifications,
        'inbox_silent_sync': inboxSilentSync,
        'prayer_text_v2': prayerTextV2,
        'retention_days': retentionDays,
      };

  factory NotificationFlags.fromMap(Map<String, dynamic> map) {
    return NotificationFlags(
      enabled: _bool(map['enabled']),
      appInboxV2: _bool(map['app_inbox_v2']),
      serverTaskNotifications: _bool(map['server_task_notifications']),
      inboxSilentSync: _bool(map['inbox_silent_sync']),
      prayerTextV2: _bool(map['prayer_text_v2']),
      retentionDays: int.tryParse('${map['retention_days']}') ?? 90,
    );
  }

  static bool _bool(dynamic value) {
    if (value is bool) return value;
    final text = (value ?? '').toString().trim().toLowerCase();
    return text == '1' || text == 'true' || text == 'yes';
  }
}

class NotificationConfigService {
  static const _cacheKey = 'elrace_notify_config_v1';
  static NotificationFlags current = NotificationFlags.defaults;

  static Future<void> loadCached() async {
    try {
      final raw = SharedPref.preferences.getPreferenceInstance().getString(_cacheKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        current = NotificationFlags.fromMap(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      current = NotificationFlags.defaults;
    }
  }

  /// Network or parse failure keeps the last known flags, or all-off if none.
  static Future<void> refresh() async {
    try {
      final response = await http.post(
        Uri.parse('${NotificationApiService.baseUrl}/v2/notifications/config'),
        headers: NotificationApiService.headers(),
        body: jsonEncode({'jsonrpc': '2.0', 'method': 'call', 'params': {}}),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        current = NotificationFlags.defaults;
        return;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        current = NotificationFlags.defaults;
        return;
      }
      final result = decoded['result'];
      if (result is! Map) {
        current = NotificationFlags.defaults;
        return;
      }
      final flags = NotificationFlags.fromMap(Map<String, dynamic>.from(result));
      current = flags;
      await SharedPref.preferences
          .getPreferenceInstance()
          .setString(_cacheKey, jsonEncode(flags.toMap()));
    } catch (_) {
      current = NotificationFlags.defaults;
    }
  }
}
