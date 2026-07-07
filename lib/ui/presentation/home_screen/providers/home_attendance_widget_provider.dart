import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_widget_api_client.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_widget_session_cache.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Week-day chip state for the home attendance widget (Sun → Sat).
enum HomeAttendanceWeekDayState {
  present,
  absent,
  today,
  todayPresent,
  future,
  empty,
}

class HomeAttendanceWidgetData {
  const HomeAttendanceWidgetData({
    required this.presentDays,
    required this.workingDays,
    required this.attendancePercent,
    required this.weekDayStates,
  });

  final int presentDays;
  final int workingDays;
  final int attendancePercent;
  final List<HomeAttendanceWeekDayState> weekDayStates;

  static HomeAttendanceWidgetData? fromLoginCache() {
    final map = SharedPref.getLoginData()
        .result
        ?.data
        ?.defaultWidgets
        ?.data
        ?.attendanceWidget
        ?.recordMap;
    if (map == null) return null;

    final present = _readInt(map['present_days'] ?? map['present']);
    var working = _readInt(map['working_days']);
    if (working <= 0) {
      working = present + _readInt(map['absent']);
    }
    if (present <= 0 && working <= 0) return null;

    final pct = map['percentage'] != null
        ? _readInt(map['percentage'])
        : (working > 0 ? ((present / working) * 100).round() : 0);

    return HomeAttendanceWidgetData(
      presentDays: present,
      workingDays: working,
      attendancePercent: pct,
      weekDayStates: _defaultWeekStates(),
    );
  }

  static HomeAttendanceWidgetData? fromApiMap(Map<String, dynamic> map) {
    final present = _readInt(map['present_days'] ?? map['present']);
    final working = _readInt(map['working_days']);
    if (present <= 0 && working <= 0) return null;

    final pct = map['percentage'] != null
        ? _readInt(map['percentage'])
        : (working > 0 ? ((present / working) * 100).round() : 0);

    return HomeAttendanceWidgetData(
      presentDays: present,
      workingDays: working,
      attendancePercent: pct,
      weekDayStates: _defaultWeekStates(),
    );
  }

  static HomeAttendanceWidgetData empty() => HomeAttendanceWidgetData(
        presentDays: 0,
        workingDays: 0,
        attendancePercent: 0,
        weekDayStates: _defaultWeekStates(),
      );
}

final homeAttendanceWidgetProvider =
    NotifierProvider<HomeAttendanceWidgetNotifier, HomeAttendanceWidgetData>(
  HomeAttendanceWidgetNotifier.new,
);

class HomeAttendanceWidgetNotifier extends Notifier<HomeAttendanceWidgetData> {
  @override
  HomeAttendanceWidgetData build() {
    ref.keepAlive();
    final instant = _instantData();
    Future.microtask(_refreshInBackground);
    return instant;
  }

  HomeAttendanceWidgetData _instantData() {
    return HomeAttendanceWidgetData.fromLoginCache() ??
        HomeWidgetSessionCache.attendanceRaw
            ?.let(HomeAttendanceWidgetData.fromApiMap) ??
        HomeAttendanceWidgetData.empty();
  }

  Future<void> _refreshInBackground() async {
    await HomeWidgetApiClient.refreshIfStale(
      force: !HomeWidgetSessionCache.isFresh,
    );
    final raw = HomeWidgetSessionCache.attendanceRaw;
    if (raw == null) return;
    final fresh = HomeAttendanceWidgetData.fromApiMap(raw);
    if (fresh == null) return;
    state = fresh;
  }
}

extension _Let<T> on T {
  R? let<R>(R? Function(T value) fn) => fn(this);
}

List<HomeAttendanceWeekDayState> _defaultWeekStates() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final weekStart = today.subtract(Duration(days: today.weekday % 7));

  return List.generate(7, (index) {
    final day = weekStart.add(Duration(days: index));
    if (day.isAfter(today)) return HomeAttendanceWeekDayState.future;
    if (day == today) return HomeAttendanceWeekDayState.today;
    return HomeAttendanceWeekDayState.empty;
  });
}

int _readInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
