import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_widget_api_client.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_widget_session_cache.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final homeTaskManagementWidgetProvider =
    NotifierProvider<HomeTaskManagementWidgetNotifier, TaskManagementWidgetRecord>(
  HomeTaskManagementWidgetNotifier.new,
);

class HomeTaskManagementWidgetNotifier
    extends Notifier<TaskManagementWidgetRecord> {
  @override
  TaskManagementWidgetRecord build() {
    ref.keepAlive();
    final instant = _instant();
    Future.microtask(_refresh);
    return instant;
  }

  TaskManagementWidgetRecord _instant() {
    return _taskManagementFromLogin() ??
        HomeWidgetSessionCache.taskManagementRaw
            ?.let(TaskManagementWidgetRecord.fromMap) ??
        TaskManagementWidgetRecord.empty();
  }

  Future<void> _refresh() async {
    await HomeWidgetApiClient.refreshIfStale(
      force: !HomeWidgetSessionCache.isFresh,
    );
    final raw = HomeWidgetSessionCache.taskManagementRaw;
    if (raw != null) state = TaskManagementWidgetRecord.fromMap(raw);
  }
}

TaskManagementWidgetRecord? _taskManagementFromLogin() {
  return SharedPref.getLoginData()
      .result
      ?.data
      ?.defaultWidgets
      ?.data
      ?.taskManagementWidget
      ?.taskManagementRecord;
}

extension _Let<T> on T {
  R let<R>(R Function(T value) fn) => fn(this);
}
