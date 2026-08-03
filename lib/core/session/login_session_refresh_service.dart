import 'dart:convert';

import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/session/force_logout_guard.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/services/api_client.dart';
import 'package:el_race/utils/di.dart';
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
      // Migrated off a one-off Dio() with a hardcoded 'https://erp.elrace.com'
      // base URL and manual Authorization header onto the shared ApiClient
      // (base URL from UaepassConfig.baseApiUrl, same backend as
      // UrlUtil.baseUrl). AuthInterceptor attaches the bearer token from the
      // same SharedPref source read above; the 401 handler and retry
      // interceptor now also cover this call for free. Per
      // FIX_IMPLEMENTATION_PLAN.md Phase 4.3(1) — this was the highest-value
      // migration target, directly tied to the "logout stuck /
      // permission-denied" baseline bug.
      final res = await sl<ApiClient>().post(
        'session/refresh',
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
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

      if (result['success'] != true) {
        final code = (result['code'] ?? '').toString().trim().toUpperCase();
        if (code == 'FORCE_LOGOUT' || code == 'SESSION_EXPIRED') {
          // ignore: unawaited_futures
          ForceLogoutGuard.instance.presentForcedLogoutFlow();
        }
        return false;
      }
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
