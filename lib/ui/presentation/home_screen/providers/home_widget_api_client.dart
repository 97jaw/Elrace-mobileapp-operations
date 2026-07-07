import 'dart:async';
import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_widget_session_cache.dart';
import 'package:http/http.dart' as http;

/// Parallel widget fetch — deduped in-flight, 8s timeout, session cache.
class HomeWidgetApiClient {
  HomeWidgetApiClient._();

  static const _base = 'https://erp.elrace.com/api';
  static const _timeout = Duration(seconds: 8);

  static Future<void>? _inFlight;

  /// Fetches all home category widgets in one parallel round-trip (deduped).
  static Future<void> refreshIfStale({bool force = false}) async {
    if (!force && HomeWidgetSessionCache.isFresh) return;

    if (_inFlight != null) {
      await _inFlight;
      return;
    }

    _inFlight = _fetchAll().whenComplete(() => _inFlight = null);
    await _inFlight;
  }

  static Future<void> _fetchAll() async {
    final token = SharedPref.getLoginDataOrNull()?.result?.token;
    if (token == null || token.isEmpty) return;

    final results = await Future.wait([
      _post('$_base/widgets/attendance/data', token),
      _post('$_base/widgets/hrms/data', token),
      _post('$_base/widgets/timesheet/data', token),
      _post('$_base/widgets/my_projects/data', token),
      _post('$_base/widgets/site_management/data', token),
      _post('$_base/widgets/my_reports/data', token),
      _post('$_base/widgets/lpo/data', token),
      _post('$_base/widgets/notes/data', token),
      _post('$_base/widgets/task_management/data', token),
      _post('$_base/widgets/tickets/data', token),
      _post('$_base/widgets/petty_cash/data', token),
      _post('$_base/widgets/my_documents/data', token),
      _post('$_base/widgets/media/data', token),
      _post('$_base/widgets/prayer_times/data', token),
    ]);

    if (results.any((r) => r != null)) {
      HomeWidgetSessionCache.store(
        attendanceRaw: results[0],
        hrmsRaw: results[1],
        timesheetRaw: results[2],
        myProjectsRaw: results[3],
        siteManagementRaw: results[4],
        myReportsRaw: results[5],
        lpoRaw: results[6],
        notesRaw: results[7],
        taskManagementRaw: results[8],
        ticketsRaw: results[9],
        pettyCashRaw: results[10],
        myDocumentsRaw: results[11],
        mediaRaw: results[12],
        prayerTimesRaw: results[13],
      );
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
