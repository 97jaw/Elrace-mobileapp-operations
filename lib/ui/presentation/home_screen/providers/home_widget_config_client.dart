import 'dart:async';
import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:http/http.dart' as http;

/// Fetches lightweight widget visibility (`is_disabled`) without full login.
class HomeWidgetConfigClient {
  HomeWidgetConfigClient._();

  static const _url = 'https://erp.elrace.com/api/widgets/config';
  static const _timeout = Duration(seconds: 5);

  static Future<bool> refresh() async {
    final token = SharedPref.getLoginDataOrNull()?.result?.token;
    if (token == null || token.isEmpty) return false;

    try {
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
      if (result is! Map || result['status']?.toString() != 'success') {
        return false;
      }

      final data = result['data'];
      if (data is! Map) return false;

      return SharedPref.mergeDefaultWidgetsVisibility(
        Map<String, dynamic>.from(data),
      );
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
