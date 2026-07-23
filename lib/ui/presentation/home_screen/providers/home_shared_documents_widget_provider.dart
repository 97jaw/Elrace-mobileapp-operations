import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_widget_api_client.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_widget_session_cache.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final homeSharedDocumentsWidgetProvider = NotifierProvider<
    HomeSharedDocumentsWidgetNotifier, SharedDocumentsWidgetRecord>(
  HomeSharedDocumentsWidgetNotifier.new,
);

class HomeSharedDocumentsWidgetNotifier
    extends Notifier<SharedDocumentsWidgetRecord> {
  @override
  SharedDocumentsWidgetRecord build() {
    ref.keepAlive();
    final instant = _instant();
    Future.microtask(_refresh);
    return instant;
  }

  SharedDocumentsWidgetRecord _instant() {
    return _fromLogin() ??
        HomeWidgetSessionCache.sharedDocumentsRaw
            ?.let(SharedDocumentsWidgetRecord.fromMap) ??
        SharedDocumentsWidgetRecord.empty();
  }

  Future<void> _refresh() async {
    await HomeWidgetApiClient.refreshIfStale(
      force: !HomeWidgetSessionCache.isFresh,
    );
    final raw = HomeWidgetSessionCache.sharedDocumentsRaw;
    if (raw != null) state = SharedDocumentsWidgetRecord.fromMap(raw);
  }
}

SharedDocumentsWidgetRecord? _fromLogin() {
  return SharedPref.getLoginData()
      .result
      ?.data
      ?.defaultWidgets
      ?.data
      ?.sharedDocumentsWidget
      ?.sharedDocumentsRecord;
}

extension _Let<T> on T {
  R let<R>(R Function(T value) fn) => fn(this);
}
