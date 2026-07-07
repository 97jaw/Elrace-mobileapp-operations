import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_widget_api_client.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_widget_session_cache.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final homeTimesheetWidgetProvider =
    NotifierProvider<HomeTimesheetWidgetNotifier, TimesheetWidgetRecord>(
  HomeTimesheetWidgetNotifier.new,
);

class HomeTimesheetWidgetNotifier extends Notifier<TimesheetWidgetRecord> {
  @override
  TimesheetWidgetRecord build() {
    ref.keepAlive();
    final instant = _instantData();
    Future.microtask(_refreshInBackground);
    return instant;
  }

  TimesheetWidgetRecord _instantData() {
    return _fromLoginCache() ??
        HomeWidgetSessionCache.timesheetRaw?.let(_fromApiMap) ??
        _empty();
  }

  Future<void> _refreshInBackground() async {
    await HomeWidgetApiClient.refreshIfStale(
      force: !HomeWidgetSessionCache.isFresh,
    );
    final raw = HomeWidgetSessionCache.timesheetRaw;
    if (raw == null) return;
    state = _fromApiMap(raw);
  }
}

TimesheetWidgetRecord? _fromLoginCache() {
  return SharedPref.getLoginData()
      .result
      ?.data
      ?.defaultWidgets
      ?.data
      ?.timesheetWidget
      ?.timesheetRecord;
}

TimesheetWidgetRecord _fromApiMap(Map<String, dynamic> map) {
  return TimesheetWidgetRecord.fromMap(map);
}

TimesheetWidgetRecord _empty() => const TimesheetWidgetRecord(
      totalHours: 0,
      overtimeHours: 0,
      avgPerWorker: 0,
      workersCount: 0,
      recordsCount: 0,
      projectsCount: 0,
      weekLabel: 'This Week',
      teamLabel: 'You',
      deltaVsLastWeek: 0,
      scope: 'self',
    );

extension _Let<T> on T {
  R let<R>(R Function(T value) fn) => fn(this);
}
