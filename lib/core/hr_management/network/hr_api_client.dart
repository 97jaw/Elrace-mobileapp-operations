import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:el_race/core/hr_management/hr_mock_request_detail.dart';
import 'package:el_race/core/hr_management/hr_mock_requests.dart';
import 'package:el_race/core/hr_management/hr_mock_team_requests.dart';
import 'package:el_race/core/hr_management/network/hr_api_envelope.dart';

/// HR module HTTP client — Odoo JSON-RPC (`type=json` routes).
class HrApiClient {
  HrApiClient(
    this._dio, {
    this.useMock = false,
    this.baseUrl = 'https://erp.elrace.com',
  }) {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  final Dio _dio;
  final bool useMock;
  final String baseUrl;

  Dio get dio => _dio;

  Future<HrApiEnvelope<List<Map<String, dynamic>>>> fetchMyRequests({
    String? keyword,
    int limit = 200,
    int offset = 0,
  }) async {
    if (useMock) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      return HrApiEnvelope<List<Map<String, dynamic>>>(
        success: true,
        data: hrMockMyRequestsJson(),
        error: null,
        uiStatus: null,
      );
    }
    return _postList(
      '/api/hr/my_requests',
      {
        if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
        'limit': limit,
        'offset': offset,
      },
    );
  }

  Future<HrApiEnvelope<List<Map<String, dynamic>>>> fetchTeamRequests({
    String? keyword,
    int limit = 200,
    int offset = 0,
    String? department,
    String? status,
    String? type,
  }) async {
    if (useMock) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      return HrApiEnvelope<List<Map<String, dynamic>>>(
        success: true,
        data: hrMockTeamRequestsJson(),
        error: null,
        uiStatus: null,
      );
    }
    return _postList(
      '/api/hr/team_requests',
      {
        if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
        'limit': limit,
        'offset': offset,
        if (department != null && department.isNotEmpty) 'department': department,
        if (status != null && status.isNotEmpty) 'status': status,
        if (type != null && type.isNotEmpty) 'type': type,
      },
    );
  }

  /// All Odoo `request.type` rows for filter pickers.
  Future<HrApiEnvelope<List<Map<String, dynamic>>>> fetchRequestTypes() async {
    if (useMock) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return HrApiEnvelope<List<Map<String, dynamic>>>(
        success: true,
        data: const [
          {'id': 1, 'name': 'Leave Request', 'label': 'Leave Request', 'code': 'ANNUALLEAVE'},
          {'id': 2, 'name': 'Job Mission', 'label': 'Job Mission', 'code': 'JM'},
          {'id': 3, 'name': 'Temporary Permission', 'label': 'Temporary Permission', 'code': 'TEMP'},
        ],
        error: null,
        uiStatus: null,
      );
    }
    return _postList('/api/hr/request_types', {});
  }

  /// Fast KPI counts for Requests tab (`POST /api/hr/team_requests/kpis`).
  Future<HrApiEnvelope<Map<String, dynamic>>> fetchTeamKpis({
    String period = 'month',
  }) async {
    if (useMock) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return HrApiEnvelope<Map<String, dynamic>>(
        success: true,
        data: {'pending': 24, 'approved': 58, 'total': 120},
        error: null,
        uiStatus: null,
      );
    }
    try {
      return await _postMap('/api/hr/team_requests/kpis', {'period': period});
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return _kpisFallbackFromTeamList();
      }
      return HrApiEnvelope<Map<String, dynamic>>(
        success: false,
        error: _dioErrorMessage(e),
      );
    }
  }

  Future<HrApiEnvelope<Map<String, dynamic>>> _kpisFallbackFromTeamList() async {
    final team = await fetchTeamRequests(status: 'all', limit: 500);
    if (!team.success || team.data == null) {
      return HrApiEnvelope<Map<String, dynamic>>(
        success: false,
        error: team.error ?? 'Could not load KPIs',
      );
    }
    var pending = 0;
    var approved = 0;
    for (final row in team.data!) {
      final s = (row['ui_status']?.toString() ?? '').toUpperCase();
      if (s == 'PENDING') pending++;
      if (s == 'APPROVED') approved++;
    }
    return HrApiEnvelope<Map<String, dynamic>>(
      success: true,
      data: {
        'pending': pending,
        'approved': approved,
        'total': team.data!.length,
      },
    );
  }

  /// Legacy mock detail — HR Management uses [HrDetailsScreen] + `/api/get_hr_request_details`.
  Future<HrApiEnvelope<Map<String, dynamic>>> fetchRequestDetail(
    String id, {
    bool managerContext = false,
  }) async {
    if (useMock) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return HrApiEnvelope<Map<String, dynamic>>(
        success: true,
        data: hrMockRequestDetailJson(id, managerContext: managerContext),
        error: null,
        uiStatus: null,
      );
    }
    throw UnsupportedError(
      'Use HrDetailsScreen with /api/get_hr_request_details for live detail.',
    );
  }

  Future<HrApiEnvelope<List<Map<String, dynamic>>>> searchTeamRequests({
    String query = '',
    String? department,
    String? requestType,
    String? status,
    int offset = 0,
    int limit = 20,
  }) async {
    if (useMock) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      var list = hrMockTeamArchiveJson();
      final q = query.trim().toLowerCase();
      if (q.isNotEmpty) {
        list = list.where((e) {
          final ref = e['reference']?.toString().toLowerCase() ?? '';
          final typ = e['type']?.toString().toLowerCase() ?? '';
          final name = e['employee_name']?.toString().toLowerCase() ?? '';
          return ref.contains(q) || typ.contains(q) || name.contains(q);
        }).toList();
      }
      if (department != null && department.isNotEmpty) {
        list = list
            .where((e) =>
                e['department']?.toString().toLowerCase() ==
                department.toLowerCase())
            .toList();
      }
      if (requestType != null && requestType.isNotEmpty) {
        list = list
            .where((e) => e['type']?.toString() == requestType)
            .toList();
      }
      if (status != null && status.isNotEmpty && status != 'all') {
        list = list
            .where((e) =>
                e['ui_status']?.toString().toUpperCase() ==
                status.toUpperCase())
            .toList();
      }
      final slice = list.skip(offset).take(limit).toList();
      return HrApiEnvelope<List<Map<String, dynamic>>>(
        success: true,
        data: slice,
        error: null,
        uiStatus: null,
      );
    }
    try {
      return await _postList(
        '/api/hr/team_requests/search',
        {
          'q': query,
          if (department != null) 'department': department,
          if (requestType != null) 'type': requestType,
          if (status != null) 'status': status,
          'offset': offset,
          'limit': limit,
        },
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return _searchFallbackFromTeamQueue(
          query: query,
          department: department,
          requestType: requestType,
          status: status,
          offset: offset,
          limit: limit,
        );
      }
      return HrApiEnvelope<List<Map<String, dynamic>>>(
        success: false,
        error: _dioErrorMessage(e),
      );
    }
  }

  /// When search route is not deployed yet — uses team queue + client filters.
  Future<HrApiEnvelope<List<Map<String, dynamic>>>> _searchFallbackFromTeamQueue({
    required String query,
    String? department,
    String? requestType,
    String? status,
    required int offset,
    required int limit,
  }) async {
    final team = await fetchTeamRequests(
      keyword: query,
      limit: 500,
      offset: 0,
      department: department,
      type: requestType,
      status: status != null && status.isNotEmpty && status.toLowerCase() != 'all'
          ? status
          : null,
    );
    if (!team.success) {
      return HrApiEnvelope<List<Map<String, dynamic>>>(
        success: false,
        error: team.error ?? 'Could not load team requests',
      );
    }
    var list = List<Map<String, dynamic>>.from(team.data ?? []);
    if (status != null &&
        status.isNotEmpty &&
        status.toLowerCase() != 'all') {
      final want = status.toUpperCase();
      list = list
          .where((e) => (e['ui_status']?.toString().toUpperCase() ?? '') == want)
          .toList();
    }
    final slice = list.skip(offset).take(limit).toList();
    return HrApiEnvelope<List<Map<String, dynamic>>>(
      success: true,
      data: slice,
    );
  }

  String _dioErrorMessage(DioException e) {
    final code = e.response?.statusCode;
    if (code == 404) {
      return 'Service not found. Please update the server or try again later.';
    }
    if (code != null) {
      return 'Request failed (HTTP $code).';
    }
    return e.message ?? 'Network error';
  }

  Future<HrApiEnvelope<Map<String, dynamic>>> submitAssetRequest({
    required String kind,
    required Map<String, dynamic> payload,
  }) async {
    if (useMock) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return HrApiEnvelope<Map<String, dynamic>>(
        success: true,
        data: {
          'reference':
              'HR/${kind.toUpperCase()}/2026/${1000 + payload.hashCode % 9000}',
        },
        error: null,
        uiStatus: 'PENDING',
      );
    }
    final envelope = await _postMap(
      '/api/hr/asset_request',
      {'kind': kind, ...payload},
    );
    return HrApiEnvelope<Map<String, dynamic>>(
      success: envelope.success,
      data: envelope.data,
      error: envelope.error,
      uiStatus: envelope.uiStatus,
    );
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
    return _listEnvelopeFromOdoo(_decodePayload(res.data));
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
    final payload = _decodePayload(res.data);
    return _envelopeFromOdoo(payload);
  }

  dynamic _decodePayload(dynamic data) {
    if (data is String) {
      return jsonDecode(data);
    }
    return data;
  }

  HrApiEnvelope<Map<String, dynamic>> _envelopeFromOdoo(dynamic payload) {
    if (payload is! Map) {
      return const HrApiEnvelope<Map<String, dynamic>>(
        success: false,
        error: 'Invalid server response',
      );
    }
    final json = Map<String, dynamic>.from(payload);

    if (json['error'] is Map) {
      final err = Map<String, dynamic>.from(json['error'] as Map);
      final errData = err['data'];
      String message;
      if (errData is Map) {
        message = errData['message']?.toString() ??
            err['message']?.toString() ??
            'Odoo server error';
      } else {
        message = err['message']?.toString() ?? 'Odoo server error';
      }
      return HrApiEnvelope<Map<String, dynamic>>(
        success: false,
        error: message,
      );
    }

    final result = json['result'];
    if (result is! Map) {
      return const HrApiEnvelope<Map<String, dynamic>>(
        success: false,
        error: 'Missing result in response',
      );
    }

    final resultMap = Map<String, dynamic>.from(result);

    // HR list routes: { success, data: [...], error, ui_status }
    if (resultMap.containsKey('success')) {
      final data = resultMap['data'];
      return HrApiEnvelope<Map<String, dynamic>>(
        success: resultMap['success'] == true,
        data: data is Map ? Map<String, dynamic>.from(data) : null,
        error: resultMap['error']?.toString(),
        uiStatus: resultMap['ui_status']?.toString(),
      );
    }

    // Legacy { status, data, message }
    if (resultMap['status'] == 'success') {
      final data = resultMap['data'];
      return HrApiEnvelope<Map<String, dynamic>>(
        success: true,
        data: data is Map ? Map<String, dynamic>.from(data) : null,
        error: null,
        uiStatus: null,
      );
    }

    return HrApiEnvelope<Map<String, dynamic>>(
      success: false,
      error: resultMap['message']?.toString() ?? 'Request failed',
    );
  }

  HrApiEnvelope<List<Map<String, dynamic>>> _listEnvelopeFromOdoo(dynamic payload) {
    if (payload is! Map) {
      return const HrApiEnvelope<List<Map<String, dynamic>>>(
        success: false,
        error: 'Invalid server response',
      );
    }
    final json = Map<String, dynamic>.from(payload);

    if (json['error'] is Map) {
      final err = Map<String, dynamic>.from(json['error'] as Map);
      final errData = err['data'];
      final message = errData is Map
          ? errData['message']?.toString() ??
              err['message']?.toString() ??
              'Odoo server error'
          : err['message']?.toString() ?? 'Odoo server error';
      return HrApiEnvelope<List<Map<String, dynamic>>>(
        success: false,
        error: message,
      );
    }

    final result = json['result'];
    if (result is! Map) {
      return const HrApiEnvelope<List<Map<String, dynamic>>>(
        success: false,
        error: 'Missing result in response',
      );
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
      return HrApiEnvelope<List<Map<String, dynamic>>>(
        success: true,
        data: list,
        error: null,
        uiStatus: resultMap['ui_status']?.toString(),
      );
    }

    return HrApiEnvelope<List<Map<String, dynamic>>>(
      success: false,
      error: resultMap['error']?.toString() ??
          resultMap['message']?.toString() ??
          'Request failed',
    );
  }
}
