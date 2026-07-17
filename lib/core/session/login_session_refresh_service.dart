import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Refreshes role flags from the server using the current bearer token.
class LoginSessionRefreshService {
  LoginSessionRefreshService._();

  /// Pull-to-refresh / app resume: merge latest roles into cached login, then
  /// bump Riverpod so HR/recruitment views re-evaluate [hrEffectiveViewProvider].
  static Future<bool> refreshRoles({ProviderContainer? container}) async {
    final token = SharedPref.getLoginDataOrNull()?.result?.token;
    if (token == null || token.isEmpty) return false;

    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: 'https://erp.elrace.com',
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      final res = await dio.post<dynamic>(
        '/api/session/refresh',
        data: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'call',
          'params': <String, dynamic>{},
        }),
      );

      final payload = res.data;
      if (payload is! Map) return false;

      final result = payload['result'];
      if (result is! Map) return false;

      if (result['success'] != true) return false;
      final data = result['data'];
      if (data is! Map) return false;

      final merged = await SharedPref.mergeLoginRoleFields(
        Map<String, dynamic>.from(data),
      );
      if (!merged) return false;

      final c = container;
      if (c != null) {
        bumpLoginSessionRiverpod(c);
      }
      return true;
    } catch (e, st) {
      debugPrint('LoginSessionRefreshService.refreshRoles failed: $e\n$st');
      return false;
    }
  }
}
