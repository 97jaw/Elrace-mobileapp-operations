import 'dart:convert';

import 'package:el_race/core/notifications/notification_config_service.dart';
import 'package:el_race/core/services/notification_api_service.dart';
import 'package:el_race/core/services/notification_storage_service.dart';
import 'package:http/http.dart' as http;

class NotificationInboxRow {
  const NotificationInboxRow(this.data);

  final Map<String, dynamic> data;

  String get id => '${data['id'] ?? ''}';
  String get title => '${data['title'] ?? ''}';
  String get body => '${data['body'] ?? ''}';
  String get category => '${data['category'] ?? ''}';
  String get createdAt => '${data['created_at'] ?? ''}';
}

class NotificationInboxCategory {
  const NotificationInboxCategory({
    required this.code,
    required this.name,
    this.icon = '',
    this.color = '',
    this.sequence = 0,
    this.mandatory = false,
    this.localOnly = false,
    this.muted = false,
  });

  final String code;
  final String name;
  final String icon;
  final String color;
  final int sequence;
  final bool mandatory;
  final bool localOnly;
  final bool muted;

  factory NotificationInboxCategory.fromMap(Map<String, dynamic> map) {
    return NotificationInboxCategory(
      code: '${map['code'] ?? ''}',
      name: '${map['name'] ?? map['code'] ?? ''}',
      icon: '${map['icon'] ?? ''}',
      color: '${map['color'] ?? ''}',
      sequence: int.tryParse('${map['sequence']}') ?? 0,
      mandatory: _bool(map['mandatory']),
      localOnly: _bool(map['local_only']),
      muted: _bool(map['muted']),
    );
  }
}

class NotificationInboxRepository {
  static const _pageSize = 50;

  static Future<List<NotificationInboxRow>> list({
    int offset = 0,
    String? q,
    String? category,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final data = await _call('/v2/notifications/list', {
      'limit': _pageSize,
      'offset': offset,
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      if (category != null && category.isNotEmpty) 'category': category,
      if (dateFrom != null) 'date_from': _day(dateFrom),
      if (dateTo != null) 'date_to': _day(dateTo),
    });
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((row) => NotificationInboxRow(Map<String, dynamic>.from(row)))
        .toList();
  }

  static Future<void> markAllRead() async {
    await _call('/v2/notifications/mark_all_read', const {});
  }

  static Future<int> unreadCount() async {
    final data = await _call('/v2/notifications/unread_count', const {});
    if (data is Map) return int.tryParse('${data['count']}') ?? 0;
    return 0;
  }

  static Future<void> hide(String id) async {
    await _call('/v2/notifications/hide', {'id': int.tryParse(id) ?? id});
  }

  static Future<void> hideAll() async {
    await _call('/v2/notifications/hide_all', const {});
  }

  static Future<List<NotificationInboxCategory>> categories() async {
    final data = await _call('/v2/notifications/categories', const {});
    if (data is! List) return const [];
    final rows = data
        .whereType<Map>()
        .map((row) => NotificationInboxCategory.fromMap(Map<String, dynamic>.from(row)))
        .toList();
    rows.sort((a, b) => a.sequence.compareTo(b.sequence));
    return rows;
  }

  static Future<void> setMuted(String code, bool muted) async {
    await _call('/v2/notifications/preferences/update', {
      'category_code': code,
      'muted': muted,
    });
  }

  /// Bell badge from the server unread count. Used while inbox v2 is on.
  static Future<int> refreshBadge() async {
    final count = await unreadCount();
    await NotificationStorageService.applyServerUnread(count);
    return count;
  }

  static Future<dynamic> _call(String path, Map<String, dynamic> params) async {
    final response = await http
        .post(
          Uri.parse('${NotificationApiService.baseUrl}$path'),
          headers: NotificationApiService.headers(),
          body: jsonEncode({
            'jsonrpc': '2.0',
            'method': 'call',
            'params': params,
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Notification request failed');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return null;
    final result = decoded['result'];
    if (result is! Map) return null;
    if ('${result['status']}' == 'error') {
      throw Exception('${result['message'] ?? 'Notification request failed'}');
    }
    return result['data'] ?? result;
  }

  static String _day(DateTime value) {
    final local = DateTime(value.year, value.month, value.day);
    return local.toIso8601String().split('T').first;
  }
}

bool _bool(dynamic value) {
  if (value is bool) return value;
  final text = (value ?? '').toString().trim().toLowerCase();
  return text == '1' || text == 'true' || text == 'yes';
}

bool get notificationInboxV2Enabled =>
    NotificationConfigService.current.appInboxV2;
