import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_widget_api_client.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_widget_session_cache.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final homePettyCashWidgetProvider =
    NotifierProvider<HomePettyCashWidgetNotifier, PettyCashWidgetRecord>(
  HomePettyCashWidgetNotifier.new,
);

class HomePettyCashWidgetNotifier extends Notifier<PettyCashWidgetRecord> {
  @override
  PettyCashWidgetRecord build() {
    ref.keepAlive();
    final instant = _instant();
    Future.microtask(_refresh);
    return instant;
  }

  PettyCashWidgetRecord _instant() {
    return _pettyCashFromLogin() ??
        HomeWidgetSessionCache.pettyCashRaw?.let(PettyCashWidgetRecord.fromMap) ??
        PettyCashWidgetRecord.empty();
  }

  Future<void> _refresh() async {
    await HomeWidgetApiClient.refreshIfStale(
      force: !HomeWidgetSessionCache.isFresh,
    );
    final raw = HomeWidgetSessionCache.pettyCashRaw;
    if (raw != null) state = PettyCashWidgetRecord.fromMap(raw);
  }
}

PettyCashWidgetRecord? _pettyCashFromLogin() {
  return SharedPref.getLoginData()
      .result
      ?.data
      ?.defaultWidgets
      ?.data
      ?.pettyCashWidget
      ?.pettyCashRecord;
}

extension _Let<T> on T {
  R let<R>(R Function(T value) fn) => fn(this);
}
