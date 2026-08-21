import 'dart:async';
import 'dart:convert';

import 'package:el_race/core/home/home_widget_visibility.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Pulls live `is_disabled` flags from `/api/widgets/config` and merges them
/// into the cached login payload.
///
/// Home sections are gated by login `default_widgets.*.is_disabled`. That map
/// used to be frozen until the next full login — after a bundle-id upgrade the
/// restored session often carried stale flags, so Management users could lose
/// Projects / Clients / Vendors until they logged out.
class HomeWidgetVisibilityRefresh {
  HomeWidgetVisibilityRefresh._();

  static const _url = 'https://erp.elrace.com/api/widgets/config';
  static const _timeout = Duration(seconds: 8);

  static Future<void>? _inFlight;

  /// Returns true when cached visibility flags were updated.
  static Future<bool> refresh() async {
    if (_inFlight != null) {
      await _inFlight;
      return false;
    }

    final completer = Completer<bool>();
    _inFlight = completer.future.whenComplete(() => _inFlight = null);

    try {
      final updated = await _fetchAndMerge();
      completer.complete(updated);
      return updated;
    } catch (e, st) {
      debugPrint('HomeWidgetVisibilityRefresh failed: $e\n$st');
      completer.complete(false);
      return false;
    }
  }

  static Future<bool> _fetchAndMerge() async {
    final token = SharedPref.getLoginDataOrNull()?.result?.token;
    if (token == null || token.isEmpty) return false;

    final response = await http
        .post(
          Uri.parse(_url),
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

    if (response.statusCode != 200) return false;

    final decoded = jsonDecode(response.body);
    final result = decoded is Map ? decoded['result'] : null;
    if (result is! Map) return false;

    final status = result['status']?.toString();
    if (status != null && status != 'success') return false;

    final data = result['data'];
    if (data is! Map) return false;

    final flags = Map<String, dynamic>.from(data);
    final merged = await SharedPref.mergeDefaultWidgetDisabledFlags(flags);
    if (merged) {
      HomeWidgetVisibility.debugDumpLoginFlags();
      _logVisibilitySnapshot();
    }
    return merged;
  }

  static void _logVisibilitySnapshot() {
    final v = HomeWidgetVisibility.fromLoginPref();
    debugPrint(
      'HOME WIDGETS visibility refreshed → '
      'projects=${v.hasVisibleProjects} '
      'clientsVendors=${v.hasVisibleClientsVendors} '
      'myProjects=${v.isVisible(HomeWidgetCode.myProjects)} '
      'site=${v.isVisible(HomeWidgetCode.siteManagement)} '
      'clients=${v.isVisible(HomeWidgetCode.clients)} '
      'vendors=${v.isVisible(HomeWidgetCode.vendors)}',
    );
  }
}
