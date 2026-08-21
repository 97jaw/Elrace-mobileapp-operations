import 'dart:async';
import 'dart:convert';

import 'package:el_race/core/home/home_widget_visibility.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_widget_session_cache.dart';
import 'package:http/http.dart' as http;

/// Parallel widget fetch — deduped in-flight, 8s timeout, session cache.
class HomeWidgetApiClient {
  HomeWidgetApiClient._();

  static const _base = 'https://erp.elrace.com/api';
  static const _timeout = Duration(seconds: 8);

  /// In-flight requests keyed by endpoint path. Keyed per endpoint rather than
  /// globally so a caller narrowing to one widget cannot define the fetch scope
  /// for every other widget that races it on home build.
  static final Map<String, Future<void>> _inFlightByPath = {};

  // Endpoints that the home UI actually consumes. Removed (never read by UI):
  // sub_contractors (merged into vendors), task_management
  // (UI uses TodoFirebaseProvider), tickets (UI uses TasksProvider),
  // prayer_times (UI uses Aladhan via HomeBloc).
  static const _fetchOrder = <_WidgetFetch>[
    _WidgetFetch(HomeWidgetCode.attendance, 'attendance'),
    _WidgetFetch(HomeWidgetCode.hrms, 'hrms'),
    _WidgetFetch(HomeWidgetCode.timesheet, 'timesheet'),
    _WidgetFetch(HomeWidgetCode.myProjects, 'my_projects'),
    _WidgetFetch(HomeWidgetCode.siteManagement, 'site_management'),
    _WidgetFetch(HomeWidgetCode.myReports, 'my_reports'),
    _WidgetFetch(HomeWidgetCode.clients, 'clients'),
    _WidgetFetch(HomeWidgetCode.vendors, 'vendors'),
    _WidgetFetch(HomeWidgetCode.lpo, 'lpo'),
    _WidgetFetch(HomeWidgetCode.notes, 'notes'),
    _WidgetFetch(HomeWidgetCode.sharedDocuments, 'shared_documents'),
    _WidgetFetch(HomeWidgetCode.pettyCash, 'petty_cash'),
    _WidgetFetch(HomeWidgetCode.myDocuments, 'my_documents'),
    _WidgetFetch(HomeWidgetCode.media, 'media'),
  ];

  /// Fetches home category widgets in parallel, deduped per endpoint.
  ///
  /// Only widgets visible per login prefs are fetched; pass [onlyCodes] to
  /// narrow further. Narrowing affects only the caller's own endpoints —
  /// concurrent callers each still get the widgets they asked for.
  static Future<void> refreshIfStale({
    bool force = false,
    Set<HomeWidgetCode>? onlyCodes,
  }) async {
    final token = SharedPref.getLoginDataOrNull()?.result?.token;
    if (token == null || token.isEmpty) return;

    // Hidden widgets are never fetched, even when callers don't narrow.
    final visibility = HomeWidgetVisibility.fromLoginPref();
    final pending = <Future<void>>[];

    for (final entry in _fetchOrder) {
      final code = entry.code;
      if (code != null) {
        if (!visibility.isVisible(code)) continue;
        if (onlyCodes != null && !onlyCodes.contains(code)) continue;
      }

      final path = entry.path;

      // Join an identical request already running instead of issuing a second.
      final inFlight = _inFlightByPath[path];
      if (inFlight != null) {
        pending.add(inFlight);
        continue;
      }

      if (!force && HomeWidgetSessionCache.isPathFresh(path)) continue;

      final future = _fetchOne(path, token)
          .whenComplete(() => _inFlightByPath.remove(path));
      _inFlightByPath[path] = future;
      pending.add(future);
    }

    if (pending.isEmpty) return;
    await Future.wait(pending);
  }

  /// Marks the endpoint fresh only when data actually arrived, so a timeout
  /// cannot lock an empty widget out of retrying for the whole TTL.
  static Future<void> _fetchOne(String path, String token) async {
    final raw = await _post('$_base/widgets/$path/data', token);
    if (raw == null) return;
    _applyResult(path, raw);
    HomeWidgetSessionCache.markPathFetched(path);
  }

  static void _applyResult(String path, Map<String, dynamic>? raw) {
    if (raw == null) return;
    switch (path) {
      case 'attendance':
        HomeWidgetSessionCache.attendanceRaw = raw;
        return;
      case 'hrms':
        HomeWidgetSessionCache.hrmsRaw = raw;
        return;
      case 'timesheet':
        HomeWidgetSessionCache.timesheetRaw = raw;
        return;
      case 'my_projects':
        HomeWidgetSessionCache.myProjectsRaw = raw;
        return;
      case 'site_management':
        HomeWidgetSessionCache.siteManagementRaw = raw;
        return;
      case 'my_reports':
        HomeWidgetSessionCache.myReportsRaw = raw;
        return;
      case 'clients':
        HomeWidgetSessionCache.clientsRaw = raw;
        return;
      case 'vendors':
        HomeWidgetSessionCache.vendorsRaw = raw;
        return;
      case 'lpo':
        HomeWidgetSessionCache.lpoRaw = raw;
        return;
      case 'notes':
        HomeWidgetSessionCache.notesRaw = raw;
        return;
      case 'task_management':
        HomeWidgetSessionCache.taskManagementRaw = raw;
        return;
      case 'tickets':
        HomeWidgetSessionCache.ticketsRaw = raw;
        return;
      case 'shared_documents':
        HomeWidgetSessionCache.sharedDocumentsRaw = raw;
        return;
      case 'petty_cash':
        HomeWidgetSessionCache.pettyCashRaw = raw;
        return;
      case 'my_documents':
        HomeWidgetSessionCache.myDocumentsRaw = raw;
        return;
      case 'media':
        HomeWidgetSessionCache.mediaRaw = raw;
        return;
      case 'prayer_times':
        HomeWidgetSessionCache.prayerTimesRaw = raw;
        return;
    }
  }

  static Future<Map<String, dynamic>?> _post(String url, String token) async {
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'jsonrpc': '2.0',
              'method': 'call',
              'params': {},
            }),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      final result = decoded is Map ? decoded['result'] : null;
      if (result is! Map || result['status']?.toString() != 'success') {
        return null;
      }
      final data = result['data'];
      if (data is Map) return Map<String, dynamic>.from(data);
      return null;
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }
}

class _WidgetFetch {
  const _WidgetFetch(this.code, this.path);

  final HomeWidgetCode? code;
  final String path;
}
