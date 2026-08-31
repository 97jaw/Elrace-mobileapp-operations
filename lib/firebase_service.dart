import 'dart:async';
import 'dart:convert';

import 'package:el_race/chat/models/models.dart';
import 'package:el_race/core/app_globals.dart';
import 'package:el_race/core/services/attendance_status_sync_service.dart';
import 'package:el_race/core/services/notification_storage_service.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/data/services/prayer_audio_service.dart';
import 'package:el_race/ui/chat/chat_screen.dart';
import 'package:el_race/ui/presentation/tasks/tasks_screen.dart';
import 'package:el_race/ui/presentation/tasks_dashboard/screens/task_details.dart'
    as firebase_task_details;
import 'package:el_race/utils/string_utils.dart';
import 'package:el_race/utils/urll_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

// Prevent device identifiers from reaching production logs while preserving
// the existing token retrieval and storage flow.
void print(Object? message) {
  final text = message?.toString() ?? '';
  final lower = text.toLowerCase();
  if (lower.contains('fcm token') ||
      lower.contains('apns token') ||
      lower.contains('device token')) {
    return;
  }
  debugPrint(text);
}

class FirebaseService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // Track processed notification message IDs to avoid duplicate handling
  static final Set<String> _processedMessageIds = {};
  static String? _pendingChatTapPayload;
  static bool _isHandlingChatTap = false;
  static bool _isHomeReady = false;
  static String? _lastSyncedOdooToken;
  static DateTime? _lastOdooSyncAt;
  static const String _lastSyncedOdooTokenKey = 'fcm_token_synced_odoo';
  static const Duration _odooSyncMinInterval = Duration(minutes: 5);
  static Future<void>? _initializeFuture;

  /// Call this after splash/home is ready so queued chat-notification taps can
  /// be replayed with a valid app context.
  static void markHomeReady() {
    _isHomeReady = true;
    processPendingNotificationTap();
  }

  /// Call this when the app returns to splash and chat taps must wait again.
  static void markHomeNotReady() {
    _isHomeReady = false;
  }

  static Future<void> initialize({
    bool requestPermissions = true,
    bool fetchToken = true,
  }) async {
    // G9: once-guard — listeners must not be attached twice.
    if (_initializeFuture != null) {
      await _initializeFuture;
      if (requestPermissions) {
        await requestNotificationPermissions();
      }
      if (fetchToken) {
        await _fetchAndStoreFcmToken();
      }
      return;
    }
    _initializeFuture = _initializeBody(
      requestPermissions: requestPermissions,
      fetchToken: fetchToken,
    );
    await _initializeFuture;
  }

  static Future<void> _initializeBody({
    required bool requestPermissions,
    required bool fetchToken,
  }) async {
    await _firebaseMessaging.setAutoInitEnabled(true);

    // Permission prompts are slow on iOS and must NOT gate splash navigation.
    // Critical startup calls initialize(requestPermissions: false, fetchToken: false).
    if (requestPermissions) {
      await requestNotificationPermissions();
    }

    // Initialize local notifications (for showing notifications in foreground)
    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings iosInitSettings =
        DarwinInitializationSettings(
      // Avoid a second iOS permission prompt during critical init.
      requestAlertPermission: requestPermissions,
      requestBadgePermission: requestPermissions,
      requestSoundPermission: requestPermissions,
    );

    final initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: iosInitSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        print("🔔 [LOCAL NOTIFICATION TAP] Notification tapped!");
        print("   - Payload: $payload");
        print("   - Action ID: ${response.actionId}");
        print("   - Notification ID: ${response.id}");
        // General notifications are view-only. Chat notifications still open
        // their conversation.
        _handleNotificationTap(payload);
      },
    );

    // Create the high_importance_channel used by FCM foreground notifications.
    // Without this, Android 8+ silently drops or demotes notifications because
    // the channel referenced in AndroidManifest meta-data doesn't exist.
    final androidImpl =
        _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          'high_importance_channel',
          'High Importance Notifications',
          description: 'Used for general push notifications',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );
    }

    // Do NOT auto-present FCM alerts in foreground — that bypasses mute.
    // We show via local notifications after shouldMuteNotification (G4).
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('📬 [FOREGROUND] Received message!');
      print('   - Title: ${message.notification?.title}');
      print('   - Body: ${message.notification?.body}');
      print('   - Data: ${message.data}');

      String category = 'notification';
      if (message.data.containsKey('category')) {
        category = message.data['category'].toString();
      } else if (message.data.containsKey('type')) {
        category = message.data['type'].toString();
      } else if (message.data.containsKey('model')) {
        category = message.data['model'].toString();
      }

      final muted = await NotificationStorageService.shouldMuteNotification(
        category: category,
        data: message.data,
      );
      if (muted) {
        print(
            '🔇 Foreground notification suppressed by mute settings: category=$category');
        return;
      }

      // Chat messages: ChatNotificationService already shows a local banner
      // (with active-chat + per-chat mute). Skip FCM local to avoid doubles.
      final isChatMessage = category == 'chat_message' ||
          category == 'chat' ||
          message.data.containsKey('chat_id') ||
          message.data.containsKey('chatId');
      if (isChatMessage) {
        print(
            '💬 Foreground chat FCM skipped (ChatNotificationService owns UI)');
        await _saveNotificationToStorage(message);
        return;
      }

      // Android + iOS: local notification path (mute-aware).
      await _showNotification(message);

      // Save notification to storage (await to ensure badge count
      // is persisted before the onCountChanged callback fires).
      await _saveNotificationToStorage(message);
      // iOS often delivers alert pushes without a reliable local bump — sync
      // unread-since-open from Odoo so the home bell updates immediately.
      await NotificationStorageService.syncBadgeFromServer();

      await _refreshAttendanceFromPushIfNeeded(
        message,
        source: 'foreground',
      );
    });

    // Handle background-tap messages (when app is resumed from notification)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      final messageId = message.messageId ?? message.data.toString();
      print('📲 [BACKGROUND TAP] App opened from notification!');
      print('   - Message ID: $messageId');
      print('   - Title: ${message.notification?.title}');
      print('   - Data: ${message.data}');

      // Check if already processed
      if (_processedMessageIds.contains(messageId)) {
        print('   - ⚠️ Message already processed, ignoring');
        return;
      }

      _processedMessageIds.add(messageId);
      print(
          '   - ✅ Processing message (${_processedMessageIds.length} total processed)');

      // Save notification to storage if not already saved
      await _saveNotificationToStorage(message);
      await _refreshAttendanceFromPushIfNeeded(
        message,
        source: 'background_tap',
      );
      _handleNotificationTap(_buildEnrichedPayload(message));
    });

    // Check for initial message (when app is opened from terminated state)
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) async {
      if (message != null) {
        final messageId = message.messageId ?? message.data.toString();
        print('📲 [TERMINATED TAP] App opened from notification!');
        print('   - Message ID: $messageId');
        print('   - Title: ${message.notification?.title}');
        print('   - Data: ${message.data}');

        // Check if already processed
        if (_processedMessageIds.contains(messageId)) {
          print('   - ⚠️ Message already processed, ignoring');
          return;
        }

        _processedMessageIds.add(messageId);
        print(
            '   - ✅ Processing message (${_processedMessageIds.length} total processed)');

        await _saveNotificationToStorage(message);
        await _refreshAttendanceFromPushIfNeeded(
          message,
          source: 'terminated_tap',
        );
        _handleNotificationTap(_buildEnrichedPayload(message));
      } else {
        print('ℹ️ [TERMINATED] No initial message found');
      }
    });

    // Token fetch can wait for APNS (~2s+) — keep it off the splash-critical path.
    if (fetchToken) {
      await _fetchAndStoreFcmToken();
    }

    // Listen for token refresh — keep Odoo expo_token in sync (G1).
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      SharedPref().setPreferencesString(fcm_token, newToken.toString());
      if (kDebugMode) print('🔁 FCM Token refreshed');
      unawaited(syncFcmTokenToOdoo(token: newToken, force: true));
    });
  }

  /// Request notification permission (iOS prompt). Safe to call after splash.
  static Future<void> requestNotificationPermissions() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print('🔔 Notification permission status: ${settings.authorizationStatus}');
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Notification permission granted');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      print('⚠️ Provisional notification permission granted');
    } else {
      print(
          '❌ Notification permission declined: ${settings.authorizationStatus}');
    }
  }

  /// Completes deferred FCM setup after splash can navigate.
  static Future<void> completeDeferredSetup() async {
    try {
      await requestNotificationPermissions();
      await _fetchAndStoreFcmToken();
      // Restored sessions never re-login — sync token so backend can push.
      await syncFcmTokenToOdoo();
      // iOS APNS / token can arrive late after the splash deferral; retry once.
      Future<void>.delayed(const Duration(seconds: 5), () async {
        try {
          await _fetchAndStoreFcmToken();
          await syncFcmTokenToOdoo(force: true);
        } catch (_) {}
      });
    } catch (e) {
      print('⚠️ Deferred Firebase setup error: $e');
    }
  }

  /// Push current FCM token to Odoo `res.users.expo_token` via `/api/save_expo_token`.
  ///
  /// No-ops when logged out or token empty. Dedupes identical tokens within
  /// [_odooSyncMinInterval] unless [force] is true (token refresh / login).
  static Future<bool> syncFcmTokenToOdoo({
    String? token,
    bool force = false,
  }) async {
    try {
      if (!SharedPref.isUserAuthenticated()) return false;

      final authToken =
          SharedPref.getLoginDataOrNull()?.result?.token?.trim() ?? '';
      if (authToken.isEmpty) return false;

      var fcm = (token ?? SharedPref().getPreferenceString(fcm_token)).trim();
      if (fcm.isEmpty) {
        fcm = (await _firebaseMessaging.getToken() ?? '').trim();
        if (fcm.isNotEmpty) {
          SharedPref().setPreferencesString(fcm_token, fcm);
        }
      }
      if (fcm.isEmpty) return false;

      _lastSyncedOdooToken ??=
          SharedPref().getPreferenceString(_lastSyncedOdooTokenKey);
      final now = DateTime.now();
      if (!force &&
          _lastSyncedOdooToken == fcm &&
          _lastOdooSyncAt != null &&
          now.difference(_lastOdooSyncAt!) < _odooSyncMinInterval) {
        return true;
      }

      final response = await http
          .post(
            Uri.parse('${UrlUtil.baseUrl}${UrlUtil.saveExpoToken}'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({
              'jsonrpc': '2.0',
              'params': {'expo_token': fcm},
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (kDebugMode) {
          debugPrint(
            '⚠️ FCM sync HTTP ${response.statusCode}: ${response.body}',
          );
        }
        return false;
      }

      if (response.body.trim().isEmpty) {
        _rememberSyncedToken(fcm);
        return true;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final result = decoded['result'] ?? decoded;
        if (result is Map) {
          final status = '${result['status'] ?? ''}'.toLowerCase();
          final success = result['success'] == true ||
              status == 'success' ||
              status == 'ok' ||
              status == 'true';
          if (success) {
            _rememberSyncedToken(fcm);
            if (kDebugMode) {
              debugPrint('✅ FCM token synced to Odoo (save_expo_token)');
            }
            return true;
          }
          if (kDebugMode) {
            debugPrint('⚠️ FCM sync unexpected response: $result');
          }
        }
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ FCM sync to Odoo failed: $e');
      }
      return false;
    }
  }

  static void _rememberSyncedToken(String token) {
    _lastSyncedOdooToken = token;
    _lastOdooSyncAt = DateTime.now();
    SharedPref().setPreferencesString(_lastSyncedOdooTokenKey, token);
  }

  static Future<void> _fetchAndStoreFcmToken() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        print('🍎 iOS detected - waiting for APNS token...');
        await Future.delayed(const Duration(seconds: 2));

        final apnsToken = await _firebaseMessaging.getAPNSToken();
        if (apnsToken != null && apnsToken.isNotEmpty) {
          if (kDebugMode) print('🍎 APNS token available');
        } else {
          print('⚠️ APNS token unavailable during initialize');
        }
      }

      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        SharedPref().setPreferencesString(fcm_token, token);
        if (kDebugMode) print('📱 FCM Token obtained');
        unawaited(syncFcmTokenToOdoo(token: token));
      } else {
        print('❌ FCM Token is null - this may indicate APNS token issue');
      }
    } catch (e) {
      print('❌ Error getting FCM token during initialization: $e');
    }
  }

  static Future<String?> ensureFCMToken() async {
    try {
      // Check if we already have a token in SharedPreferences
      String existingToken = SharedPref().getPreferenceString(fcm_token);
      if (existingToken.isNotEmpty) {
        print(
            '📱 Using existing FCM Token: ${existingToken.substring(0, 20)}...');
        unawaited(syncFcmTokenToOdoo(token: existingToken));
        return existingToken;
      }

      // For iOS, check APNS token first
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        print('🍎 Checking APNS token availability...');
        try {
          String? apnsToken = await _firebaseMessaging.getAPNSToken();
          if (apnsToken == null) {
            print('⚠️ APNS token not available yet, waiting...');
            print('💡 This usually means:');
            print('   1. Push Notifications capability not enabled in Xcode');
            print('   2. App not signed with proper provisioning profile');
            print('   3. Running on simulator (APNS not supported)');
            print('   4. Firebase APNS configuration missing');

            // Wait and retry a few times
            for (int i = 0; i < 5; i++) {
              await Future.delayed(const Duration(seconds: 1));
              apnsToken = await _firebaseMessaging.getAPNSToken();
              if (apnsToken != null) {
                print('✅ APNS token obtained after ${i + 1} attempts');
                break;
              }
            }
            if (apnsToken == null) {
              print('❌ APNS token still not available after 5 attempts');
              print('🔧 Please check the troubleshooting steps below');
              return null;
            }
          } else {
            print(
                '✅ APNS token is available: ${apnsToken.substring(0, 20)}...');
          }
        } catch (apnsError) {
          print('❌ Error checking APNS token: $apnsError');
        }
      }

      // Try to get a new FCM token
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        SharedPref().setPreferencesString(fcm_token, token);
        print('📱 FCM Token obtained and stored: ${token.substring(0, 20)}...');
        unawaited(syncFcmTokenToOdoo(token: token));
      } else {
        print('❌ Failed to get FCM token - Firebase may not be initialized');
      }
      return token;
    } catch (e) {
      print('❌ Error getting FCM token: $e');
      print('❌ This may happen if Firebase is not properly initialized');
      return null;
    }
  }

  /// Test method to manually check FCM token generation
  static Future<void> testFCMToken() async {
    print('🧪 Testing FCM Token generation...');
    try {
      String? token = await ensureFCMToken();
      if (token != null) {
        print('✅ FCM Token test successful: ${token.substring(0, 20)}...');
      } else {
        print('❌ FCM Token test failed - no token generated');
        print('🔄 Trying alternative method...');
        await testFCMTokenAlternative();
      }
    } catch (e) {
      print('❌ FCM Token test error: $e');
    }
  }

  /// Alternative method to get FCM token without APNS dependency
  static Future<String?> testFCMTokenAlternative() async {
    print('🔄 Trying alternative FCM token retrieval...');
    try {
      // Try to get token directly without APNS check
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        print('✅ Alternative method successful: ${token.substring(0, 20)}...');
        SharedPref().setPreferencesString(fcm_token, token);
        return token;
      } else {
        print('❌ Alternative method also failed');
        return null;
      }
    } catch (e) {
      print('❌ Alternative method error: $e');
      return null;
    }
  }

  static Future<void> _showNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    final data = message.data;

    var title = (notification?.title ??
            data['title']?.toString() ??
            data['notification_title']?.toString() ??
            data['sender_name']?.toString() ??
            data['chat_title']?.toString() ??
            'Notification')
        .trim();

    var body = (notification?.body ??
            data['body']?.toString() ??
            data['message']?.toString() ??
            data['text']?.toString() ??
            '')
        .trim();

    if (title.isEmpty && body.isEmpty) {
      print('⚠️ Skipping local notification: empty title/body payload');
      return;
    }

    String category = 'notification';
    if (message.data.containsKey('category')) {
      category = message.data['category'].toString();
    } else if (message.data.containsKey('type')) {
      category = message.data['type'].toString();
    } else if (message.data.containsKey('model')) {
      category = message.data['model'].toString();
    }

    final remapped = NotificationStorageService.displayCopyForPush(
      title: title.isEmpty ? 'Notification' : title,
      body: body,
      category: category,
      data: Map<String, dynamic>.from(data),
    );
    title = remapped.$1;
    body = remapped.$2;

    final isMuted = await NotificationStorageService.shouldMuteNotification(
      category: category,
      data: message.data,
    );
    if (isMuted) {
      print(
          '🔇 Foreground notification suppressed by mute settings: category=$category');
      return;
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.high,
      priority: Priority.high,
      channelShowBadge: true,
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final notificationId = message.messageId?.hashCode ??
        '${title}_${body}_${DateTime.now().millisecondsSinceEpoch}'.hashCode;

    await _flutterLocalNotificationsPlugin.show(
      notificationId,
      title,
      body.isEmpty ? null : body,
      platformDetails,
      payload: _buildEnrichedPayload(message),
    );
  }

  static Future<void> _saveNotificationToStorage(RemoteMessage message) async {
    try {
      final notification = message.notification;
      final title = (notification?.title ??
              message.data['title'] ??
              message.data['subject'] ??
              '')
          .toString()
          .trim();
      final body = (notification?.body ??
              message.data['body'] ??
              message.data['message'] ??
              '')
          .toString()
          .trim();

      if (title.isEmpty && body.isEmpty) {
        print('⚠️ Skip saving empty FCM payload');
        return;
      }

      String category = 'notification';
      if (message.data.containsKey('category')) {
        category = message.data['category'].toString();
      } else if (message.data.containsKey('type')) {
        category = message.data['type'].toString();
      } else if (message.data.containsKey('model')) {
        category = message.data['model'].toString();
      }

      final data = Map<String, dynamic>.from(message.data);
      if (message.messageId != null && message.messageId!.isNotEmpty) {
        data.putIfAbsent('fcm_message_id', () => message.messageId);
      }

      await NotificationStorageService.saveNotification(
        title: title.isEmpty ? 'Notification' : title,
        body: body,
        imageUrl:
            notification?.android?.imageUrl ?? notification?.apple?.imageUrl,
        data: data,
        category: category,
      );
    } catch (e) {
      print('❌ Error saving notification to storage: $e');
    }
  }

  static Future<void> _refreshAttendanceFromPushIfNeeded(
    RemoteMessage message, {
    required String source,
  }) async {
    if (!_isAttendancePush(message)) {
      return;
    }

    print(
      '🕒 Attendance push trigger detected from $source. Refreshing /api/attendance/today_status',
    );

    await AttendanceStatusSyncService.refreshFromServer(
      reason: 'push_$source',
    );
  }

  static bool _isAttendancePush(RemoteMessage message) {
    final data = message.data;

    final searchSpace = <String>[
      data['category']?.toString() ?? '',
      data['type']?.toString() ?? '',
      data['model']?.toString() ?? '',
      data['model_name']?.toString() ?? '',
      data['event']?.toString() ?? '',
      data['action']?.toString() ?? '',
      data['topic']?.toString() ?? '',
      message.notification?.title ?? '',
      message.notification?.body ?? '',
    ].join(' ').toLowerCase();

    final hasAttendanceKeyword = searchSpace.contains('hr.attendance') ||
        searchSpace.contains('attendance') ||
        searchSpace.contains('biotime') ||
        searchSpace.contains('check_in') ||
        searchSpace.contains('check_out') ||
        searchSpace.contains('check in') ||
        searchSpace.contains('check out') ||
        searchSpace.contains('checkout');

    if (hasAttendanceKeyword) {
      return true;
    }

    final refreshFlag = data['refresh_attendance'] ??
        data['attendance_refresh'] ??
        data['refresh_today_status'];

    if (refreshFlag == null) {
      return false;
    }

    final normalizedFlag = refreshFlag.toString().trim().toLowerCase();
    return normalizedFlag == '1' ||
        normalizedFlag == 'true' ||
        normalizedFlag == 'yes' ||
        normalizedFlag == 'y';
  }

  static void _handleNotificationTap(String? payload) {
    print('\n🔔 [HANDLE TAP] Notification tapped');
    print('   - Payload: $payload');

    // Azan local notification: OS already played sound — never replay in-app.
    if (payload != null && payload.startsWith('prayer:')) {
      unawaited(PrayerAudioService.acknowledgeOsPrayerFromPayload(payload));
      print('   - Prayer/azan tap acknowledged (no in-app replay).');
      return;
    }

    final payloadData = _parseNotificationPayload(payload);
    final category = (payloadData['category'] ?? payloadData['type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    if (_isChatNotificationPayload(payloadData, category)) {
      _handleChatNotificationTap(payload, payloadData);
      return;
    }

    if (_isTaskOrTicketNotificationPayload(payloadData, category)) {
      _handleTaskNotificationTap(payload, payloadData, category);
      return;
    }

    print('   - View-only notification; no navigation.');
  }

  static bool _isTaskOrTicketNotificationPayload(
    Map<String, dynamic> payloadData,
    String category,
  ) {
    return category == 'task' ||
        category == 'ticket' ||
        payloadData.containsKey('task_id') ||
        payloadData.containsKey('taskId') ||
        payloadData.containsKey('is_firebase_task');
  }

  static bool _parseBoolFlag(dynamic value) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == '1' ||
        normalized == 'true' ||
        normalized == 'yes' ||
        normalized == 'y';
  }

  static void _handleTaskNotificationTap(
    String? rawPayload,
    Map<String, dynamic> payloadData,
    String category,
  ) {
    final navigator = navKey.currentState;
    if (navigator == null || navKey.currentContext == null || !_isHomeReady) {
      _pendingChatTapPayload = rawPayload;
      print('   - Task/ticket tap queued until navigation is ready.');
      return;
    }

    final taskId =
        (payloadData['task_id'] ?? payloadData['taskId'] ?? '').toString();
    final isFirebase = _parseBoolFlag(payloadData['is_firebase_task']);
    final isTicket = category == 'ticket' || !isFirebase;

    try {
      if (isFirebase && taskId.isNotEmpty) {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => firebase_task_details.TaskDetailsScreen(
              taskId: taskId,
            ),
            settings: const RouteSettings(name: '/task-details'),
          ),
        );
        print('   - Opened Firebase task details for $taskId');
        return;
      }

      // Odoo tickets / non-firebase tasks → Tickets list
      navigator.push(
        MaterialPageRoute(
          builder: (_) => const TasksScreen(),
          settings: const RouteSettings(name: '/tickets'),
        ),
      );
      print('   - Opened Tickets screen (taskId=$taskId)');
    } catch (e) {
      print('   - Failed to navigate for task/ticket tap: $e');
    }
  }

  static void processPendingNotificationTap({String? forcePayload}) {
    final payload = forcePayload ?? _pendingChatTapPayload;
    if (payload == null || payload.isEmpty) return;

    _pendingChatTapPayload = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleNotificationTap(payload);
    });
  }

  static String _buildEnrichedPayload(RemoteMessage message) {
    final enriched = Map<String, dynamic>.from(message.data);
    final notification = message.notification;
    if (notification != null) {
      enriched.putIfAbsent('title', () => notification.title ?? '');
      enriched.putIfAbsent('body', () => notification.body ?? '');
    }

    return _encodePayload(enriched);
  }

  static String _encodePayload(Map<String, dynamic> data) {
    try {
      return jsonEncode(data);
    } catch (_) {
      return data.toString();
    }
  }

  static Map<String, dynamic> _parseNotificationPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) {
      return {};
    }

    final trimmed = payload.trim();
    if (trimmed.startsWith('{')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          return decoded.map(
            (key, value) => MapEntry(key.toString(), value),
          );
        }
      } catch (_) {
        // Fall back to parsing the Dart Map.toString() format used by older
        // notification payloads.
      }
    }

    final result = <String, dynamic>{};
    final content = trimmed
        .replaceFirst(RegExp(r'^\{'), '')
        .replaceFirst(RegExp(r'\}$'), '');

    for (final pair in content.split(RegExp(r',\s*'))) {
      final separatorIndex = pair.indexOf(':');
      if (separatorIndex <= 0) continue;

      final key = pair.substring(0, separatorIndex).trim();
      final value = pair.substring(separatorIndex + 1).trim();
      if (key.isNotEmpty) {
        result[key] = value;
      }
    }

    return result;
  }

  static bool _isChatNotificationPayload(
    Map<String, dynamic> payloadData,
    String category,
  ) {
    return category == 'chat_message' ||
        category == 'chat' ||
        payloadData.containsKey('chat_id') ||
        payloadData.containsKey('chatId');
  }

  static void _handleChatNotificationTap(
    String? rawPayload,
    Map<String, dynamic> payloadData,
  ) {
    if (_isHandlingChatTap) {
      _pendingChatTapPayload = rawPayload;
      return;
    }

    final navigator = navKey.currentState;
    if (navigator == null || navKey.currentContext == null || !_isHomeReady) {
      _pendingChatTapPayload = rawPayload;
      print('   - Chat tap queued until navigation is ready.');
      return;
    }

    _isHandlingChatTap = true;
    try {
      final chatId =
          (payloadData['chat_id'] ?? payloadData['chatId'] ?? '').toString();
      if (chatId.trim().isEmpty) {
        print('   - Chat notification missing chat_id; no navigation.');
        return;
      }

      final chatTitle = (payloadData['chat_title'] ??
              payloadData['chatTitle'] ??
              payloadData['title'] ??
              'Chat')
          .toString();
      final chatType = _resolveChatType(payloadData);

      _navigateToChatScreen(navigator, chatId, chatTitle, chatType);
    } finally {
      _isHandlingChatTap = false;

      if (_pendingChatTapPayload != null &&
          _pendingChatTapPayload != rawPayload) {
        final nextPayload = _pendingChatTapPayload;
        _pendingChatTapPayload = null;
        processPendingNotificationTap(forcePayload: nextPayload);
      }
    }
  }

  static String _resolveChatType(Map<String, dynamic> payloadData) {
    for (final key in const [
      'chat_type',
      'chatType',
      'conversation_type',
      'type',
    ]) {
      final normalized =
          (payloadData[key] ?? '').toString().trim().toLowerCase();
      if (normalized == 'dm' ||
          normalized == 'role' ||
          normalized == 'group' ||
          normalized == 'support') {
        return normalized;
      }
    }

    return 'dm';
  }

  static void _navigateToChatScreen(
    NavigatorState navigator,
    String chatId,
    String chatTitle,
    String chatTypeStr,
  ) {
    try {
      final chatType = ChatType.fromString(chatTypeStr.toLowerCase().trim());

      String? peerUid;
      if (chatType == ChatType.dm && chatId.startsWith('dm_')) {
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        if (currentUid != null) {
          final allParts = chatId.substring(3);
          if (allParts.startsWith('${currentUid}_')) {
            peerUid = allParts.substring(currentUid.length + 1);
          } else if (allParts.endsWith('_$currentUid')) {
            peerUid =
                allParts.substring(0, allParts.length - currentUid.length - 1);
          }
        }
      }

      navigator.push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            title: chatTitle.trim().isEmpty ? 'Chat' : chatTitle,
            chatType: chatType,
            peerUid: peerUid,
          ),
          settings: const RouteSettings(name: '/chat_from_notification'),
        ),
      );
      print('   - Chat notification opened chatId=$chatId');
    } catch (e) {
      print('   - Chat navigation failed: $e');
    }
  }
}
