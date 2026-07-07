import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_widget_api_client.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_widget_session_cache.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final homeNotesWidgetProvider =
    NotifierProvider<HomeNotesWidgetNotifier, NotesWidgetRecord>(
  HomeNotesWidgetNotifier.new,
);

class HomeNotesWidgetNotifier extends Notifier<NotesWidgetRecord> {
  @override
  NotesWidgetRecord build() {
    ref.keepAlive();
    final instant = _instant();
    Future.microtask(_refresh);
    return instant;
  }

  NotesWidgetRecord _instant() {
    return _notesFromLogin() ??
        HomeWidgetSessionCache.notesRaw?.let(NotesWidgetRecord.fromMap) ??
        NotesWidgetRecord.empty();
  }

  Future<void> _refresh() async {
    await HomeWidgetApiClient.refreshIfStale(
      force: !HomeWidgetSessionCache.isFresh,
    );
    final raw = HomeWidgetSessionCache.notesRaw;
    if (raw != null) state = NotesWidgetRecord.fromMap(raw);
  }
}

NotesWidgetRecord? _notesFromLogin() {
  return SharedPref.getLoginData()
      .result
      ?.data
      ?.defaultWidgets
      ?.data
      ?.myNotesWidget
      ?.notesRecord;
}

extension _Let<T> on T {
  R let<R>(R Function(T value) fn) => fn(this);
}
