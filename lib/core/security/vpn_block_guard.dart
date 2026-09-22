import 'dart:async';
import 'dart:convert';

import 'package:el_race/core/app_globals.dart';
import 'package:el_race/core/security/device_security_service.dart';
import 'package:el_race/core/services/app_config_service.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/services/api_client.dart';
import 'package:el_race/utils/di.dart';
import 'package:flutter/foundation.dart';

/// VPN block popup — local probe + optional backend IP hint (session/refresh).
/// Retry / Close App only; does not sign the user out.
class VpnBlockGuard {
  VpnBlockGuard._();

  static final VpnBlockGuard instance = VpnBlockGuard._();

  bool _inFlight = false;
  DateTime? _lastCheckAt;
  DateTime? _lastBackendCheckAt;

  static const _minCheckInterval = Duration(seconds: 3);
  static const _minBackendInterval = Duration(seconds: 20);

  Future<void> checkOnForeground({bool force = false}) async {
    if (AppConfigService.instance.shouldSkipVpnCheck) return;
    if (DeviceSecurityService.isSecurityDialogVisible) return;
    if (_inFlight) return;

    final last = _lastCheckAt;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < _minCheckInterval) {
      return;
    }
    _lastCheckAt = DateTime.now();
    _inFlight = true;

    try {
      final localActive =
          await DeviceSecurityService.instance.isVpnBlockingActive();
      if (localActive) {
        await _showVpnDialog();
        return;
      }

      final backendSuspected = await _backendVpnSuspected();
      if (backendSuspected) {
        await _showVpnDialog();
      }
    } catch (e) {
      debugPrint('[VpnBlockGuard] check failed: $e');
    } finally {
      _inFlight = false;
    }
  }

  Future<bool> _backendVpnSuspected() async {
    if (!SharedPref.isUserAuthenticated()) return false;

    final last = _lastBackendCheckAt;
    if (last != null &&
        DateTime.now().difference(last) < _minBackendInterval) {
      return false;
    }
    _lastBackendCheckAt = DateTime.now();

    final token = SharedPref.getLoginDataOrNull()?.result?.token;
    if (token == null || token.isEmpty) return false;

    try {
      final res = await sl<ApiClient>()
          .post(
            'session/refresh',
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            data: jsonEncode({
              'jsonrpc': '2.0',
              'method': 'call',
              'params': {
                'client_vpn_active': false,
              },
            }),
          )
          .timeout(const Duration(seconds: 8));

      final payload = res.data;
      if (payload is! Map) return false;
      final result = payload['result'];
      if (result is! Map) return false;
      if (result['success'] != true) return false;

      final data = result['data'];
      if (data is Map && data['vpn_suspected'] == true) return true;
      return result['vpn_suspected'] == true;
    } catch (e) {
      debugPrint('[VpnBlockGuard] backend VPN check failed: $e');
      return false;
    }
  }

  Future<void> _showVpnDialog() async {
    if (DeviceSecurityService.isSecurityDialogVisible) return;
    final ctx = navKey.currentContext;
    if (ctx == null || !ctx.mounted) return;

    await DeviceSecurityService.showSecurityBlockDialog(
      ctx,
      SecurityCheckResult.vpnOnly(),
    );
  }
}
