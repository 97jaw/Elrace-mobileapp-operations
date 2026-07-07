import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_widget_api_client.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_widget_session_cache.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final homeTicketsWidgetProvider =
    NotifierProvider<HomeTicketsWidgetNotifier, TicketsWidgetRecord>(
  HomeTicketsWidgetNotifier.new,
);

class HomeTicketsWidgetNotifier extends Notifier<TicketsWidgetRecord> {
  @override
  TicketsWidgetRecord build() {
    ref.keepAlive();
    final instant = _instant();
    Future.microtask(_refresh);
    return instant;
  }

  TicketsWidgetRecord _instant() {
    return _ticketsFromLogin() ??
        HomeWidgetSessionCache.ticketsRaw?.let(TicketsWidgetRecord.fromMap) ??
        TicketsWidgetRecord.empty();
  }

  Future<void> _refresh() async {
    await HomeWidgetApiClient.refreshIfStale(
      force: !HomeWidgetSessionCache.isFresh,
    );
    final raw = HomeWidgetSessionCache.ticketsRaw;
    if (raw != null) state = TicketsWidgetRecord.fromMap(raw);
  }
}

TicketsWidgetRecord? _ticketsFromLogin() {
  return SharedPref.getLoginData()
      .result
      ?.data
      ?.defaultWidgets
      ?.data
      ?.ticketsWidget
      ?.ticketsRecord;
}

extension _Let<T> on T {
  R let<R>(R Function(T value) fn) => fn(this);
}
