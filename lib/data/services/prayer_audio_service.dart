import 'dart:async';
import 'package:adhan/adhan.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/data/services/hive_service.dart';
import 'package:el_race/data/services/prayer_notification_service.dart';
import 'package:flutter/widgets.dart';
import 'package:volume_controller/volume_controller.dart';

class PrayerAudioService {
  static final PrayerAudioService _instance = PrayerAudioService._internal();
  factory PrayerAudioService() => _instance;
  PrayerAudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final PrayerNotificationService _notificationService =
      PrayerNotificationService();
  Timer? _checkTimer;
  PrayerTimes? _currentPrayerTimes;
  DateTime? _lastPlayedTime;
  bool _isPlaying = false; // منع تشغيل متعدد
  StreamSubscription<double>? _volumeSubscription;
  double? _volumeAtStart; // مستوى الصوت عند بداية الأذان

  /// When true, only the in-app timer + AudioPlayer fire azan.
  /// When false (background), only OS scheduled notifications fire.
  bool _foregroundActive = true;

  // تهيئة الخدمة
  Future<void> initialize(PrayerTimes prayerTimes) async {
    // debugPrint('🕌 PrayerAudioService: Initializing...');
    _currentPrayerTimes = prayerTimes;
    await _notificationService.initialize();

    // App is in foreground: own azan via timer/AudioPlayer only.
    await enterForegroundMode();
    // debugPrint('🕌 PrayerAudioService: Initialized successfully');
  }

  /// Foreground: cancel all pending OS azan notifications, run poll timer.
  Future<void> enterForegroundMode() async {
    _foregroundActive = true;
    try {
      await _notificationService.cancelAllPendingAdhan();
    } catch (_) {}
    await _startChecking();
  }

  /// Background: stop timer so we never double-fire with OS notifications.
  Future<void> enterBackgroundMode() async {
    _foregroundActive = false;
    _checkTimer?.cancel();
    _checkTimer = null;
    await rescheduleBackgroundNotifications();
  }

  // بدء التحقق الدوري من أوقات الصلاة
  Future<void> _startChecking() async {
    // إلغاء أي timer سابق
    _checkTimer?.cancel();
    // debugPrint('⏰ Starting prayer check timer (every 30 seconds)');

    // التحقق كل 30 ثانية
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      // debugPrint('⏰ Timer tick - checking prayer times...');
      await _checkAndPlayAdhan();
    });

    // تحقق فوري عند البداية
    // debugPrint('⏰ Initial check at startup');
    await _checkAndPlayAdhan();
  }

  bool get _isAppResumed {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  // التحقق وتشغيل الأذان إذا حان الوقت
  Future<void> _checkAndPlayAdhan() async {
    // فقط في المقدمة — الخلفية تعتمد على الإشعار المجدول فقط
    if (!_foregroundActive || !_isAppResumed) {
      return;
    }

    // منع التشغيل المتعدد
    if (_isPlaying) {
      // debugPrint('⏭️ Adhan already playing, skipping check');
      return;
    }

    if (_currentPrayerTimes == null) {
      // debugPrint('❌ Prayer times not initialized');
      return;
    }

    try {
      // التحقق من تسجيل الدخول
      final isLoggedIn = SharedPref.isUserAuthenticated();
      // debugPrint('🔑 User logged in: $isLoggedIn');
      if (!isLoggedIn) {
        // debugPrint('🚫 User not logged in, skipping adhan');
        return;
      }

      // التحقق من حالة كتم الصوت
      final isMuted = await HiveService.isPrayerSoundMuted();
      // debugPrint('🔊 Sound muted: $isMuted');
      if (isMuted) {
        // debugPrint('🔇 Prayer sound is muted, skipping adhan');
        return;
      }

      final now = DateTime.now();
      // debugPrint('🕐 Current time: ${now.hour}:${now.minute}:${now.second}');

      final prayers = [
        {'prayer': Prayer.fajr, 'time': _currentPrayerTimes!.fajr},
        {'prayer': Prayer.dhuhr, 'time': _currentPrayerTimes!.dhuhr},
        {'prayer': Prayer.asr, 'time': _currentPrayerTimes!.asr},
        {'prayer': Prayer.maghrib, 'time': _currentPrayerTimes!.maghrib},
        {'prayer': Prayer.isha, 'time': _currentPrayerTimes!.isha},
      ];

      for (var prayerData in prayers) {
        final prayerTime = prayerData['time'] as DateTime;
        final prayer = prayerData['prayer'] as Prayer;
        final prayerName = _getPrayerName(prayer);
        final normalizedPrayerName = prayerName.toLowerCase();

        // التحقق إذا كان الوقت الحالي بين وقت الصلاة و 5 دقائق بعدها
        final timeDiff = now.difference(prayerTime);

        // debugPrint(
        //     '📋 Checking $prayerName: time=${prayerTime.hour}:${prayerTime.minute}, diff=${timeDiff.inSeconds}s');

        if (timeDiff.inSeconds >= 0 && timeDiff.inMinutes < 5) {
          // Day-based key so local vs API second drift still dedupes.
          final dayKey =
              '${prayerTime.year}${prayerTime.month.toString().padLeft(2, '0')}${prayerTime.day.toString().padLeft(2, '0')}';
          final playedKey = 'played_${normalizedPrayerName}_$dayKey';
          final alreadyPlayed = await HiveService.hasPlayedPrayer(playedKey);

          if (alreadyPlayed) {
            // debugPrint(
            //     '⏭️ Already handled $prayerName at ${prayerTime.toIso8601String()}');
            continue;
          }

          if (_lastPlayedTime == null ||
              _lastPlayedTime!.difference(prayerTime).abs().inMinutes > 10) {
            // debugPrint('✅ Time for $prayerName prayer! Playing adhan...');
            _isPlaying = true; // تعيين الحالة قبل التشغيل

            // Extra safety: wipe any leftover scheduled OS azan for this slot.
            try {
              await _notificationService.cancelScheduledAdhan(
                normalizedPrayerName,
                prayerTime.millisecondsSinceEpoch,
              );
              await _notificationService.cancelAllPendingAdhan();
            } catch (_) {}

            await _notificationService.showAdhanNotification(prayerName);
            await _playAdhan();
            _lastPlayedTime = prayerTime;
            // mark as played to prevent duplicates (foreground/background)
            await HiveService.markPrayerPlayed(playedKey);
            _isPlaying = false; // إعادة الحالة بعد الانتهاء
            break;
          } else {
            // debugPrint('⏭️ Already played for this prayer time');
          }
        }
      }
      // debugPrint('✓ Check completed');
    } catch (e) {
      // debugPrint('❌ Error checking prayer times: $e');
      _isPlaying = false; // التأكد من إعادة الحالة في حالة الخطأ
    }
  }

  // بدء مراقبة زر الصوت لإيقاف الأذان عند الضغط على أي زر
  void _startVolumeListener() {
    _volumeSubscription?.cancel();
    // حفظ مستوى الصوت الحالي
    VolumeController.instance.getVolume().then((vol) {
      _volumeAtStart = vol;
    });
    // لا نريد أن يظهر مؤشر الصوت الخاص بالنظام
    VolumeController.instance.showSystemUI = false;
    _volumeSubscription =
        VolumeController.instance.addListener((volume) {
      if (_isPlaying && _volumeAtStart != null) {
        // إذا تغير مستوى الصوت (أي كبسة) → أوقف الأذان
        if ((volume - _volumeAtStart!).abs() > 0.01) {
          stopAdhan();
          // إعادة مستوى الصوت للقيمة الأصلية
          VolumeController.instance.setVolume(_volumeAtStart!);
        }
      }
    });
  }

  // إيقاف مراقبة زر الصوت
  void _stopVolumeListener() {
    _volumeSubscription?.cancel();
    _volumeSubscription = null;
    _volumeAtStart = null;
    VolumeController.instance.showSystemUI = true;
  }

  // تشغيل صوت الأذان
  Future<void> _playAdhan() async {
    try {
      // debugPrint('🎵 Starting adhan playback...');
      await _audioPlayer.stop();
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      // start with low volume and fade in
      await _audioPlayer.setVolume(0.1);
      // debugPrint('🔊 Volume set to 10% (starting fade-in)');

      // بدء مراقبة أزرار الصوت
      _startVolumeListener();

      // تشغيل ملف الصوت من assets
      await _audioPlayer.play(AssetSource('mp3/athan.mp3'));

      // Gradually increase volume to full over ~3 seconds
      for (int i = 1; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 300));
        try {
          await _audioPlayer.setVolume(0.1 * i);
        } catch (_) {}
      }

      // debugPrint('✅ Adhan started playing successfully (with fade-in)!');

      // إيقاف الصوت تلقائياً بعد 4 دقائق (مدة الأذان الكاملة)
      Future.delayed(const Duration(minutes: 4), () async {
        if (_isPlaying) {
          await stopAdhan();
          _isPlaying = false;
        }
      });
    } catch (e) {
      // debugPrint('❌ Error playing adhan: $e');
      _isPlaying = false;
    }
  }

  // إيقاف صوت الأذان
  Future<void> stopAdhan() async {
    try {
      await _audioPlayer.stop();
      _isPlaying = false;
      _stopVolumeListener();
      // debugPrint('Adhan stopped');
    } catch (e) {
      // debugPrint('Error stopping adhan: $e');
    }
  }

  // تحديث أوقات الصلاة
  void updatePrayerTimes(PrayerTimes prayerTimes) {
    _currentPrayerTimes = prayerTimes;
    _lastPlayedTime = null; // إعادة تعيين آخر وقت تشغيل
    if (_foregroundActive) {
      // ignore: unawaited_futures
      _notificationService.cancelAllPendingAdhan();
    }
  }

  /// إعادة جدولة إشعارات الأذان المحلية للصلوات القادمة.
  /// يُستدعى عندما ينتقل التطبيق إلى الخلفية لضمان وصول الإشعار
  /// حتى لو أوقف النظام الـ foreground timer.
  Future<void> rescheduleBackgroundNotifications() async {
    if (_currentPrayerTimes == null) return;

    // Wipe orphans from earlier schedule passes (different timestamps/IDs).
    try {
      await _notificationService.cancelAllPendingAdhan();
    } catch (_) {}

    final now = DateTime.now();
    final prayers = [
      {'name': 'fajr', 'time': _currentPrayerTimes!.fajr},
      {'name': 'dhuhr', 'time': _currentPrayerTimes!.dhuhr},
      {'name': 'asr', 'time': _currentPrayerTimes!.asr},
      {'name': 'maghrib', 'time': _currentPrayerTimes!.maghrib},
      {'name': 'isha', 'time': _currentPrayerTimes!.isha},
    ];

    for (final p in prayers) {
      final time = p['time'] as DateTime;
      if (time.isAfter(now)) {
        try {
          await _notificationService.scheduleAdhanNotification(
            p['name'] as String,
            time,
          );
        } catch (_) {}
      }
    }
  }

  // الحصول على اسم الصلاة
  String _getPrayerName(Prayer prayer) {
    switch (prayer) {
      case Prayer.fajr:
        return 'Fajr';
      case Prayer.dhuhr:
        return 'Dhuhr';
      case Prayer.asr:
        return 'Asr';
      case Prayer.maghrib:
        return 'Maghrib';
      case Prayer.isha:
        return 'Isha';
      default:
        return 'Unknown';
    }
  }

  // تنظيف الموارد
  Future<void> dispose() async {
    _checkTimer?.cancel();
    _stopVolumeListener();
    await _audioPlayer.stop();
    await _audioPlayer.dispose();
    _isPlaying = false;
    // debugPrint('PrayerAudioService disposed');
  }
}
