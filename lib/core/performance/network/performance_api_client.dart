import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:el_race/core/hr_management/network/hr_api_envelope.dart';

/// Performance evaluation HTTP client — Odoo JSON-RPC.
class PerformanceApiClient {
  PerformanceApiClient(this._dio);

  final Dio _dio;

  Future<HrApiEnvelope<List<Map<String, dynamic>>>> fetchEvaluations({
    String? keyword,
    int? year,
    int page = 1,
    int limit = 30,
  }) async {
    return _postList('/api/performance/evaluations', {
      if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
      if (year != null) 'year': year,
      'page': page,
      'limit': limit,
    });
  }

  Future<HrApiEnvelope<Map<String, dynamic>>> fetchEvaluationDetail(
    String id,
  ) async {
    return _postMap('/api/performance/evaluations/detail', {'id': int.parse(id)});
  }

  Future<HrApiEnvelope<Map<String, dynamic>>> fetchMyEvaluation(int year) async {
    return _postMap('/api/performance/my_evaluation', {'year': year});
  }

  Future<HrApiEnvelope<Map<String, dynamic>>> fetchPlanning() async {
    return _postMap('/api/performance/planning', {});
  }

  Future<HrApiEnvelope<List<Map<String, dynamic>>>> fetchEmployees({
    int limit = 200,
  }) async {
    return _postList('/api/performance/employees', {'limit': limit});
  }

  Future<HrApiEnvelope<Map<String, dynamic>>> createEvaluation({
    required int employeeId,
    int? year,
  }) async {
    return _postMap('/api/performance/evaluations/create', {
      'employee_id': employeeId,
      if (year != null) 'year': year,
    });
  }

  Future<HrApiEnvelope<Map<String, dynamic>>> saveEvaluation({
    required String id,
    required List<Map<String, dynamic>> lines,
  }) async {
    return _postMap('/api/performance/evaluations/save', {
      'id': int.parse(id),
      'lines': lines,
    });
  }

  Future<HrApiEnvelope<Map<String, dynamic>>> _postMap(
    String path,
    Map<String, dynamic> params,
  ) async {
    final res = await _dio.post<dynamic>(
      path,
      data: jsonEncode({
        'jsonrpc': '2.0',
        'method': 'call',
        'params': params,
      }),
    );
    return _mapEnvelope(_decode(res.data));
  }

  Future<HrApiEnvelope<List<Map<String, dynamic>>>> _postList(
    String path,
    Map<String, dynamic> params,
  ) async {
    final res = await _dio.post<dynamic>(
      path,
      data: jsonEncode({
        'jsonrpc': '2.0',
        'method': 'call',
        'params': params,
      }),
    );
    return _listEnvelope(_decode(res.data));
  }

  dynamic _decode(dynamic data) =>
      data is String ? jsonDecode(data) as dynamic : data;

  HrApiEnvelope<List<Map<String, dynamic>>> _listEnvelope(dynamic payload) {
    if (payload is! Map) {
      return const HrApiEnvelope(success: false, error: 'Invalid server response');
    }
    final json = Map<String, dynamic>.from(payload);
    if (json['error'] is Map) {
      final err = Map<String, dynamic>.from(json['error'] as Map);
      return HrApiEnvelope(success: false, error: err['message']?.toString());
    }
    final result = json['result'];
    if (result is! Map) {
      return const HrApiEnvelope(success: false, error: 'Missing result');
    }
    final resultMap = Map<String, dynamic>.from(result);
    if (resultMap['success'] == true) {
      final data = resultMap['data'];
      final list = data is List
          ? data
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];
      return HrApiEnvelope(success: true, data: list);
    }
    return HrApiEnvelope(
      success: false,
      error: resultMap['error']?.toString() ?? 'Request failed',
    );
  }

  HrApiEnvelope<Map<String, dynamic>> _mapEnvelope(dynamic payload) {
    if (payload is! Map) {
      return const HrApiEnvelope(success: false, error: 'Invalid response');
    }
    final json = Map<String, dynamic>.from(payload);
    if (json['error'] is Map) {
      final err = Map<String, dynamic>.from(json['error'] as Map);
      return HrApiEnvelope(success: false, error: err['message']?.toString());
    }
    final result = json['result'];
    if (result is! Map) {
      return const HrApiEnvelope(success: false, error: 'Missing result');
    }
    final resultMap = Map<String, dynamic>.from(result);
    if (resultMap.containsKey('success')) {
      final data = resultMap['data'];
      return HrApiEnvelope(
        success: resultMap['success'] == true,
        data: data is Map ? Map<String, dynamic>.from(data) : null,
        error: resultMap['error']?.toString(),
      );
    }
    return HrApiEnvelope(
      success: false,
      error: resultMap['message']?.toString() ?? 'Request failed',
    );
  }
}
