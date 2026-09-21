import 'dart:convert';

import 'package:adhan/adhan.dart';
import 'package:el_race/data/services/prayer_location_service.dart';
import 'package:el_race/data/services/prayer_notification_service.dart';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';

const String prayerCheckTaskName = 'prayerCheckTask';
const String rescheduleTaskName = 'reschedulePrayerTasks';
const String prayerScheduleRefreshUniqueName = 'prayerScheduleRefreshV2';
const int prayerScheduleHorizonDays = 7;

class PrayerBackgroundService {
  static Future<void> initialize() async {
    // Workmanager is initialized once in main.dart with the unified dispatcher.
    await _schedulePrayerTasks();
  }

  /// Refreshes the rolling schedule even when the app stays closed for days.
  static Future<void> registerPeriodicRefresh() async {
    await Workmanager().registerPeriodicTask(
      prayerScheduleRefreshUniqueName,
      rescheduleTaskName,
      frequency: const Duration(hours: 12),
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  }

  static Future<void> _schedulePrayerTasks() async {
    try {
      final notificationService = PrayerNotificationService();
      await notificationService.initialize();

      // A refresh replaces the existing prayer window instead of stacking it.
      // When prayer sound is muted, scheduleAdhanNotification keeps this empty.
      await notificationService.cancelAllPendingAdhan();

      final coordinates =
          await PrayerLocationService.getBestAvailableCoordinates();
      final parameters =
          PrayerLocationService.calculationParametersFor(coordinates);
      final now = DateTime.now();
      final dates = List<DateTime>.generate(
        prayerScheduleHorizonDays,
        (dayOffset) => DateTime(now.year, now.month, now.day + dayOffset),
      );
      final aladhanSchedules = await Future.wait(
        dates.map((date) => _fetchAladhanTimes(date, coordinates)),
      );

      for (var dayOffset = 0; dayOffset < dates.length; dayOffset++) {
        final date = dates[dayOffset];
        final localPrayerTimes = PrayerTimes(
          coordinates,
          DateComponents.from(date),
          parameters,
        );
        final prayers = aladhanSchedules[dayOffset] ??
            <MapEntry<String, DateTime>>[
              MapEntry('fajr', localPrayerTimes.fajr),
              MapEntry('dhuhr', localPrayerTimes.dhuhr),
              MapEntry('asr', localPrayerTimes.asr),
              MapEntry('maghrib', localPrayerTimes.maghrib),
              MapEntry('isha', localPrayerTimes.isha),
            ];

        for (final prayer in prayers) {
          if (prayer.value.isAfter(now)) {
            await notificationService.scheduleAdhanNotification(
              prayer.key,
              prayer.value,
            );
          }
        }
      }
    } catch (_) {
      // The next periodic refresh or app launch will retry the rolling window.
    }
  }

  static Future<void> reschedule() async {
    await _schedulePrayerTasks();
  }

  static Future<List<MapEntry<String, DateTime>>?> _fetchAladhanTimes(
    DateTime date,
    Coordinates coordinates,
  ) async {
    try {
      final datePath = '${date.day.toString().padLeft(2, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-${date.year}';
      final uri = Uri.https(
        'api.aladhan.com',
        '/v1/timings/$datePath',
        {
          'latitude': coordinates.latitude.toString(),
          'longitude': coordinates.longitude.toString(),
          'method':
              PrayerLocationService.aladhanMethodIdFor(coordinates).toString(),
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['code'] != 200) return null;
      final data = body['data'] as Map<String, dynamic>?;
      final timings = data?['timings'] as Map<String, dynamic>?;
      if (timings == null) return null;

      DateTime parse(String key) {
        final match = RegExp(r'^(\d{1,2}):(\d{2})')
            .firstMatch(timings[key]?.toString() ?? '');
        if (match == null) throw const FormatException('Invalid prayer time');
        return DateTime(
          date.year,
          date.month,
          date.day,
          int.parse(match.group(1)!),
          int.parse(match.group(2)!),
        );
      }

      return <MapEntry<String, DateTime>>[
        MapEntry('fajr', parse('Fajr')),
        MapEntry('dhuhr', parse('Dhuhr')),
        MapEntry('asr', parse('Asr')),
        MapEntry('maghrib', parse('Maghrib')),
        MapEntry('isha', parse('Isha')),
      ];
    } catch (_) {
      return null;
    }
  }

  static Future<void> cancelAll() async {
    final now = DateTime.now();
    await PrayerNotificationService().cancelAllPendingAdhan();
    await Workmanager().cancelByUniqueName(prayerScheduleRefreshUniqueName);

    // Clean up the previous one-off scheduler during migration.
    await Workmanager().cancelByUniqueName(
      'reschedule-prayers-${now.year}-${now.month}-${now.day}',
    );
  }
}
