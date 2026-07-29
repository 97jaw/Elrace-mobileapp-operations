import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/my_actions/data/my_actions_models.dart';
import 'package:el_race/utils/api_query.dart';
import 'package:el_race/utils/urll_utils.dart';
import 'package:http/http.dart' as http;

class MyActionsRepository {
  static const int defaultPerPage = 10;

  final ApiQuery _apiQuery;

  MyActionsRepository({ApiQuery? apiQuery})
      : _apiQuery = apiQuery ?? ApiQuery();

  Future<List<MyActionItem>> fetchByType(
    MyActionsType type, {
    int page = 1,
    int perPage = defaultPerPage,
    String keyword = '',
  }) async {
    final token = SharedPref.getLoginDataOrNull()?.result?.token;
    if (token == null || token.isEmpty) {
      throw Exception('Invalid token');
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final Map<String, dynamic> params = {
      'type': type.apiValue,
      'page': page,
      'per_page': perPage,
    };
    if (keyword.trim().isNotEmpty) {
      params['keyword'] = keyword.trim();
    }

    final body = {
      'jsonrpc': '2.0',
      'params': params,
    };

    final Response? response = await _apiQuery.postQuery(
      UrlUtil.myActionsApi,
      headers,
      body,
      'my_actions_${type.apiValue}',
      true,
    );

    if (response == null) {
      throw Exception('No response from server');
    }

    if (response.statusCode != 200) {
      throw Exception('My actions HTTP ${response.statusCode}');
    }

    final dynamic payload = response.data is String
        ? jsonDecode(response.data as String)
        : response.data;

    if (payload is! Map) {
      throw Exception(
          'Unexpected my_actions payload type: ${payload.runtimeType}');
    }

    final Map<String, dynamic> json = Map<String, dynamic>.from(payload);

    // Handle JSON-RPC error envelope from Odoo
    if (json.containsKey('error') && json['error'] is Map) {
      final err = Map<String, dynamic>.from(json['error'] as Map);
      // Odoo nests the real message inside error.data.message
      final errData = err['data'];
      String message;
      if (errData is Map) {
        message = errData['message']?.toString() ??
            errData['name']?.toString() ??
            err['message']?.toString() ??
            'Odoo Server Error';
      } else {
        message = err['message']?.toString() ?? 'Odoo Server Error';
      }
      throw Exception(message);
    }

    final result = json['result'];

    // result might be the list/data directly (no wrapping map)
    if (result is List) {
      return result
          .whereType<Map>()
          .map((e) => MyActionItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    if (result is! Map) {
      return const <MyActionItem>[];
    }

    final status = result['status']?.toString();
    if (status != null && status != 'success') {
      final message = result['message']?.toString() ?? 'Unknown error';
      throw Exception(message);
    }

    // Try the expected nested structure first: result.data.<key>
    final data = result['data'];
    if (data is Map) {
      final list = data[type.responseKey];
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => MyActionItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    }

    // Fallback: result.<key> directly (flat response)
    final directList = result[type.responseKey];
    if (directList is List) {
      return directList
          .whereType<Map>()
          .map((e) => MyActionItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    // Fallback: result.data is a list
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => MyActionItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    // Fallback: result.records (some Odoo endpoints)
    final records = result['records'];
    if (records is List) {
      return records
          .whereType<Map>()
          .map((e) => MyActionItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return const <MyActionItem>[];
  }

  Future<List<MyActionItem>> fetchMyRequests({String keyword = ''}) async {
    final login = SharedPref.getLoginDataOrNull();
    final token = login?.result?.token;
    if (token == null || token.isEmpty) {
      throw Exception('Invalid token');
    }

    final loginData = login?.result?.data;
    final loginEmployeeName = (loginData?.emp_name?.trim().isNotEmpty == true)
        ? loginData!.emp_name!.trim()
        : (loginData?.name?.trim().isNotEmpty == true)
            ? loginData!.name!.trim()
            : (loginData?.username ?? '').trim();
    final loginEmployeeImage = loginData?.image_url ?? '';
    final loginFileId = (loginData?.emp_profile_id?.trim().isNotEmpty == true)
        ? loginData!.emp_profile_id!.trim()
        : (loginData?.employee_id?.toString() ?? loginData?.emp_id ?? '');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final body = jsonEncode({
      'jsonrpc': '2.0',
      'params': {
        'keyword': keyword,
      },
    });

    final url = Uri.parse('${UrlUtil.baseUrl}my_requests');
    final request = http.Request('GET', url)
      ..headers.addAll(headers)
      ..body = body;

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('My requests HTTP ${response.statusCode}');
    }

    final dynamic payload =
        response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);

    if (payload is! Map) {
      throw Exception(
          'Unexpected my_requests payload type: ${payload.runtimeType}');
    }

    final json = Map<String, dynamic>.from(payload);
    final result = json['result'];

    List<dynamic> items = const [];
    if (result is Map && result['data'] is List) {
      items = List<dynamic>.from(result['data'] as List);
    } else if (result is List) {
      items = List<dynamic>.from(result);
    }

    return items.whereType<Map>().map((rawItem) {
      final map = Map<String, dynamic>.from(rawItem);
      map['employee_name'] =
          (map['employee_name']?.toString().trim().isNotEmpty == true)
              ? map['employee_name']
              : loginEmployeeName;
      map['employee_image'] =
          (map['employee_image']?.toString().trim().isNotEmpty == true)
              ? map['employee_image']
              : loginEmployeeImage;
      map['file_id'] = (map['file_id']?.toString().trim().isNotEmpty == true)
          ? map['file_id']
          : loginFileId;

      return MyActionItem.fromJson(map);
    }).toList(growable: false);
  }

  /// Fetches My Actions preview sheet payload (dedicated endpoint).
  /// Does NOT use Waiting detail APIs (get_*_details).
  Future<MyActionRecordPreview> fetchRecordPreview({
    required MyActionsType type,
    required int recordId,
  }) async {
    final token = SharedPref.getLoginDataOrNull()?.result?.token;
    if (token == null || token.isEmpty) {
      throw Exception('Invalid token');
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final url = Uri.parse('${UrlUtil.baseUrl}my_actions/preview');
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'params': {
        'type': type.apiValue,
        'record_id': recordId,
      },
    });
    final request = http.Request('GET', url)
      ..headers.addAll(headers)
      ..body = body;

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw Exception('Preview HTTP ${response.statusCode}');
    }

    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('Unexpected preview payload');
    }

    final json = Map<String, dynamic>.from(decoded);
    if (json['error'] is Map) {
      final err = Map<String, dynamic>.from(json['error'] as Map);
      final errData = err['data'];
      final message = errData is Map
          ? (errData['message']?.toString() ?? err['message']?.toString())
          : err['message']?.toString();
      throw Exception(message ?? 'Failed to load record preview');
    }

    final result = json['result'];
    Map<String, dynamic> data = {};
    if (result is Map) {
      final map = Map<String, dynamic>.from(result);
      final status = map['status']?.toString();
      final message = map['message']?.toString();
      final raw = map['data'];
      if (raw is Map) {
        data = Map<String, dynamic>.from(raw);
      } else if (map['form_view'] != null ||
          map['approvals'] != null ||
          map['request_info'] != null ||
          map['employee_info'] != null) {
        data = map;
      } else if (status != null && status != 'success' && status != 'ok') {
        throw Exception(message ?? 'Preview failed');
      }
    } else if (result == null) {
      throw Exception('Empty preview response');
    }

    return MyActionRecordPreview.fromDetailData(data, type: type);
  }
}
