import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_widget_api_client.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_widget_session_cache.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final homeMyDocumentsWidgetProvider =
    NotifierProvider<HomeMyDocumentsWidgetNotifier, MyDocumentsWidgetRecord>(
  HomeMyDocumentsWidgetNotifier.new,
);

final homeMediaWidgetProvider =
    NotifierProvider<HomeMediaWidgetNotifier, MediaWidgetRecord>(
  HomeMediaWidgetNotifier.new,
);

final homePrayerTimesWidgetProvider =
    NotifierProvider<HomePrayerTimesWidgetNotifier, PrayerTimesWidgetRecord>(
  HomePrayerTimesWidgetNotifier.new,
);

class HomeMyDocumentsWidgetNotifier extends Notifier<MyDocumentsWidgetRecord> {
  @override
  MyDocumentsWidgetRecord build() {
    ref.keepAlive();
    final instant = _instant();
    Future.microtask(_refresh);
    return instant;
  }

  MyDocumentsWidgetRecord _instant() {
    return _myDocumentsFromLogin() ??
        HomeWidgetSessionCache.myDocumentsRaw
            ?.let(MyDocumentsWidgetRecord.fromMap) ??
        MyDocumentsWidgetRecord.empty();
  }

  Future<void> _refresh() async {
    await HomeWidgetApiClient.refreshIfStale(
      force: !HomeWidgetSessionCache.isFresh,
    );
    final raw = HomeWidgetSessionCache.myDocumentsRaw;
    if (raw != null) state = MyDocumentsWidgetRecord.fromMap(raw);
  }
}

class HomeMediaWidgetNotifier extends Notifier<MediaWidgetRecord> {
  @override
  MediaWidgetRecord build() {
    ref.keepAlive();
    final instant = _instant();
    Future.microtask(_refresh);
    return instant;
  }

  MediaWidgetRecord _instant() {
    return _mediaFromLogin() ??
        HomeWidgetSessionCache.mediaRaw?.let(MediaWidgetRecord.fromMap) ??
        MediaWidgetRecord.empty();
  }

  Future<void> _refresh() async {
    await HomeWidgetApiClient.refreshIfStale(
      force: !HomeWidgetSessionCache.isFresh,
    );
    final raw = HomeWidgetSessionCache.mediaRaw;
    if (raw != null) state = MediaWidgetRecord.fromMap(raw);
  }
}

class HomePrayerTimesWidgetNotifier extends Notifier<PrayerTimesWidgetRecord> {
  @override
  PrayerTimesWidgetRecord build() {
    ref.keepAlive();
    final instant = _instant();
    Future.microtask(_refresh);
    return instant;
  }

  PrayerTimesWidgetRecord _instant() {
    return _prayerFromLogin() ??
        HomeWidgetSessionCache.prayerTimesRaw
            ?.let(PrayerTimesWidgetRecord.fromMap) ??
        PrayerTimesWidgetRecord.empty();
  }

  Future<void> _refresh() async {
    await HomeWidgetApiClient.refreshIfStale(
      force: !HomeWidgetSessionCache.isFresh,
    );
    final raw = HomeWidgetSessionCache.prayerTimesRaw;
    if (raw != null) state = PrayerTimesWidgetRecord.fromMap(raw);
  }
}

MyDocumentsWidgetRecord? _myDocumentsFromLogin() {
  return SharedPref.getLoginData()
      .result
      ?.data
      ?.defaultWidgets
      ?.data
      ?.myDocumentsWidget
      ?.myDocumentsRecord;
}

MediaWidgetRecord? _mediaFromLogin() {
  return SharedPref.getLoginData()
      .result
      ?.data
      ?.defaultWidgets
      ?.data
      ?.mediaWidget
      ?.mediaRecord;
}

PrayerTimesWidgetRecord? _prayerFromLogin() {
  return SharedPref.getLoginData()
      .result
      ?.data
      ?.defaultWidgets
      ?.data
      ?.prayerTimesWidget
      ?.prayerTimesRecord;
}

extension _Let<T> on T {
  R let<R>(R Function(T value) fn) => fn(this);
}
