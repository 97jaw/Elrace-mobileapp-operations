import 'dart:convert';

import 'package:el_race/core/services/notification_api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationStorageService {
  static const String _notificationsKey = 'stored_notifications';
  static const String _unreadCountKey = 'unread_notification_count';
  static const String _badgeAckAtKey = 'notification_badge_ack_at_iso';
  static const String _badgeUnreadBaselineKey =
      'notification_badge_unread_baseline_v1';
  static const String _muteSettingsKey = 'notification_mute_settings_v1';
  static const String _muteSettingsFetchedAtKey =
      'notification_mute_settings_v1_fetched_at';
  static const String _categoriesKey = 'notification_categories_v1';
  static const String _categoriesFetchedAtKey =
      'notification_categories_v1_fetched_at';

  static const Duration _muteSettingsCacheTtl = Duration(minutes: 5);
  static const Duration _categoriesCacheTtl = Duration(minutes: 5);
  /// Avoid hammering /notifications when Odoo/proxy returns 5xx (home polls every 5s).
  static const Duration _badgeSyncFailureCooldown = Duration(seconds: 60);

  static Map<String, bool>? _memoryMuteSettings;
  static DateTime? _memoryMuteSettingsFetchedAt;
  static List<NotificationCategoryApiModel>? _memoryCategories;
  static DateTime? _memoryCategoriesFetchedAt;
  static DateTime? _badgeSyncCooldownUntil;
  static DateTime? _lastBadgeSyncFailureLoggedAt;
  static bool _badgeSyncInFlight = false;

  /// Callback to notify when notification count changes.
  static void Function()? onCountChanged;

  /// Fast badge count from local cache (no API call).
  /// Use this for real-time badge updates (e.g. after a push notification
  /// is saved locally) to avoid a race condition where the API has not yet
  /// indexed the new notification.
  static Future<int> getLocalStoredCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_unreadCountKey) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static String _normalizeKey(String value) {
    return value.trim().toLowerCase();
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value.toString().trim().toLowerCase() == 'true';
  }

  static DateTime? _readFetchedAt(SharedPreferences prefs) {
    final millis = prefs.getInt(_muteSettingsFetchedAtKey);
    if (millis == null || millis <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  static bool _isFresh(DateTime? fetchedAt, DateTime now) {
    if (fetchedAt == null) return false;
    return now.difference(fetchedAt) <= _muteSettingsCacheTtl;
  }

  static Map<String, bool> _readCachedMuteSettings(SharedPreferences prefs) {
    final raw = prefs.getString(_muteSettingsKey);
    if (raw == null || raw.trim().isEmpty) {
      return <String, bool>{};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, bool>{};
      }

      final result = <String, bool>{};
      for (final entry in decoded.entries) {
        final key = _normalizeKey(entry.key.toString());
        if (key.isEmpty) continue;
        result[key] = _asBool(entry.value);
      }
      return result;
    } catch (_) {
      return <String, bool>{};
    }
  }

  static String _humanizeCategory(String value) {
    final text = value.trim();
    if (text.isEmpty) return 'Notification';

    final parts = text
        .split(RegExp(r'[._-]+'))
        .where((part) => part.trim().isNotEmpty)
        .map((part) {
      final p = part.trim();
      return '${p[0].toUpperCase()}${p.substring(1)}';
    }).toList(growable: false);

    if (parts.isEmpty) return 'Notification';
    return parts.join(' ');
  }

  static List<NotificationCategoryApiModel> _readCachedCategories(
    SharedPreferences prefs,
  ) {
    final raw = prefs.getString(_categoriesKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <NotificationCategoryApiModel>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <NotificationCategoryApiModel>[];
      }

      final items = <NotificationCategoryApiModel>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item.cast<String, dynamic>());
        final model = _normalizeKey('${map['model'] ?? ''}');
        if (model.isEmpty) continue;

        items.add(
          NotificationCategoryApiModel(
            model: model,
            title: (map['title'] ?? '').toString().trim().isEmpty
                ? _humanizeCategory(model)
                : map['title'].toString().trim(),
          ),
        );
      }

      return items;
    } catch (_) {
      return const <NotificationCategoryApiModel>[];
    }
  }

  static Future<void> _writeCachedCategories(
    SharedPreferences prefs,
    List<NotificationCategoryApiModel> categories,
  ) async {
    final now = DateTime.now();
    final normalized = <NotificationCategoryApiModel>[];
    final seen = <String>{};

    for (final item in categories) {
      final model = _normalizeKey(item.model);
      if (model.isEmpty || seen.contains(model)) continue;
      seen.add(model);
      normalized.add(
        NotificationCategoryApiModel(
          model: model,
          title: item.title.trim().isEmpty
              ? _humanizeCategory(model)
              : item.title.trim(),
        ),
      );
    }

    await prefs.setString(
      _categoriesKey,
      jsonEncode(normalized.map((e) => e.toMap()).toList(growable: false)),
    );
    await prefs.setInt(_categoriesFetchedAtKey, now.millisecondsSinceEpoch);

    _memoryCategories = List<NotificationCategoryApiModel>.from(normalized);
    _memoryCategoriesFetchedAt = now;
  }

  static Future<void> _writeCachedMuteSettings(
    SharedPreferences prefs,
    Map<String, bool> settings,
  ) async {
    final normalized = <String, bool>{};
    for (final entry in settings.entries) {
      final key = _normalizeKey(entry.key);
      if (key.isEmpty) continue;
      normalized[key] = entry.value;
    }

    final now = DateTime.now();
    await prefs.setString(_muteSettingsKey, jsonEncode(normalized));
    await prefs.setInt(_muteSettingsFetchedAtKey, now.millisecondsSinceEpoch);

    _memoryMuteSettings = Map<String, bool>.from(normalized);
    _memoryMuteSettingsFetchedAt = now;
  }

  static Future<Map<String, bool>> getMuteSettings({
    bool forceRefresh = false,
    bool allowNetwork = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    if (!forceRefresh &&
        _memoryMuteSettings != null &&
        _isFresh(_memoryMuteSettingsFetchedAt, now)) {
      return Map<String, bool>.from(_memoryMuteSettings!);
    }

    final cachedSettings = _readCachedMuteSettings(prefs);
    final cachedFetchedAt = _readFetchedAt(prefs);

    if (!forceRefresh &&
        cachedSettings.isNotEmpty &&
        _isFresh(cachedFetchedAt, now)) {
      _memoryMuteSettings = Map<String, bool>.from(cachedSettings);
      _memoryMuteSettingsFetchedAt = cachedFetchedAt;
      return cachedSettings;
    }

    // Background isolates / offline: use last known prefs (even if stale).
    if (!allowNetwork) {
      if (cachedSettings.isNotEmpty) {
        _memoryMuteSettings = Map<String, bool>.from(cachedSettings);
        _memoryMuteSettingsFetchedAt = cachedFetchedAt ?? now;
        return cachedSettings;
      }
      return <String, bool>{};
    }

    try {
      final remoteSettings =
          await NotificationApiService.getNotificationPreferences();
      // Preserve local-only mute keys when replacing cache from API.
      final previous = _readCachedMuteSettings(prefs);
      const localOnly = {'chat_message', 'task', 'adhan', 'prayer'};
      final merged = Map<String, bool>.from(remoteSettings);
      for (final key in localOnly) {
        if (previous.containsKey(key) && !merged.containsKey(key)) {
          merged[key] = previous[key]!;
        }
      }
      await _writeCachedMuteSettings(prefs, merged);
      return Map<String, bool>.from(merged);
    } catch (e) {
      if (cachedSettings.isNotEmpty) {
        _memoryMuteSettings = Map<String, bool>.from(cachedSettings);
        _memoryMuteSettingsFetchedAt = cachedFetchedAt;
        return cachedSettings;
      }
      if (forceRefresh) {
        throw Exception('Unable to fetch notification preferences: $e');
      }
      return <String, bool>{};
    }
  }

  static Future<List<NotificationCategoryApiModel>> getNotificationCategories({
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    if (!forceRefresh &&
        _memoryCategories != null &&
        _isFresh(_memoryCategoriesFetchedAt, now)) {
      return List<NotificationCategoryApiModel>.from(_memoryCategories!);
    }

    final cachedCategories = _readCachedCategories(prefs);
    final cachedFetchedAt = _readFetchedAtCategories(prefs);

    if (!forceRefresh &&
        cachedCategories.isNotEmpty &&
        _isFresh(cachedFetchedAt, now)) {
      _memoryCategories = List<NotificationCategoryApiModel>.from(
        cachedCategories,
      );
      _memoryCategoriesFetchedAt = cachedFetchedAt;
      return cachedCategories;
    }

    try {
      final remoteCategories =
          await NotificationApiService.getNotificationCategories();
      if (remoteCategories.isNotEmpty) {
        await _writeCachedCategories(prefs, remoteCategories);
        return List<NotificationCategoryApiModel>.from(remoteCategories);
      }
    } catch (_) {
      // Fallback below.
    }

    if (cachedCategories.isNotEmpty) {
      _memoryCategories = List<NotificationCategoryApiModel>.from(
        cachedCategories,
      );
      _memoryCategoriesFetchedAt = cachedFetchedAt;
      return cachedCategories;
    }

    // Last fallback: infer categories from already stored notifications.
    final allNotifications = await _getStoredNotifications();
    final inferred = <String, NotificationCategoryApiModel>{};
    for (final item in allNotifications) {
      final model = _normalizeKey('${item['category'] ?? ''}');
      if (model.isEmpty) continue;
      inferred[model] = NotificationCategoryApiModel(
        model: model,
        title: _humanizeCategory(model),
      );
    }

    if (inferred.isEmpty) {
      inferred['notification'] = const NotificationCategoryApiModel(
        model: 'notification',
        title: 'Notifications',
      );
    }

    final fallback = inferred.values.toList(growable: false)
      ..sort((a, b) => a.title.compareTo(b.title));
    await _writeCachedCategories(prefs, fallback);
    return fallback;
  }

  static DateTime? _readFetchedAtCategories(SharedPreferences prefs) {
    final millis = prefs.getInt(_categoriesFetchedAtKey);
    if (millis == null || millis <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  static Future<void> setMuteSetting(String channel, bool muted) async {
    final key = _normalizeKey(channel);
    if (key.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final previous = await getMuteSettings();
    final currentValue = previous[key] == true;
    if (currentValue == muted) return;

    final optimistic = Map<String, bool>.from(previous)..[key] = muted;
    await _writeCachedMuteSettings(prefs, optimistic);

    try {
      final apiResponse =
          await NotificationApiService.updateNotificationPreference(
        model: key,
        muted: muted,
      );
      print('[MuteSettings][UpdateResponse][$key] $apiResponse');
      await _updateUnreadCount();
      onCountChanged?.call();
    } catch (e) {
      await _writeCachedMuteSettings(prefs, previous);
      throw Exception('Unable to update notification preference: $e');
    }
  }

  /// حفظ إعداد كتم محلي فقط (بدون مزامنة مع الـ API).
  /// يُستخدم للفئات المحلية مثل chat_message, task, adhan.
  static Future<void> setLocalMuteSetting(String channel, bool muted) async {
    final key = _normalizeKey(channel);
    if (key.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final previous = await getMuteSettings();
    final currentValue = previous[key] == true;
    if (currentValue == muted) return;

    final optimistic = Map<String, bool>.from(previous)..[key] = muted;
    await _writeCachedMuteSettings(prefs, optimistic);
  }

  static Future<bool> isChannelMuted(String channel) async {
    final key = _normalizeKey(channel);
    if (key.isEmpty) return false;
    final settings = await getMuteSettings();
    return settings[key] == true;
  }

  static Future<bool> shouldMuteNotification({
    String? category,
    Map<String, dynamic>? data,
    bool allowNetwork = true,
  }) async {
    final settings = await getMuteSettings(allowNetwork: allowNetwork);
    if (settings.isEmpty) return false;

    // Shared Waiting mute covers all approval FCM models.
    const waitingApprovalModels = <String>{
      'waiting',
      'employee.requests',
      'account.move',
      'purchase.order',
      'hr.expense.sheet',
    };

    final candidates = <String>[
      if (category != null) category,
      if (data != null) ...[
        '${data['category'] ?? ''}',
        '${data['type'] ?? ''}',
        '${data['model'] ?? ''}',
        '${data['model_name'] ?? ''}',
        '${data['record_type'] ?? ''}',
        '${data['target_type'] ?? ''}',
      ],
    ];

    final normalized = <String>[];
    for (final candidate in candidates) {
      final key = _normalizeKey(candidate);
      if (key.isNotEmpty) normalized.add(key);
    }

    if (settings['waiting'] == true) {
      for (final key in normalized) {
        if (waitingApprovalModels.contains(key)) {
          return true;
        }
      }
    }

    // Safety / Alerts mute covers weather, summer, safety pushes.
    const alertCoveredModels = <String>{
      'alert',
      'weather',
      'safety',
      'summer',
    };
    if (settings['alert'] == true) {
      for (final key in normalized) {
        if (alertCoveredModels.contains(key)) {
          return true;
        }
      }
    }

    // Projects mute covers assigned + completed.
    const projectCoveredModels = <String>{
      'project_open',
      'project_completed',
    };
    if (settings['project_open'] == true ||
        settings['project_completed'] == true) {
      for (final key in normalized) {
        if (projectCoveredModels.contains(key)) {
          return true;
        }
      }
    }

    for (final key in normalized) {
      if (settings[key] == true) {
        return true;
      }
    }

    return false;
  }

  /// Save a new notification locally.
  static Future<void> saveNotification({
    required String title,
    required String body,
    String? imageUrl,
    Map<String, dynamic>? data,
    String? category,
  }) async {
    try {
      final notificationCategory = _normalizeKey(category ??
          '${data?['category'] ?? data?['type'] ?? 'notification'}');

      final shouldMute = await shouldMuteNotification(
        category: notificationCategory,
        data: data,
      );
      if (shouldMute) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      var notifications = await _getStoredNotifications();

      // Prefer unique per-delivery ids. Never key only on record_id — reusing
      // the same approval/record silently skipped badge bumps on iOS.
      final serverId = (data?['notification_user_id'] ??
              data?['notification_id'] ??
              data?['fcm_message_id'] ??
              data?['message_id'] ??
              '')
          .toString()
          .trim();
      final id = serverId.isNotEmpty
          ? serverId
          : 'fcm_${DateTime.now().millisecondsSinceEpoch}';

      // Avoid duplicates when the same push is delivered more than once.
      final existingIndex =
          notifications.indexWhere((n) => '${n['id'] ?? ''}' == id);
      if (existingIndex != -1) {
        return;
      }

      notifications.insert(0, {
        'id': id,
        'title': title,
        'body': body,
        'imageUrl': imageUrl,
        'data': data,
        'category': notificationCategory.isEmpty
            ? 'notification'
            : notificationCategory,
        'timestamp': DateTime.now().toIso8601String(),
        'isRead': false,
        'is_read': false,
        'source': 'fcm',
      });

      if (notifications.length > 100) {
        notifications = notifications.sublist(0, 100);
      }

      await _saveStoredNotifications(notifications, prefs);
      // LinkedIn-style: only bump badge for newly arrived pushes.
      await _incrementBadge();
    } catch (_) {
      // Keep silent to avoid crashing push pipeline.
    }
  }

  static bool _sameContent(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final titleA = (a['title'] ?? '').toString().trim();
    final titleB = (b['title'] ?? '').toString().trim();
    final bodyA = (a['body'] ?? '').toString().trim();
    final bodyB = (b['body'] ?? '').toString().trim();
    return titleA.isNotEmpty && titleA == titleB && bodyA == bodyB;
  }

  static List<Map<String, dynamic>> _pageOf(
    List<Map<String, dynamic>> items, {
    required int limit,
    required int offset,
  }) {
    if (limit <= 0) return List<Map<String, dynamic>>.from(items);
    if (offset >= items.length) return const <Map<String, dynamic>>[];
    final end = offset + limit;
    final boundedEnd = end > items.length ? items.length : end;
    return items.sublist(offset, boundedEnd);
  }

  /// Get notifications. Merges API + local FCM cache so push items always show.
  static Future<List<Map<String, dynamic>>> getNotifications({
    int limit = 500,
    int offset = 0,
  }) async {
    try {
      final apiResult = await NotificationApiService.getNotifications(
        limit: limit,
        offset: offset,
      );

      final normalized = apiResult.notifications
          .map(_normalizeApiNotification)
          .toList(growable: true);

      final prefs = await SharedPreferences.getInstance();
      final storedBeforeFetch = await _getStoredNotifications();
      final locallyReadIds = <String>{
        for (final item in storedBeforeFetch)
          if (item['isRead'] == true || item['is_read'] == true)
            '${item['id'] ?? ''}',
      }..removeWhere((id) => id.isEmpty);

      for (final notification in normalized) {
        final id = '${notification['id'] ?? ''}';
        if (id.isNotEmpty && locallyReadIds.contains(id)) {
          notification['isRead'] = true;
          notification['is_read'] = true;
        }
      }

      if (offset <= 0) {
        final mergedNotifications = <Map<String, dynamic>>[];
        final seenIds = <String>{};

        // Keep recent local/FCM rows first so they appear immediately.
        for (final localNotif in storedBeforeFetch) {
          final id = '${localNotif['id'] ?? ''}';
          final isLocalOnly = localNotif['source'] == 'fcm' ||
              !normalized.any((api) =>
                  '${api['id'] ?? ''}' == id || _sameContent(api, localNotif));
          if (!isLocalOnly) continue;
          if (id.isNotEmpty && seenIds.contains(id)) continue;
          if (normalized.any((api) => _sameContent(api, localNotif))) {
            continue;
          }
          mergedNotifications.add(Map<String, dynamic>.from(localNotif));
          if (id.isNotEmpty) seenIds.add(id);
        }

        for (final notification in normalized) {
          final id = '${notification['id'] ?? ''}';
          if (id.isNotEmpty && seenIds.contains(id)) continue;
          mergedNotifications.add(notification);
          if (id.isNotEmpty) seenIds.add(id);
        }

        await _saveStoredNotifications(mergedNotifications, prefs);
        // Do not recompute bell badge from unread rows — badge is
        // "new since last open" and is cleared via acknowledgeBadge().
        return _pageOf(mergedNotifications, limit: limit, offset: 0);
      }

      final storedNotifications = await _getStoredNotifications();
      final mergedNotifications =
          List<Map<String, dynamic>>.from(storedNotifications);
      final existingIds = mergedNotifications
          .map((notification) => '${notification['id'] ?? ''}')
          .where((id) => id.isNotEmpty)
          .toSet();

      for (final notification in normalized) {
        final id = '${notification['id'] ?? ''}';
        if (id.isNotEmpty && existingIds.contains(id)) continue;
        if (mergedNotifications.any((local) => _sameContent(local, notification))) {
          continue;
        }
        mergedNotifications.add(notification);
        if (id.isNotEmpty) existingIds.add(id);
      }

      await _saveStoredNotifications(mergedNotifications, prefs);
      return normalized;
    } catch (_) {
      final storedNotifications = await _getStoredNotifications();
      return _pageOf(storedNotifications, limit: limit, offset: offset);
    }
  }

  /// Home bell badge = new notifications since last Notification Center open.
  static Future<int> getBadgeCount() async {
    return getLocalStoredCount();
  }

  /// Refresh home bell as `max(0, serverUnread - unreadAtLastOpen)`.
  ///
  /// This matches Android LinkedIn-style behavior without depending on iOS
  /// waking Dart for FCM, and without treating old opened rows as new.
  ///
  /// Failures (e.g. HTTP 502) are non-fatal: returns the local badge and
  /// cools down so periodic home polls do not spam the API/logs.
  static Future<int> syncBadgeFromServer() async {
    final now = DateTime.now();
    final cooldownUntil = _badgeSyncCooldownUntil;
    if (cooldownUntil != null && now.isBefore(cooldownUntil)) {
      return getLocalStoredCount();
    }
    if (_badgeSyncInFlight) {
      return getLocalStoredCount();
    }

    _badgeSyncInFlight = true;
    try {
      final result = await NotificationApiService.getNotifications(
        limit: 1,
        offset: 0,
      );
      _badgeSyncCooldownUntil = null;
      _lastBadgeSyncFailureLoggedAt = null;

      final unread = result.unreadCount;
      if (unread == null) {
        return getLocalStoredCount();
      }

      final prefs = await SharedPreferences.getInstance();
      final baseline = prefs.getInt(_badgeUnreadBaselineKey);
      final remoteBadge =
          baseline == null ? unread : (unread - baseline < 0 ? 0 : unread - baseline);

      final previous = prefs.getInt(_unreadCountKey) ?? 0;
      // Raise to server-computed "new since open". Keep a higher local value
      // briefly so a foreground FCM bump is not wiped before Odoo indexes.
      final next = remoteBadge > previous ? remoteBadge : previous;
      if (next != previous) {
        await prefs.setInt(_unreadCountKey, next);
        onCountChanged?.call();
      }
      return next;
    } catch (e) {
      _badgeSyncCooldownUntil = now.add(_badgeSyncFailureCooldown);
      final shouldLog = _lastBadgeSyncFailureLoggedAt == null ||
          now.difference(_lastBadgeSyncFailureLoggedAt!) >=
              _badgeSyncFailureCooldown;
      if (shouldLog) {
        _lastBadgeSyncFailureLoggedAt = now;
        debugPrint(
          '⚠️ syncBadgeFromServer failed (using local badge; '
          'retry in ${_badgeSyncFailureCooldown.inSeconds}s): $e',
        );
      }
      return getLocalStoredCount();
    } finally {
      _badgeSyncInFlight = false;
    }
  }

  static Future<void> _incrementBadge([int by = 1]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final previous = prefs.getInt(_unreadCountKey) ?? 0;
      final next = previous + by;
      await prefs.setInt(_unreadCountKey, next);
      if (previous != next) {
        onCountChanged?.call();
      }
    } catch (_) {}
  }

  static Future<void> _decrementBadge([int by = 1]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final previous = prefs.getInt(_unreadCountKey) ?? 0;
      final next = previous - by;
      final clamped = next < 0 ? 0 : next;
      await prefs.setInt(_unreadCountKey, clamped);
      if (previous != clamped) {
        onCountChanged?.call();
      }
    } catch (_) {}
  }

  /// Get unread notification count — prefers accurate local cache.
  static Future<int> getTotalCount() async {
    return getBadgeCount();
  }

  static Map<String, dynamic> _normalizeApiNotification(
    Map<String, dynamic> raw,
  ) {
    final normalized = Map<String, dynamic>.from(raw);

    dynamic notificationData = raw['data'] ?? raw['payload'];
    if (notificationData is String && notificationData.trim().isNotEmpty) {
      try {
        notificationData = jsonDecode(notificationData);
      } catch (_) {
        // Keep original value.
      }
    }

    final rawRead = raw['is_read'] ?? raw['isRead'] ?? false;
    final isRead = rawRead == true ||
        rawRead == 1 ||
        rawRead.toString().toLowerCase() == 'true';

    normalized['id'] =
        (raw['id'] ?? DateTime.now().millisecondsSinceEpoch).toString();
    normalized['title'] =
        (raw['title'] ?? raw['subject'] ?? 'Notification').toString();
    normalized['body'] = (raw['body'] ?? raw['message'] ?? '').toString();
    normalized['imageUrl'] = raw['image_url'] ?? raw['imageUrl'];
    normalized['data'] = notificationData;
    normalized['payload'] = notificationData;
    normalized['category'] = _normalizeKey(
      '${raw['category'] ?? raw['type'] ?? (notificationData is Map ? notificationData['model'] : null) ?? 'notification'}',
    );
    normalized['timestamp'] = (raw['created_at'] ??
            raw['timestamp'] ??
            raw['date'] ??
            raw['sent_at'] ??
            '')
        .toString();
    normalized['timeAgo'] =
        (raw['time_ago'] ?? raw['timeAgo'] ?? '').toString();
    normalized['isRead'] = isRead;
    normalized['readAt'] = raw['read_at'] ?? raw['readAt'];

    return normalized;
  }

  static Future<List<Map<String, dynamic>>> _getStoredNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_notificationsKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveStoredNotifications(
    List<Map<String, dynamic>> notifications,
    SharedPreferences prefs,
  ) async {
    final jsonString = jsonEncode(notifications);
    await prefs.setString(_notificationsKey, jsonString);
  }

  /// Mark a single notification as read.
  static Future<void> markAsRead(String notificationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notifications = await _getStoredNotifications();

      final index = notifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) {
        final wasUnread = notifications[index]['isRead'] != true &&
            notifications[index]['is_read'] != true;
        notifications[index]['isRead'] = true;
        notifications[index]['is_read'] = true;
        notifications[index]['readAt'] = DateTime.now().toIso8601String();
        await _saveStoredNotifications(notifications, prefs);
        // Do not recount all unread into the bell badge.
        if (wasUnread) {
          await _decrementBadge();
        }
      }

      await NotificationApiService.markAsRead(notificationId);
    } catch (_) {
      // Local state has already been updated when possible.
    }
  }

  /// Clears the home badge and snapshots server unread as the baseline.
  /// New bell count = serverUnread - baseline (only notifications after open).
  static Future<void> acknowledgeBadge({Iterable<String>? knownIds}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      var baseline = prefs.getInt(_badgeUnreadBaselineKey) ?? 0;
      try {
        final result = await NotificationApiService.getNotifications(
          limit: 1,
          offset: 0,
        );
        if (result.unreadCount != null) {
          baseline = result.unreadCount!;
        }
      } catch (_) {
        // Keep previous baseline if offline.
      }

      await prefs.setInt(_badgeUnreadBaselineKey, baseline);
      await prefs.setInt(_unreadCountKey, 0);
      await prefs.setString(
        _badgeAckAtKey,
        DateTime.now().toUtc().toIso8601String(),
      );
      // knownIds kept for API compatibility; baseline is the source of truth.
      onCountChanged?.call();
    } catch (_) {
      // Ignore badge-only failures.
    }
  }

  /// Mark all notifications in a category as read — local first, API in background.
  static Future<void> markCategoryAsRead(String category) async {
    final selected = _normalizeKey(category);
    if (selected.isEmpty ||
        selected == 'all' ||
        selected == '__all__') {
      await markAllAsRead();
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final notifications = await _getStoredNotifications();
      final idsToSync = <String>[];

      for (final notification in notifications) {
        final cat = _normalizeKey('${notification['category'] ?? ''}');
        if (cat != selected || notification['isRead'] == true) continue;
        notification['isRead'] = true;
        notification['is_read'] = true;
        notification['readAt'] = DateTime.now().toIso8601String();
        final id = '${notification['id'] ?? ''}';
        if (id.isNotEmpty) idsToSync.add(id);
      }

      await _saveStoredNotifications(notifications, prefs);
      // Category clear should also clear the home bell.
      await prefs.setInt(_unreadCountKey, 0);
      onCountChanged?.call();

      if (idsToSync.isNotEmpty) {
        _syncReadIdsToApiInBackground(idsToSync);
      }
    } catch (_) {
      // Keep UI stable.
    }
  }

  static void _syncReadIdsToApiInBackground(List<String> ids) {
    Future<void>(() async {
      await Future.wait(
        ids.map(NotificationApiService.markAsRead),
        eagerError: false,
      );
    });
  }

  /// Mark all notifications as read — local update is immediate; API runs after.
  static Future<void> markAllAsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notifications = await _getStoredNotifications();

      for (final notification in notifications) {
        notification['isRead'] = true;
        notification['is_read'] = true;
        notification['readAt'] = DateTime.now().toIso8601String();
      }

      await _saveStoredNotifications(notifications, prefs);
      await prefs.setInt(_unreadCountKey, 0);
      onCountChanged?.call();

      Future<void>(() async {
        await NotificationApiService.markAllAsRead();
      });
    } catch (_) {
      // Ignore to keep UI stable.
    }
  }

  /// Get unread notification count for APIs that need list unread totals.
  /// Home bell must use [getBadgeCount] / [getLocalStoredCount] instead.
  static Future<int> getUnreadCount() async {
    try {
      final apiUnreadCount = await NotificationApiService.getUnreadCount();
      if (apiUnreadCount != null) {
        return apiUnreadCount;
      }
    } catch (_) {
      // Fallback to local cache below.
    }

    try {
      final notifications = await _getStoredNotifications();
      return notifications
          .where((n) => n['isRead'] != true && n['is_read'] != true)
          .length;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> _updateUnreadCount() async {
    // Deprecated path for mute updates — do not overwrite LinkedIn-style badge
    // with total unread list size.
    onCountChanged?.call();
  }

  /// Delete a notification from local cache and sync to API.
  static Future<void> deleteNotification(String notificationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notifications = await _getStoredNotifications();

      final index = notifications
          .indexWhere((n) => '${n['id'] ?? ''}' == notificationId);
      final wasUnread = index != -1 &&
          notifications[index]['isRead'] != true &&
          notifications[index]['is_read'] != true;

      notifications.removeWhere((n) => '${n['id'] ?? ''}' == notificationId);

      await _saveStoredNotifications(notifications, prefs);

      // Await backend delete so a refresh does not resurrect the row.
      try {
        await NotificationApiService.deleteNotification(notificationId);
      } catch (_) {}

      // Only reduce the bell if it still has "new since open" count.
      if (wasUnread) {
        await _decrementBadge();
      } else {
        onCountChanged?.call();
      }
    } catch (_) {
      // Ignore failures.
    }
  }

  /// Get notifications by category.
  static Future<List<Map<String, dynamic>>> getNotificationsByCategory(
    String category,
  ) async {
    try {
      final allNotifications = await getNotifications();
      final selected = _normalizeKey(category);
      if (selected == 'all') {
        return allNotifications;
      }

      return allNotifications.where((notification) {
        final itemCategory = _normalizeKey('${notification['category'] ?? ''}');
        return itemCategory == selected;
      }).toList(growable: false);
    } catch (_) {
      return [];
    }
  }

  /// Clear all local notifications and sync delete-all to API.
  static Future<void> clearAll() async {
    try {
      try {
        final cleared = await NotificationApiService.clearAllNotifications();
        if (!cleared) {
          await NotificationApiService.markAllAsRead();
        }
      } catch (_) {}

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_notificationsKey);
      await prefs.setInt(_unreadCountKey, 0);
      onCountChanged?.call();
    } catch (_) {
      // Ignore failures.
    }
  }

  /// Add sample notifications for testing.
  static Future<void> addSampleNotifications() async {
    await saveNotification(
      title: 'Leave Approved',
      body: 'Your leave request from Jan 15 to Jan 20 has been approved.',
      category: 'notification',
    );

    await saveNotification(
      title: 'Attendance Reminder',
      body: 'Please ensure to check in before 9:00 AM.',
      category: 'notification',
    );

    await saveNotification(
      title: 'New Project Launch',
      body:
          'We are excited to announce the launch of Abu Dhabi Dialysis Center project.',
      category: 'announcement',
    );

    await saveNotification(
      title: 'Company Meeting',
      body: 'All staff meeting scheduled for tomorrow at 10:00 AM.',
      category: 'announcement',
    );

    await saveNotification(
      title: 'Safety Guidelines',
      body:
          'Please review the updated safety guidelines for construction sites.',
      category: 'circular',
    );

    await saveNotification(
      title: 'Policy Update',
      body: 'New HR policies effective from next month. Please read carefully.',
      category: 'circular',
    );
  }
}
