import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/attendance_checkin/models/checkin_context_model.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:el_race/utils/urll_utils.dart';
import 'package:http/http.dart' as http;

class CheckinContextRepository {
  Future<CheckinContextModel> fetchCheckinContext() async {
    final token = await _resolveToken();
    if (token == null || token.isEmpty) {
      throw Exception('No valid session. Token is missing.');
    }

    final url = Uri.parse('${UrlUtil.baseUrl}${UrlUtil.checkinContextApi}');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'params': {},
    });

    final request = http.Request('POST', url)
      ..headers.addAll(headers)
      ..body = body;

    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode != 200) {
      throw Exception('Failed to load check-in context: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    final result = decoded['result'];
    if (result is! Map) {
      throw Exception('Invalid check-in context response.');
    }

    if (result['status'] == 'error') {
      throw Exception(result['message']?.toString() ?? 'Check-in context error.');
    }

    final data = result['data'];
    if (data is! Map) {
      throw Exception('Check-in context data is missing.');
    }

    return CheckinContextModel.fromJson(Map<String, dynamic>.from(data));
  }

  /// Map search panel: staff_list + supervisor projects with coordinates.
  Future<List<CheckinAllowedProject>> fetchCheckinMapProjects({
    String? keyword,
  }) async {
    final token = await _resolveToken();
    if (token == null || token.isEmpty) {
      throw Exception('No valid session. Token is missing.');
    }

    final url = Uri.parse('${UrlUtil.baseUrl}${UrlUtil.checkinProjectsApi}');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final params = <String, dynamic>{};
    if (keyword != null && keyword.trim().isNotEmpty) {
      params['keyword'] = keyword.trim();
    }
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'params': params,
    });

    final request = http.Request('POST', url)
      ..headers.addAll(headers)
      ..body = body;

    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode != 200) {
      throw Exception('Failed to load check-in projects: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    final result = decoded['result'];
    if (result is! Map) {
      throw Exception('Invalid checkin_projects response.');
    }

    if (result['status'] == 'error') {
      throw Exception(
        result['message']?.toString() ?? 'checkin_projects error.',
      );
    }

    final data = result['data'];
    if (data is! List) {
      throw Exception('Check-in project list is missing.');
    }

    return data
        .whereType<Map>()
        .map(
          (row) => CheckinAllowedProject.fromJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList();
  }

  Future<Map<String, dynamic>> validateUserLocation({
    required int projectId,
    required double latitude,
    required double longitude,
  }) async {
    final token = await _resolveToken();
    if (token == null || token.isEmpty) {
      throw Exception('No valid session. Token is missing.');
    }

    final url = Uri.parse('${UrlUtil.baseUrl}${UrlUtil.validateUserLocationApi}');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'jsonrpc': '2.0',
        'params': {
          'project_id': projectId,
          'check_in_lat': latitude,
          'check_in_long': longitude,
          'office': null,
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Location validation failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    final result = decoded['result'];
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    return {'status': 'error', 'message': 'Invalid validation response.'};
  }

  Future<String?> _resolveToken() async {
    var token = SharedPref.getLoginData().result?.token;
    if (token != null && token.isNotEmpty) return token;

    final storedData = SharedPref().getPreferenceString('loginResponse');
    if (storedData.isEmpty) return null;

    final jsonData = jsonDecode(storedData);
    final storedLoginResponse = LoginResponseModel.fromJson(jsonData);
    return storedLoginResponse.result?.token;
  }
}
