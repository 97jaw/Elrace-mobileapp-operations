import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/Email%20Approval/models/ror_response.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class RorRepository {
  static const String _baseUrl = 'https://erp.elrace.com/api';

  Map<String, String> _buildHeaders(String token) => {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      };

  String _requireToken() {
    final token = SharedPref.getLoginData().result?.token;
    if (token == null || token.isEmpty) {
      throw Exception('User not authenticated');
    }
    return token;
  }

  /// ROR → /api/my_delayed_approvals/ror
  Future<RorResponse> fetchRor({int? month, int? year}) async {
    final token = _requireToken();
    final url = Uri.parse('$_baseUrl/my_delayed_approvals/ror');

    final params = <String, dynamic>{};
    if (month != null) params['month'] = month;
    if (year != null) params['year'] = year;

    final body = jsonEncode({"jsonrpc": "2.0", "params": params});

    try {
      http.Response response = await _sendRorRequest(
        method: 'GET',
        url: url,
        token: token,
        body: body,
      );

      if (response.statusCode == 405) {
        if (kDebugMode) {
          debugPrint('🟣 [ROR] GET returned 405, retrying with POST');
        }
        response = await _sendRorRequest(
          method: 'POST',
          url: url,
          token: token,
          body: body,
        );
      }

      if (kDebugMode) {
        debugPrint(
            'ROR status=${response.statusCode} bytes=${response.body.length}');
        debugPrint('🟣 [ROR] Raw response start');
        const chunkSize = 800;
        final raw = response.body;
        for (var i = 0; i < raw.length; i += chunkSize) {
          final end = (i + chunkSize < raw.length) ? i + chunkSize : raw.length;
          debugPrint(raw.substring(i, end));
        }
        debugPrint('🟣 [ROR] Raw response end');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final parsed = RorResponse.fromJson(data);
        final directRor = _extractDirectRorPercentage(data);
        final categoryRors = [
          parsed.hrRor,
          parsed.rfqRor,
          parsed.invoiceRor,
          parsed.pettyCashRor,
        ].whereType<int>().where((v) => v > 0).toList();

        var effectiveRor = (directRor ?? parsed.rorPercentage).clamp(0, 100);
        if (categoryRors.isNotEmpty) {
          final categoryAvg =
              (categoryRors.fold<int>(0, (sum, v) => sum + v) /
                      categoryRors.length)
                  .round();
          if (effectiveRor > 100 || (effectiveRor - categoryAvg).abs() > 35) {
            effectiveRor = categoryAvg;
          }
        }

        final normalized = RorResponse(
          hrCount: parsed.hrCount,
          rfqCount: parsed.rfqCount,
          invoiceCount: parsed.invoiceCount,
          pettyCashCount: parsed.pettyCashCount,
          rorPercentage: effectiveRor,
          hrRor: parsed.hrRor,
          rfqRor: parsed.rfqRor,
          invoiceRor: parsed.invoiceRor,
          pettyCashRor: parsed.pettyCashRor,
        );
        if (kDebugMode) {
          debugPrint(
            '🟣 [ROR] Parsed => ror=${normalized.rorPercentage}% (direct=${directRor ?? 'n/a'})'
            ' | hrRor=${normalized.hrRor}%, rfqRor=${normalized.rfqRor}%, invoiceRor=${normalized.invoiceRor}%, pettyCashRor=${normalized.pettyCashRor}%'
            ' | hrCount=${normalized.hrCount}, rfqCount=${normalized.rfqCount}, invoiceCount=${normalized.invoiceCount}, pettyCashCount=${normalized.pettyCashCount}',
          );
        }
        return normalized;
      } else {
        throw Exception('Failed to fetch ROR: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching ROR: $e');
    }
  }

  Future<http.Response> _sendRorRequest({
    required String method,
    required Uri url,
    required String token,
    required String body,
  }) async {
    final request = http.Request(method, url)
      ..headers.addAll(_buildHeaders(token))
      ..body = body;

    final response = await http.Response.fromStream(await request.send());

    if (kDebugMode) {
      debugPrint(
          '🟣 [ROR] method=$method status=${response.statusCode} bytes=${response.body.length}');
    }

    return response;
  }

  int? _extractDirectRorPercentage(dynamic decoded) {
    if (decoded is! Map) return null;
    final result = decoded['result'];
    if (result is! Map) return null;
    final data = result['data'];
    if (data is! Map) return null;

    final rorField = data['ror'] ??
        data['ror_percentage'] ??
        data['response_rate'] ??
        data['percentage'];

    if (rorField == null) return null;

    // New shape: data.ror is a map {overall, hr, rfq, invoice, petty_cash}
    if (rorField is Map) {
      final overall = rorField['overall'];
      return _decimalToPercent(overall);
    }

    return _decimalToPercent(rorField);
  }

  /// Converts a value to an integer percentage.
  /// Treats values <= 1.5 as decimals (0.26 → 26), otherwise as already-percent.
  int? _decimalToPercent(dynamic raw) {
    if (raw == null) return null;
    double? value;
    if (raw is num) {
      value = raw.toDouble();
    } else if (raw is String) {
      value = double.tryParse(raw.trim().replaceAll('%', ''));
    }
    if (value == null) return null;
    // If value looks like a decimal ratio (e.g. 0.26), multiply by 100
    if (value <= 1.5) value = value * 100;
    return value.round().clamp(0, 100);
  }
}
