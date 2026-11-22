import 'dart:convert';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../utils/di.dart';
import '../../signin/data/repository.dart';

final userRepo = sl.get<UserRepo>();

class AttendanceRepo {
  Future<http.Response> getAttendanceList({
    String? keyword,
    int? month,
    int? year,
    int limit = 500,
    int offset = 0,
  }) async {
    try {
      final loginResponse = await userRepo.getLoginResponse();
      final token = loginResponse?.result?.token;
      if (token == null || token.isEmpty) {
        throw Exception('Invalid token');
      }

      Map<String, String> headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token"
      };

      var url = Uri.parse("https://erp.elrace.com/api/attendance/list");
      final body = jsonEncode({
        "jsonrpc": "2.0",
        "params": {
          "keyword": keyword,
          "limit": limit,
          "offset": offset,
          "month": month,
          if (year != null) "year": year,
        }
      });

      debugPrint('\n========== [ATTENDANCE_LIST] API REQUEST ==========');
      debugPrint('🌐 URL: $url');
      debugPrint('📤 Body:');
      try { debugPrint(const JsonEncoder.withIndent('  ').convert(jsonDecode(body))); } catch (_) { debugPrint(body); }
      debugPrint('====================================================\n');

      final request = http.Request('POST', url)
        ..headers.addAll(headers)
        ..body = body;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('========== [ATTENDANCE_LIST] API RESPONSE ==========');
      debugPrint('📊 Status Code: ${response.statusCode}');
      debugPrint('📦 Full Response Body:');
      try { debugPrint(const JsonEncoder.withIndent('  ').convert(jsonDecode(response.body))); } catch (_) { debugPrint(response.body); }
      debugPrint('====================================================\n');

      return response;
    } catch (e) {
      log('Error in getAttendanceList: $e');
      rethrow;
    }
  }

  Future<http.Response> getAttendanceDetail({
    required int empId,
    required int month,
    required int year,
  }) async {
    try {
      final loginResponse = await userRepo.getLoginResponse();
      final token = loginResponse?.result?.token;
      if (token == null || token.isEmpty) {
        throw Exception('Invalid token');
      }

      Map<String, String> headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token"
      };

      final url = Uri.parse("https://erp.elrace.com/api/attendance/detail");
      final body = jsonEncode({
        "jsonrpc": "2.0",
        "params": {
          "employee_id": empId,
          "month": month,
          "year": year,
        }
      });

      debugPrint('\n========== [ATTENDANCE_DETAIL] API REQUEST ==========');
      debugPrint('🌐 URL: $url');
      debugPrint('📤 Body:');
      try { debugPrint(const JsonEncoder.withIndent('  ').convert(jsonDecode(body))); } catch (_) { debugPrint(body); }
      debugPrint('======================================================\n');

      final request = http.Request('POST', url)
        ..headers.addAll(headers)
        ..body = body;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('========== [ATTENDANCE_DETAIL] API RESPONSE ==========');
      debugPrint('📊 Status Code: ${response.statusCode}');
      debugPrint('📦 Full Response Body:');
      try { debugPrint(const JsonEncoder.withIndent('  ').convert(jsonDecode(response.body))); } catch (_) { debugPrint(response.body); }
      debugPrint('======================================================\n');

      return response;
    } catch (e) {
      log('Error in getAttendanceDetail: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getAttendanceSummary({
    required String startDate,
    required String endDate,
  }) async {
    try {
      final loginResponse = await userRepo.getLoginResponse();
      final token = loginResponse?.result?.token;
      if (token == null || token.isEmpty) {
        throw Exception('Invalid token');
      }

      final headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token"
      };

      final body = jsonEncode({
        "jsonrpc": "2.0",
        "params": {
          "start_date": startDate,
          "end_date": endDate,
        }
      });

      final response = await http.post(
        Uri.parse("https://erp.elrace.com/attendance/summary"),
        headers: headers,
        body: body,
      );

      debugPrint('\n========== [ATTENDANCE_SUMMARY] API REQUEST ==========');
      debugPrint('🌐 URL: https://erp.elrace.com/attendance/summary');
      debugPrint('📤 Body:');
      try { debugPrint(const JsonEncoder.withIndent('  ').convert(jsonDecode(body))); } catch (_) { debugPrint(body); }
      debugPrint('======================================================');
      debugPrint('📊 Status Code: ${response.statusCode}');
      debugPrint('📦 Full Response Body:');
      try { debugPrint(const JsonEncoder.withIndent('  ').convert(jsonDecode(response.body))); } catch (_) { debugPrint(response.body); }
      debugPrint('=======================================================\n');

      final decoded = jsonDecode(response.body);
      // Handle error structure {result: {status: 'error', message: 'Invalid token'}}
      final result = decoded is Map<String, dynamic> ? decoded['result'] : null;
      if (result is Map<String, dynamic>) {
        final status = result['status'];
        if (status == 'error') {
          final message = result['message']?.toString() ?? 'Unknown error';
          throw Exception(message);
        }
        final data = result['data'];
        return data;
      }
      throw Exception('Malformed response');
    } catch (e) {
      log("Error in getAttendanceSummary: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getTodayStatus() async {
    try {
      final loginResponse = await userRepo.getLoginResponse();
      final token = loginResponse?.result?.token;
      if (token == null || token.isEmpty) {
        throw Exception('Invalid token');
      }

      final headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token"
      };

      final body = jsonEncode({
        "jsonrpc": "2.0",
        "params": {},
      });

      final response = await http.post(
        Uri.parse("https://erp.elrace.com/api/attendance/today_status"),
        headers: headers,
        body: body,
      );

      debugPrint('\n========== [ATTENDANCE_TODAY_STATUS] API REQUEST ==========');
      debugPrint('🌐 URL: https://erp.elrace.com/api/attendance/today_status');
      debugPrint('📤 Body:');
      try { debugPrint(const JsonEncoder.withIndent('  ').convert(jsonDecode(body))); } catch (_) { debugPrint(body); }
      debugPrint('==========================================================');
      debugPrint('📊 Status Code: ${response.statusCode}');
      debugPrint('📦 Full Response Body:');
      try { debugPrint(const JsonEncoder.withIndent('  ').convert(jsonDecode(response.body))); } catch (_) { debugPrint(response.body); }
      debugPrint('===========================================================\n');

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to fetch today status: HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Malformed response');
      }

      final result = decoded['result'];
      if (result is! Map<String, dynamic>) {
        throw Exception('Malformed response result');
      }

      final status = result['status']?.toString();
      if (status == 'error') {
        final message = result['message']?.toString() ?? 'Unknown error';
        throw Exception(message);
      }

      final rawData = (result['data'] is Map<String, dynamic>)
          ? result['data'] as Map<String, dynamic>
          : result;

      return {
        'checked_in': _toBool(rawData['checked_in']),
        'checked_out': _toBool(rawData['checked_out']),
        'check_in_time': rawData['check_in_time']?.toString(),
        'check_out_time': rawData['check_out_time']?.toString(),
        'is_today': _toBool(rawData['is_today']),
        'check_in_record_id': rawData['attendance_id'] ?? rawData['check_in_record_id'],
      };
    } catch (e) {
      log("Error in getTodayStatus: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getDashboardStats({
    required String dateFrom,
    required String dateTo,
  }) async {
    try {
      final loginResponse = await userRepo.getLoginResponse();
      final token = loginResponse?.result?.token;
      if (token == null || token.isEmpty) throw Exception('Invalid token');

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final body = jsonEncode({
        'jsonrpc': '2.0',
        'params': {'date_from': dateFrom, 'date_to': dateTo},
      });

      final response = await http.post(
        Uri.parse('https://erp.elrace.com/api/attendance/dashboard_stats'),
        headers: headers,
        body: body,
      );

      debugPrint('[ATTENDANCE_DASHBOARD_STATS] ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      final result = decoded is Map ? decoded['result'] : null;
      if (result is Map && result['status'] == 'success') {
        return Map<String, dynamic>.from(result['data'] as Map);
      }
      throw Exception(
          result is Map ? (result['message'] ?? 'Unknown error') : 'Malformed response');
    } catch (e) {
      log('Error in getDashboardStats: $e');
      rethrow;
    }
  }

  /// Paginated flat attendance records for the Records tab.
  /// Calls POST /api/attendance/records.
  Future<Map<String, dynamic>> getAttendanceRecords({
    required String dateFrom,
    required String dateTo,
    String? keyword,
    String? attendanceType,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final loginResponse = await userRepo.getLoginResponse();
      final token = loginResponse?.result?.token;
      if (token == null || token.isEmpty) throw Exception('Invalid token');

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final body = jsonEncode({
        'jsonrpc': '2.0',
        'params': {
          'date_from': dateFrom,
          'date_to': dateTo,
          if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
          if (attendanceType != null && attendanceType != 'all')
            'attendance_type': attendanceType,
          'limit': limit,
          'offset': offset,
        },
      });

      final response = await http.post(
        Uri.parse('https://erp.elrace.com/api/attendance/records'),
        headers: headers,
        body: body,
      );

      debugPrint('[ATTENDANCE_RECORDS] ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      final result = decoded is Map ? decoded['result'] : null;
      if (result is Map && result['status'] == 'success') {
        final data = Map<String, dynamic>.from(result['data'] as Map);
        // Deduplicate backend bug: same employee may have multiple hr.attendance
        // records for the same calendar day. Keep the one with the most worked
        // hours so stats and record counts are consistent.
        final rawRecords = data['records'];
        if (rawRecords is List && rawRecords.length > 1) {
          final deduped = <String, Map<String, dynamic>>{};
          for (final rec in rawRecords) {
            if (rec is! Map) continue;
            final empId = rec['employee_id']?.toString() ?? '0';
            final checkDate = (rec['check_date'] ?? rec['check_in'] ?? '')
                .toString()
                .split('T')
                .first
                .split(' ')
                .first;
            final key = '${empId}_$checkDate';
            final workedHours =
                (rec['worked_hours'] as num?)?.toDouble() ?? 0.0;
            final existing = deduped[key];
            if (existing == null ||
                ((existing['worked_hours'] as num?)?.toDouble() ?? 0.0) <
                    workedHours) {
              deduped[key] = Map<String, dynamic>.from(rec);
            }
          }
          data['records'] = deduped.values.toList();
          data['total'] = deduped.length;
        }
        return data;
      }
      throw Exception(
        result is Map ? (result['message'] ?? 'Unknown error') : 'Malformed response',
      );
    } catch (e) {
      log('Error in getAttendanceRecords: $e');
      rethrow;
    }
  }

  bool _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value == null) {
      return false;
    }

    final normalized = value.toString().trim().toLowerCase();
    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'y';
  }
}
