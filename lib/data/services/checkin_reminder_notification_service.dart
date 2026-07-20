import 'dart:io';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// خدمة إشعارات تذكير Check In/Out
///
/// التذكيرات:
/// • إذا عمل check in وما عمل check out:
///   - من الساعة 4 مساءً - 5 مساءً: إشعار كل 15 دقيقة
/// • إذا ما عمل check in:
///   - من الساعة 8 صباحاً - 9 صباحاً: إشعار كل 15 دقيقة
///
/// التوقيت: الإمارات (GMT+4)
class CheckInReminderNotificationService {
  static final CheckInReminderNotificationService _instance =
      CheckInReminderNotificationService._internal();
  factory CheckInReminderNotificationService() => _instance;
  CheckInReminderNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _exactAlarmGranted = false;

  // Notification IDs
  static const int _checkOutReminderId = 1000;
  static const int _checkInReminderId = 2000;

  Future<void> initialize() async {
    if (_initialized) return;
    // Set before the awaited call below, not after: cancelAllReminders()
    // calls cancelCheckInReminders()/cancelCheckOutReminders(), which each
    // call initialize() again. With the flag only set at the end, that
    // reentrant call saw _initialized still false and recursed — a real
    // infinite loop (initialize -> cancelAllReminders ->
    // cancelCheckInReminders -> initialize -> ...) that overflowed the
    // stack. Confirmed from a real device stack trace (2026-07-20).
    _initialized = true;

    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Dubai'));
    } catch (e) {
      try {
        tz.setLocalLocation(tz.getLocation('Etc/GMT-4'));
      } catch (_) {}
    }

    // Cancel any leftover check-in/out schedules from older builds.
    await cancelAllReminders();
  }

  /// طلب صلاحيات الإشعارات والإشعارات الدقيقة + إيقاف تحسين البطارية (Samsung)
  Future<void> _requestNotificationPermissions() async {
    try {
      // طلب صلاحية الإشعارات العادية (Android 13+)
      final notificationStatus = await Permission.notification.request();
      // print('📱 Notification permission: ${notificationStatus.isGranted}');

      if (Platform.isAndroid) {
        // طلب إيقاف تحسين البطارية (مهم جداً لـ Samsung)
        // Samsung One UI يوقف الإشعارات المجدولة بسبب "Sleeping apps"
        await _requestBatteryOptimizationExemption();

        // طلب صلاحية الإشعارات الدقيقة (Exact Alarms)
        // على Android 12 (API 31) وما فوق
        try {
          if (await Permission.scheduleExactAlarm.isDenied) {
            // print('⚠️ Requesting exact alarm permission...');
            await Permission.scheduleExactAlarm.request();
          }

          final alarmStatus = await Permission.scheduleExactAlarm.status;
          _exactAlarmGranted = alarmStatus.isGranted;
          // print('⏰ Exact alarm permission: $_exactAlarmGranted');

          if (!_exactAlarmGranted) {
            // print('⚠️ Exact alarm NOT granted - will use inexact alarms as fallback');
          }
        } catch (e) {
          // print('⚠️ Error checking exact alarm permission: $e');
          _exactAlarmGranted = false;
        }
      } else {
        // iOS لا يحتاج exact alarm permission
        _exactAlarmGranted = true;
      }
    } catch (e) {
      // print('⚠️ Error requesting permissions: $e');
    }
  }

  /// طلب إيقاف تحسين البطارية - مهم جداً لأجهزة Samsung
  /// Samsung One UI يضع التطبيقات في "Sleeping apps" مما يمنع الإشعارات المجدولة
  Future<void> _requestBatteryOptimizationExemption() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      // print('🔋 Battery optimization status: ${status.isGranted ? "EXEMPT" : "NOT EXEMPT"}');

      if (!status.isGranted) {
        // print('🔋 Requesting battery optimization exemption (important for Samsung)...');
        final result = await Permission.ignoreBatteryOptimizations.request();
        // print('🔋 Battery optimization exemption result: ${result.isGranted ? "GRANTED" : "DENIED"}');

        if (!result.isGranted) {
          // print('⚠️ Battery optimization NOT disabled!');
          // print('💡 Samsung users: Go to Settings > Apps > El Race > Battery > Unrestricted');
        }
      }

      // تسجيل معلومات الجهاز للتشخيص
      try {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        // print('📱 Device: ${androidInfo.manufacturer} ${androidInfo.model}');
        // print('📱 Android SDK: ${androidInfo.version.sdkInt}');

        if (androidInfo.manufacturer.toLowerCase().contains('samsung')) {
          // print('⚠️ Samsung device detected - aggressive battery optimization may block notifications');
          // print('💡 Ensure app is NOT in "Sleeping apps" or "Deep sleeping apps"');
          // print('💡 Settings > Battery > Background usage limits > Never sleeping apps > Add El Race');
        }
      } catch (e) {
        // print('⚠️ Could not get device info: $e');
      }
    } catch (e) {
      // print('⚠️ Error requesting battery optimization exemption: $e');
    }
  }

  /// إنشاء قنوات الإشعارات لـ Android
  Future<void> _createNotificationChannels() async {
    // قناة تذكيرات Check In
    const AndroidNotificationChannel checkInChannel = AndroidNotificationChannel(
      'check_in_reminder_channel',
      'Check In Reminders',
      description: 'Check-in reminders',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    // قناة تذكيرات Check Out
    const AndroidNotificationChannel checkOutChannel = AndroidNotificationChannel(
      'check_out_reminder_channel',
      'Check Out Reminders',
      description: 'Check-out reminders',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    // إنشاء القنوات
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(checkInChannel);

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(checkOutChannel);

    // print('✅ Check-in/out notification channels created');
  }

  /// جدولة إشعارات التذكير بـ check out (من 4 مساءً - 5 مساءً)
  Future<void> scheduleCheckOutReminders() async {
    // Product decision: check-in/out local reminders removed from the app.
    return;
    await initialize();
    await cancelCheckOutReminders(); // إلغاء أي إشعارات سابقة

    // إعادة فحص صلاحية exact alarm قبل الجدولة
    if (Platform.isAndroid) {
      try {
        final alarmStatus = await Permission.scheduleExactAlarm.status;
        _exactAlarmGranted = alarmStatus.isGranted;
      } catch (_) {}
    }

    final now = tz.TZDateTime.now(tz.local);
    // print('⏰ Current time: ${now.toString()}');
    // print('⏰ Schedule mode: ${_exactAlarmGranted ? "EXACT" : "INEXACT (fallback)"}');

    // جدول إشعارات كل 15 دقيقة من الساعة 4 مساءً حتى 5 مساءً
    final reminderTimes = [
      // 4:00 PM
      tz.TZDateTime(tz.local, now.year, now.month, now.day, 16, 0),
      // 4:15 PM
      tz.TZDateTime(tz.local, now.year, now.month, now.day, 16, 15),
      // 4:30 PM
      tz.TZDateTime(tz.local, now.year, now.month, now.day, 16, 30),
      // 4:45 PM
      tz.TZDateTime(tz.local, now.year, now.month, now.day, 16, 45),
      // 5:00 PM (آخر تذكير)
      tz.TZDateTime(tz.local, now.year, now.month, now.day, 17, 0),
    ];

    int idCounter = _checkOutReminderId;
    int scheduledCount = 0;
    // Capture exact-alarm capability ONCE; never mutate the shared instance field
    // inside the loop — a single failure must not force ALL remaining notifications
    // into inexact mode for the rest of the app session.
    final bool useExactAlarm = _exactAlarmGranted;
    for (var scheduledTime in reminderTimes) {
      // إذا كان الوقت قد مضى اليوم، جدول لليوم التالي
      var targetTime = scheduledTime;
      if (targetTime.isBefore(now)) {
        targetTime = targetTime.add(const Duration(days: 1));
      }

      try {
        await _notificationsPlugin.zonedSchedule(
          idCounter,
          '⏰ Check Out Reminder',
          'Don\'t forget to Check Out',
          targetTime,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'check_out_reminder_channel',
              'Check Out Reminders',
              channelDescription: 'Check-out reminders',
              importance: Importance.max,
              priority: Priority.max,
              category: AndroidNotificationCategory.alarm,
              icon: '@mipmap/ic_launcher',
              playSound: true,
              enableVibration: true,
              fullScreenIntent: false,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: useExactAlarm
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time, // يتكرر يومياً
        );
        scheduledCount++;
        print(
            '✅ Scheduled check-out reminder #${idCounter - _checkOutReminderId + 1} at ${targetTime.toString()}');
      } catch (e) {
        // print('❌ Error scheduling check-out reminder #${idCounter}: $e');
        // محاولة ثانية بوضع inexact إذا فشل exact
        // NOTE: Do NOT modify _exactAlarmGranted here; use the captured local value.
        if (useExactAlarm) {
          try {
            await _notificationsPlugin.zonedSchedule(
              idCounter,
              '⏰ Check Out Reminder',
              'Don\'t forget to Check Out',
              targetTime,
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'check_out_reminder_channel',
                  'Check Out Reminders',
                  channelDescription: 'Check-out reminders',
                  importance: Importance.max,
                  priority: Priority.max,
                  category: AndroidNotificationCategory.alarm,
                  icon: '@mipmap/ic_launcher',
                  playSound: true,
                  enableVibration: true,
                  fullScreenIntent: false,
                ),
                iOS: DarwinNotificationDetails(
                  presentAlert: true,
                  presentBadge: true,
                  presentSound: true,
                ),
              ),
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              matchDateTimeComponents: DateTimeComponents.time,
            );
            scheduledCount++;
            // print('✅ Retry with inexact mode succeeded for #${idCounter}');
          } catch (e2) {
            // print('❌ Retry also failed for #${idCounter}: $e2');
          }
        }
      }

      idCounter++;
    }

    print(
        '✅ Successfully scheduled $scheduledCount/${reminderTimes.length} check-out reminders (4 PM - 5 PM)');
  }

  /// جدولة إشعارات التذكير بـ check in (من 8 صباحاً - 9 صباحاً)
  Future<void> scheduleCheckInReminders() async {
    // Product decision: check-in/out local reminders removed from the app.
    return;
    await initialize();
    await cancelCheckInReminders(); // إلغاء أي إشعارات سابقة

    // إعادة فحص صلاحية exact alarm قبل الجدولة
    if (Platform.isAndroid) {
      try {
        final alarmStatus = await Permission.scheduleExactAlarm.status;
        _exactAlarmGranted = alarmStatus.isGranted;
      } catch (_) {}
    }

    final now = tz.TZDateTime.now(tz.local);
    // print('⏰ Current time: ${now.toString()}');
    // print('⏰ Schedule mode: ${_exactAlarmGranted ? "EXACT" : "INEXACT (fallback)"}');

    // جدول إشعارات كل 15 دقيقة من الساعة 8 صباحاً حتى 9 صباحاً
    final reminderTimes = [
      // 8:00 AM
      tz.TZDateTime(tz.local, now.year, now.month, now.day, 8, 0),
      // 8:15 AM
      tz.TZDateTime(tz.local, now.year, now.month, now.day, 8, 15),
      // 8:30 AM
      tz.TZDateTime(tz.local, now.year, now.month, now.day, 8, 30),
      // 8:45 AM
      tz.TZDateTime(tz.local, now.year, now.month, now.day, 8, 45),
      // 9:00 AM (آخر تذكير)
      tz.TZDateTime(tz.local, now.year, now.month, now.day, 9, 0),
    ];

    int idCounter = _checkInReminderId;
    int scheduledCount = 0;
    // Capture exact-alarm capability ONCE; never mutate the shared instance field
    // inside the loop — a single failure must not force ALL remaining notifications
    // into inexact mode for the rest of the app session.
    final bool useExactAlarm = _exactAlarmGranted;
    for (var scheduledTime in reminderTimes) {
      // إذا كان الوقت قد مضى اليوم، جدول لليوم التالي
      var targetTime = scheduledTime;
      if (targetTime.isBefore(now)) {
        targetTime = targetTime.add(const Duration(days: 1));
      }

      try {
        await _notificationsPlugin.zonedSchedule(
          idCounter,
          '⏰ Check In Reminder',
          'Don\'t forget to Check In',
          targetTime,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'check_in_reminder_channel',
              'Check In Reminders',
              channelDescription: 'Check-in reminders',
              importance: Importance.max,
              priority: Priority.max,
              category: AndroidNotificationCategory.alarm,
              icon: '@mipmap/ic_launcher',
              playSound: true,
              enableVibration: true,
              fullScreenIntent: false,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: useExactAlarm
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time, // يتكرر يومياً
        );
        scheduledCount++;
        print(
            '✅ Scheduled check-in reminder #${idCounter - _checkInReminderId + 1} at ${targetTime.toString()}');
      } catch (e) {
        // print('❌ Error scheduling check-in reminder #${idCounter}: $e');
        // محاولة ثانية بوضع inexact إذا فشل exact
        // NOTE: Do NOT modify _exactAlarmGranted here; use the captured local value.
        if (useExactAlarm) {
          try {
            await _notificationsPlugin.zonedSchedule(
              idCounter,
              '⏰ Check In Reminder',
              'Don\'t forget to Check In',
              targetTime,
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'check_in_reminder_channel',
                  'Check In Reminders',
                  channelDescription: 'Check-in reminders',
                  importance: Importance.max,
                  priority: Priority.max,
                  category: AndroidNotificationCategory.alarm,
                  icon: '@mipmap/ic_launcher',
                  playSound: true,
                  enableVibration: true,
                  fullScreenIntent: false,
                ),
                iOS: DarwinNotificationDetails(
                  presentAlert: true,
                  presentBadge: true,
                  presentSound: true,
                ),
              ),
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              matchDateTimeComponents: DateTimeComponents.time,
            );
            scheduledCount++;
            // print('✅ Retry with inexact mode succeeded for #${idCounter}');
          } catch (e2) {
            // print('❌ Retry also failed for #${idCounter}: $e2');
          }
        }
      }

      idCounter++;
    }

    print(
        '✅ Successfully scheduled $scheduledCount/${reminderTimes.length} check-in reminders (8 AM - 9 AM)');
  }

  /// إلغاء تذكيرات check out
  Future<void> cancelCheckOutReminders() async {
    await initialize();
    // إلغاء 5 إشعارات (4:00, 4:15, 4:30, 4:45, 5:00)
    for (int i = 0; i < 5; i++) {
      await _notificationsPlugin.cancel(_checkOutReminderId + i);
    }
    // print('🔕 Cancelled check-out reminders');
  }

  /// إلغاء تذكيرات check in
  Future<void> cancelCheckInReminders() async {
    await initialize();
    // إلغاء 5 إشعارات (8:00, 8:15, 8:30, 8:45, 9:00)
    for (int i = 0; i < 5; i++) {
      await _notificationsPlugin.cancel(_checkInReminderId + i);
    }
    // print('🔕 Cancelled check-in reminders');
  }

  /// تحديث الإشعارات حسب حالة check in/out
  /// يتحقق أولاً من حالة تسجيل الدخول — إذا كان المستخدم عامل logout يلغي كل التذكيرات
  Future<void> updateReminders() async {
    // Check-in / check-out local reminders removed — cancel any leftover schedules.
    await cancelAllReminders();
  }

  /// إلغاء جميع التذكيرات
  Future<void> cancelAllReminders() async {
    await cancelCheckInReminders();
    await cancelCheckOutReminders();
    // print('🔕 Cancelled all check-in/out reminders');
  }

  /// [للاختبار] إرسال إشعار تجريبي فوري
  Future<void> sendTestNotification({bool isCheckIn = true}) async {
    await initialize();
    try {
      await _notificationsPlugin.show(
        99999, // رقم مؤقت للاختبار
        isCheckIn
            ? '🧪 Test: Check In Reminder'
            : '🧪 Test: Check Out Reminder',
        isCheckIn
            ? 'This is a test notification - Don\'t forget to Check In'
            : 'This is a test notification - Don\'t forget to Check Out',
        NotificationDetails(
          android: AndroidNotificationDetails(
            isCheckIn
                ? 'check_in_reminder_channel'
                : 'check_out_reminder_channel',
            isCheckIn ? 'Check In Reminders' : 'Check Out Reminders',
            channelDescription: isCheckIn
                ? 'Check-in reminders'
                : 'Check-out reminders',
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
            fullScreenIntent: false,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
      print(
          '✅ Test notification sent successfully (${isCheckIn ? "Check In" : "Check Out"})');
    } catch (e) {
      // print('❌ Error sending test notification: $e');
    }
  }

  bool _hasActiveCheckInState() {
    final isCheckedIn = SharedPref().getPreferenceBoolean('isCheckedIn');
    final checkInRecordId = SharedPref().getPreferenceInt('checkInRecordId');
    final checkInTime = SharedPref().getPreferenceInt('checkInTime');
    final checkInDisplayTime =
        SharedPref().getPreferenceString('checkInDisplayTime');
    final checkOutDisplayTime =
        SharedPref().getPreferenceString('checkOutDisplayTime');

    final hasCheckInEvidence =
        isCheckedIn ||
        checkInRecordId > 0 ||
        checkInTime > 0 ||
        _isMeaningfulDisplayTime(checkInDisplayTime);
    final hasCheckOutEvidence = _isMeaningfulDisplayTime(checkOutDisplayTime);

    print(
      '📱 Reminder state: '
      'isCheckedIn=$isCheckedIn, '
      'checkInRecordId=$checkInRecordId, '
      'checkInTime=$checkInTime, '
      'checkInDisplayTime=$checkInDisplayTime, '
      'checkOutDisplayTime=$checkOutDisplayTime',
    );

    return hasCheckInEvidence && !hasCheckOutEvidence;
  }

  bool _isMeaningfulDisplayTime(String value) {
    return value.isNotEmpty && value != '00:00:00' && value != '--:--';
  }
}
