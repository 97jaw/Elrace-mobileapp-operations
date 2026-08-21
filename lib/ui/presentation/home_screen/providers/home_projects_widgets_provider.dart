import 'package:el_race/core/home/home_widget_visibility.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_widget_api_client.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_widget_session_cache.dart';
import 'package:el_race/ui/presentation/my_projects/data/datasources/project_remote_datasource.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final homeMyProjectsWidgetProvider =
    NotifierProvider<HomeMyProjectsWidgetNotifier, MyProjectsWidgetRecord>(
  HomeMyProjectsWidgetNotifier.new,
);

final homeSiteManagementWidgetProvider = NotifierProvider<
    HomeSiteManagementWidgetNotifier, SiteManagementWidgetRecord>(
  HomeSiteManagementWidgetNotifier.new,
);

final homeMyReportsWidgetProvider =
    NotifierProvider<HomeMyReportsWidgetNotifier, MyReportsWidgetRecord>(
  HomeMyReportsWidgetNotifier.new,
);

class HomeMyProjectsWidgetNotifier extends Notifier<MyProjectsWidgetRecord> {
  @override
  MyProjectsWidgetRecord build() {
    ref.keepAlive();
    final instant = _instant();
    Future.microtask(_refresh);
    return instant;
  }

  MyProjectsWidgetRecord _instant() {
    return _myProjectsFromLogin() ??
        HomeWidgetSessionCache.myProjectsRaw
            ?.let(MyProjectsWidgetRecord.fromMap) ??
        MyProjectsWidgetRecord.empty();
  }

  Future<void> _refresh() async {
    // Always target this endpoint — a prior failed warm of *other* widgets
    // must not leave My Projects stuck on empty keepAlive state.
    await HomeWidgetApiClient.refreshIfStale(
      force: HomeWidgetSessionCache.myProjectsRaw == null,
      onlyCodes: const {HomeWidgetCode.myProjects},
    );

    final raw = HomeWidgetSessionCache.myProjectsRaw;
    var record = raw != null
        ? MyProjectsWidgetRecord.fromMap(raw)
        : _myProjectsFromLogin() ?? state;

    if (record.topProjects.isEmpty) {
      record = await _enrichTopProjects(record);
    }
    state = record;
  }

  Future<MyProjectsWidgetRecord> _enrichTopProjects(
    MyProjectsWidgetRecord record,
  ) async {
    try {
      final projects = await ProjectRemoteDataSource().fetchProjects(
        maxItems: 3,
      );
      if (projects.isEmpty) return record;

      final top = projects
          .map(
            (p) => MyProjectsTopProject(
              id: p.projectId,
              name: p.name,
              progressPct: p.totalProgress ?? 0,
              statusColor: 'mid',
              isOverdue: false,
            ),
          )
          .toList(growable: false);

      final total =
          record.totalActive > 0 ? record.totalActive : projects.length;
      return MyProjectsWidgetRecord(
        totalActive: total,
        dueThisWeekCount: record.dueThisWeekCount,
        topProjects: top,
        moreProjectsCount: total > top.length ? total - top.length : 0,
      );
    } catch (_) {
      return record;
    }
  }
}

class HomeSiteManagementWidgetNotifier
    extends Notifier<SiteManagementWidgetRecord> {
  @override
  SiteManagementWidgetRecord build() {
    ref.keepAlive();
    final instant = _instant();
    Future.microtask(_refresh);
    return instant;
  }

  SiteManagementWidgetRecord _instant() {
    return _siteFromLogin() ??
        HomeWidgetSessionCache.siteManagementRaw
            ?.let(SiteManagementWidgetRecord.fromMap) ??
        SiteManagementWidgetRecord.empty();
  }

  Future<void> _refresh() async {
    await HomeWidgetApiClient.refreshIfStale(
      force: HomeWidgetSessionCache.siteManagementRaw == null,
      onlyCodes: const {HomeWidgetCode.siteManagement},
    );
    final raw = HomeWidgetSessionCache.siteManagementRaw;
    if (raw != null) {
      state = SiteManagementWidgetRecord.fromMap(raw);
    } else {
      final fromLogin = _siteFromLogin();
      if (fromLogin != null) state = fromLogin;
    }
  }
}

class HomeMyReportsWidgetNotifier extends Notifier<MyReportsWidgetRecord> {
  @override
  MyReportsWidgetRecord build() {
    ref.keepAlive();
    final instant = _instant();
    Future.microtask(_refresh);
    return instant;
  }

  MyReportsWidgetRecord _instant() {
    return _reportsFromLogin() ??
        HomeWidgetSessionCache.myReportsRaw
            ?.let(MyReportsWidgetRecord.fromMap) ??
        MyReportsWidgetRecord.empty();
  }

  Future<void> _refresh() async {
    await HomeWidgetApiClient.refreshIfStale(
      force: HomeWidgetSessionCache.myReportsRaw == null,
      onlyCodes: const {HomeWidgetCode.myReports},
    );
    final raw = HomeWidgetSessionCache.myReportsRaw;
    if (raw != null) {
      state = MyReportsWidgetRecord.fromMap(raw);
    } else {
      final fromLogin = _reportsFromLogin();
      if (fromLogin != null) state = fromLogin;
    }
  }
}

MyProjectsWidgetRecord? _myProjectsFromLogin() {
  return SharedPref.getLoginData()
      .result
      ?.data
      ?.defaultWidgets
      ?.data
      ?.myProjectsWidget
      ?.myProjectsRecord;
}

SiteManagementWidgetRecord? _siteFromLogin() {
  return SharedPref.getLoginData()
      .result
      ?.data
      ?.defaultWidgets
      ?.data
      ?.siteManagementWidget
      ?.siteManagementRecord;
}

MyReportsWidgetRecord? _reportsFromLogin() {
  return SharedPref.getLoginData()
      .result
      ?.data
      ?.defaultWidgets
      ?.data
      ?.myReportsWidget
      ?.myReportsRecord;
}

extension _Let<T> on T {
  R let<R>(R Function(T value) fn) => fn(this);
}
