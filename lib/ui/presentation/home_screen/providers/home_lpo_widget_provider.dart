import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_widget_api_client.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_widget_session_cache.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final homeLpoWidgetProvider =
    NotifierProvider<HomeLpoWidgetNotifier, LpoWidgetRecord>(
  HomeLpoWidgetNotifier.new,
);

class HomeLpoWidgetNotifier extends Notifier<LpoWidgetRecord> {
  @override
  LpoWidgetRecord build() {
    ref.keepAlive();
    final instant = _instant();
    Future.microtask(_refresh);
    return instant;
  }

  LpoWidgetRecord _instant() {
    return _lpoFromLogin() ??
        HomeWidgetSessionCache.lpoRaw?.let(LpoWidgetRecord.fromMap) ??
        LpoWidgetRecord.empty();
  }

  Future<void> _refresh() async {
    await HomeWidgetApiClient.refreshIfStale(
      force: !HomeWidgetSessionCache.isFresh,
    );
    final raw = HomeWidgetSessionCache.lpoRaw;
    if (raw != null) state = LpoWidgetRecord.fromMap(raw);
  }
}

LpoWidgetRecord? _lpoFromLogin() {
  return SharedPref.getLoginData()
      .result
      ?.data
      ?.defaultWidgets
      ?.data
      ?.lpoWidget
      ?.lpoRecord;
}

extension _Let<T> on T {
  R let<R>(R Function(T value) fn) => fn(this);
}
