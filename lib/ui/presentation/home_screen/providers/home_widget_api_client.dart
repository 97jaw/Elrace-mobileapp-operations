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

  static Future<void>? _inFlight;

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

  /// Fetches home category widgets in one parallel round-trip (deduped).
  ///
  /// Only widgets visible per login prefs are fetched; pass [onlyCodes] to
  /// narrow further.
  static Future<void> refreshIfStale({
    bool force = false,
    Set<HomeWidgetCode>? onlyCodes,
  }) async {
    if (!force && HomeWidgetSessionCache.isFresh) return;

    if (_inFlight != null) {
      await _inFlight;
      return;
    }

    _inFlight = _fetchAll(onlyCodes: onlyCodes).whenComplete(() => _inFlight = null);
    await _inFlight;
  }

  static Future<void> _fetchAll({Set<HomeWidgetCode>? onlyCodes}) async {
    final token = SharedPref.getLoginDataOrNull()?.result?.token;
    if (token == null || token.isEmpty) return;

    // Hidden widgets are never fetched, even when callers don't narrow.
    final visibility = HomeWidgetVisibility.fromLoginPref();
    final targets = _fetchOrder.where((entry) {
      final code = entry.code;
      if (code == null) return true;
      if (!visibility.isVisible(code)) return false;
      if (onlyCodes == null) return true;
      return onlyCodes.contains(code);
    }).toList();

    if (targets.isEmpty) return;

    final results = await Future.wait(
      targets.map((entry) => _post('$_base/widgets/${entry.path}/data', token)),
    );

    for (var i = 0; i < targets.length; i++) {
      _applyResult(targets[i].path, results[i]);
    }

    if (results.any((r) => r != null)) {
      HomeWidgetSessionCache.markFetched();
    }
  }

  static void _applyResult(String path, Map<String, dynamic>? raw) {
    switch (path) {
      case 'attendance':
        if (raw != null) HomeWidgetSessionCache.attendanceRaw = raw;
      case 'hrms':
        if (raw != null) HomeWidgetSessionCache.hrmsRaw = raw;
      case 'timesheet':
        if (raw != null) HomeWidgetSessionCache.timesheetRaw = raw;
      case 'my_projects':
        if (raw != null) HomeWidgetSessionCache.myProjectsRaw = raw;
      case 'site_management':
        if (raw != null) HomeWidgetSessionCache.siteManagementRaw = raw;
      case 'my_reports':
        if (raw != null) HomeWidgetSessionCache.myReportsRaw = raw;
      case 'clients':
        if (raw != null) HomeWidgetSessionCache.clientsRaw = raw;
      case 'vendors':
        if (raw != null) HomeWidgetSessionCache.vendorsRaw = raw;
      case 'lpo':
        if (raw != null) HomeWidgetSessionCache.lpoRaw = raw;
      case 'notes':
        if (raw != null) HomeWidgetSessionCache.notesRaw = raw;
      case 'task_management':
        if (raw != null) HomeWidgetSessionCache.taskManagementRaw = raw;
      case 'tickets':
        if (raw != null) HomeWidgetSessionCache.ticketsRaw = raw;
      case 'shared_documents':
        if (raw != null) HomeWidgetSessionCache.sharedDocumentsRaw = raw;
      case 'petty_cash':
        if (raw != null) HomeWidgetSessionCache.pettyCashRaw = raw;
      case 'my_documents':
        if (raw != null) HomeWidgetSessionCache.myDocumentsRaw = raw;
      case 'media':
        if (raw != null) HomeWidgetSessionCache.mediaRaw = raw;
      case 'prayer_times':
        if (raw != null) HomeWidgetSessionCache.prayerTimesRaw = raw;
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
