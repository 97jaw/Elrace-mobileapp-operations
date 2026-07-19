import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_api_catalog.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/services/api_client.dart' show AuthErrorInterceptor, RetryInterceptor;
import 'package:flutter/foundation.dart';

/// Low-level JSON-RPC calls to existing Odoo timesheet controllers.
///
/// This backs Phase 3's project/timesheet tab providers (the ones that will
/// get CancelToken-based cancellation), so per FIX_IMPLEMENTATION_PLAN.md
/// Phase 4.3(3) it gets the shared 401/retry interceptors first. Left
/// alone: the manual _headers()/withAuth Authorization-header construction
/// below — no caller in this codebase actually passes withAuth: false, so
/// it's dead-in-practice, and AuthInterceptor would just no-op here anyway
/// since the header is already present by the time a request goes out.
/// Not worth the churn of touching call sites for a header that's already
/// being set correctly.
class TimesheetOdooTransport {
  TimesheetOdooTransport({
    required Dio dio,
    this.baseUrl = 'https://erp.elrace.com/api',
  }) : _dio = dio {
    _dio.interceptors.addAll([
      AuthErrorInterceptor(),
      RetryInterceptor(_dio),
    ]);
  }

  final Dio _dio;
  final String baseUrl;

  Dio get dio => _dio;

  String? get authToken => SharedPref.getLoginData().result?.token;

  int? get odooUserId {
    final data = SharedPref.getLoginData().result?.data;
    return data?.odoo_user_id ??
        data?.uid ??
        data?.employee_id;
  }

  bool get hasSession => authToken != null && authToken!.isNotEmpty;

  Map<String, String> _headers({bool withAuth = true}) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (withAuth && authToken != null && authToken!.isNotEmpty)
        'Authorization': 'Bearer $authToken',
    };
  }

  Future<Map<String, dynamic>> postJsonRpc(
    String path, {
    required Map<String, dynamic> params,
    bool withAuth = true,
  }) async {
    final response = await _dio.post<dynamic>(
      '$baseUrl$path',
      data: {'jsonrpc': '2.0', 'params': params},
      options: Options(headers: _headers(withAuth: withAuth)),
    );
    return _normalizeBody(response.data);
  }

  Future<Map<String, dynamic>> getJsonRpc(
    String path, {
    Map<String, dynamic> params = const {},
    bool withAuth = true,
  }) async {
    final response = await _dio.get<dynamic>(
      '$baseUrl$path',
      data: {'jsonrpc': '2.0', 'params': params},
      options: Options(headers: _headers(withAuth: withAuth)),
    );
    return _normalizeBody(response.data);
  }

  Map<String, dynamic> _normalizeBody(dynamic body) {
    if (body is Map<String, dynamic>) return body;
    if (body is Map) return Map<String, dynamic>.from(body);
    if (body is String && body.isNotEmpty) {
      return jsonDecode(body) as Map<String, dynamic>;
    }
    return jsonDecode(jsonEncode(body)) as Map<String, dynamic>;
  }

  /// Reads `result` from Odoo jsonrpc body; throws on HTTP/parse errors.
  Object? parseResult(Map<String, dynamic> body, {String? debugLabel}) {
    if (body.containsKey('error') && body['error'] != null) {
      final message = body['error']?.toString() ?? 'Odoo error';
      debugPrint(
        'TimesheetOdooTransport${debugLabel != null ? ' ($debugLabel)' : ''}: $message',
      );
      throw TimesheetOdooException(message);
    }
    return body['result'];
  }

  Future<List<TimesheetOdooEmployee>> fetchEmployees() async {
    final attempts = <Future<Map<String, dynamic>>>[
      postJsonRpc(TimesheetOdooApiCatalog.employeeListX, params: const {}),
      getJsonRpc(TimesheetOdooApiCatalog.employeeListX, params: const {}),
      postJsonRpc(TimesheetOdooApiCatalog.employeeList, params: const {}),
    ];
    Object? lastError;
    for (final attempt in attempts) {
      try {
        final body = await attempt;
        final result = parseResult(body, debugLabel: 'employee/list');
        final rows = parseMapList(result, key: 'employees');
        return rows.map(TimesheetOdooEmployee.fromJson).toList();
      } catch (error) {
        lastError = error;
      }
    }
    throw TimesheetOdooException(lastError?.toString() ?? 'employee list failed');
  }

  Future<List<Map<String, dynamic>>> fetchTimesheetCountsByDays({
    required Object taskId,
    required List<String> dateList,
  }) async {
    final parsed = int.tryParse(taskId.toString());
    if (parsed == null) return const [];
    final body = await postJsonRpc(
      TimesheetOdooApiCatalog.countTimesheetsByDays,
      params: {
        'task_id': parsed,
        'date_list': dateList,
      },
    );
    final result = parseResult(body, debugLabel: 'count/timesheets/by/days');
    return parseMapList(result, key: 'timesheets');
  }

  List<Map<String, dynamic>> parseMapList(Object? raw, {String key = ''}) {
    if (raw == null) return const [];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      if (key.isNotEmpty && map[key] is List) {
        return parseMapList(map[key]);
      }
      for (final entry in map.entries) {
        if (entry.value is List) {
          return parseMapList(entry.value);
        }
      }
    }
    return const [];
  }
}

class TimesheetOdooException implements Exception {
  TimesheetOdooException(this.message);
  final String message;

  @override
  String toString() => message;
}
