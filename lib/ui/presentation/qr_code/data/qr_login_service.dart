import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/utils/urll_utils.dart';
import 'package:flutter/foundation.dart';

/// Hub QR login via authenticated Odoo relay.
///
/// Mobile sends only the scanned challenge. Odoo derives `odoo_id` from the
/// JWT session and signs the Hub request server-side.
class QrLoginService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  /// Public so the scanner can cooldown on the real challenge, not raw pixels.
  String extractCodeFromQr(String qrRaw) => _extractCodeFromQr(qrRaw);

  String _extractCodeFromQr(String qrRaw) {
    var raw = qrRaw.trim();
    if (raw.isEmpty) return '';

    // JSON payload: {"code":"..."} and common variants.
    try {
      final qrJson = jsonDecode(raw);
      if (qrJson is Map) {
        for (final key in ['code', 'qr_code', 'login_code', 'challenge']) {
          final parsed = qrJson[key]?.toString().trim();
          if (parsed != null && parsed.isNotEmpty) {
            return parsed;
          }
        }
        // Prefer explicit token only when no code-like key exists.
        final token = qrJson['token']?.toString().trim();
        if (token != null && token.isNotEmpty) {
          return token;
        }
      }
    } catch (_) {
      // Not JSON.
    }

    final uri = Uri.tryParse(raw);
    if (uri != null && uri.hasScheme && (uri.scheme == 'http' ||
        uri.scheme == 'https' ||
        uri.scheme == 'elrace' ||
        uri.scheme.startsWith('odoo'))) {
      for (final key in ['code', 'qr', 'token', 'login_code', 'challenge']) {
        final q = uri.queryParameters[key]?.trim();
        if (q != null && q.isNotEmpty) {
          return q;
        }
      }
      if (uri.pathSegments.isNotEmpty) {
        final last = uri.pathSegments.last.trim();
        if (last.isNotEmpty &&
            !last.contains('.') &&
            last.toLowerCase() != 'login' &&
            last.toLowerCase() != 'signin' &&
            last.toLowerCase() != 'auth') {
          return last;
        }
      }
    }

    // Plain challenge string from Hub QR.
    return raw;
  }

  String _friendlyMessage(String? raw) {
    final message = (raw ?? '').trim();
    if (message.isEmpty) return 'Sign-in failed. Please try again.';
    final lower = message.toLowerCase();
    if (lower.contains('too many')) {
      return 'Too many attempts. Wait about a minute, refresh the Hub QR, then scan once.';
    }
    if (lower.contains('not found') ||
        lower.contains('could not found') ||
        lower.contains('expired') ||
        lower.contains('invalid')) {
      return 'This QR is invalid or expired. Refresh the Hub QR, then scan once.';
    }
    return message;
  }

  /// Approve Hub web login using the scanned QR challenge.
  Future<Map<String, dynamic>> loginWithQrCode(String qrCode) async {
    try {
      final token = SharedPref.getLoginDataOrNull()?.result?.token?.trim() ?? '';
      if (token.isEmpty) {
        return {
          'success': false,
          'message': 'User session not found. Please login again.',
        };
      }

      final actualCode = _extractCodeFromQr(qrCode);
      if (actualCode.isEmpty) {
        return {
          'success': false,
          'message': 'Invalid QR code.',
        };
      }

      if (kDebugMode) {
        debugPrint(
          'QR login: challenge_len=${actualCode.length} '
          'prefix=${actualCode.substring(0, actualCode.length.clamp(0, 8))}…',
        );
      }

      final url = '${UrlUtil.baseUrl}${UrlUtil.hubQrLoginApi}';
      final response = await _dio.post(
        url,
        data: {
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {'code': actualCode},
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          validateStatus: (status) => true,
        ),
      );

      final payload = response.data;
      if (kDebugMode) {
        debugPrint('QR login HTTP ${response.statusCode}: $payload');
      }

      if (payload is Map && payload['error'] != null) {
        final err = payload['error'];
        final message = err is Map
            ? (err['data'] is Map
                ? (err['data']['message']?.toString() ??
                    err['message']?.toString())
                : err['message']?.toString())
            : err.toString();
        return {
          'success': false,
          'message': _friendlyMessage(message),
          'data': payload,
        };
      }

      final result = payload is Map ? (payload['result'] ?? payload) : null;
      if (result is Map) {
        final status = '${result['status'] ?? ''}'.toLowerCase();
        final ok = result['success'] == true ||
            status == 'success' ||
            status == 'ok' ||
            status == 'true';
        if (ok) {
          return {
            'success': true,
            'message': result['message']?.toString() ?? 'Login successful',
            'data': result['data'] ?? result,
            'code': actualCode,
          };
        }
        return {
          'success': false,
          'message': _friendlyMessage(result['message']?.toString()),
          'data': result['data'] ?? result,
          'code': actualCode,
        };
      }

      return {
        'success': false,
        'message': 'Sign-in failed. Please try again.',
        'data': payload,
        'code': actualCode,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error. Check network and try again.',
      };
    }
  }
}
