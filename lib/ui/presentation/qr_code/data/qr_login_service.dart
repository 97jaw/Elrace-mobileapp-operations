import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/services/api_client.dart';
import 'package:el_race/utils/urll_utils.dart';

abstract interface class QrApprovalTransport {
  Future<Response<dynamic>> approve(
    String challenge, {
    CancelToken? cancelToken,
  });
}

class OdooQrApprovalTransport implements QrApprovalTransport {
  OdooQrApprovalTransport({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(baseUrl: UrlUtil.baseUrl);

  final ApiClient _apiClient;

  @override
  Future<Response<dynamic>> approve(
    String challenge, {
    CancelToken? cancelToken,
  }) {
    return _apiClient.post(
      UrlUtil.hubQrLogin,
      data: <String, dynamic>{'code': challenge},
      headers: const <String, dynamic>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      cancelToken: cancelToken,
    );
  }
}

typedef SessionTokenProvider = String? Function();
typedef QrClock = DateTime Function();
typedef QrRetryDelay = Future<void> Function(Duration duration);

class QrLoginService {
  QrLoginService({
    QrApprovalTransport? transport,
    SessionTokenProvider? sessionTokenProvider,
    QrClock? clock,
    QrRetryDelay? retryDelay,
  })  : _transport = transport ?? OdooQrApprovalTransport(),
        _sessionTokenProvider = sessionTokenProvider ?? _currentSessionToken,
        _clock = clock ?? DateTime.now,
        _retryDelay =
            retryDelay ?? ((duration) => Future<void>.delayed(duration));

  static final RegExp _challengePattern = RegExp(r'^rcc_[A-Za-z0-9_-]{43}$');
  static final RegExp _explicitTimezonePattern = RegExp(
    r'(Z|[+-]\d{2}:\d{2})$',
    caseSensitive: false,
  );
  static const Set<String> _payloadKeys = <String>{
    'type',
    'version',
    'challenge',
    'expires_at',
  };
  static const Duration _clockSkewAllowance = Duration(seconds: 30);
  static const Duration _retryInterval = Duration(milliseconds: 350);

  final QrApprovalTransport _transport;
  final SessionTokenProvider _sessionTokenProvider;
  final QrClock _clock;
  final QrRetryDelay _retryDelay;

  static String? _currentSessionToken() =>
      SharedPref.getLoginDataOrNull()?.result?.token?.trim();

  Future<Map<String, dynamic>> loginWithQrCode(
    String qrCode, {
    CancelToken? cancelToken,
  }) async {
    final sessionToken = _sessionTokenProvider()?.trim();
    if (sessionToken == null || sessionToken.isEmpty) {
      return _failure(
        'Your session has expired. Please sign in again.',
        code: 'AUTH_REQUIRED',
      );
    }

    final parsed = _parsePayload(qrCode);
    if (parsed.error != null) {
      return parsed.error!;
    }

    final challenge = parsed.challenge!;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await _transport.approve(
          challenge,
          cancelToken: cancelToken,
        );
        return _parseRelayResponse(response);
      } on DioException catch (error) {
        if (CancelToken.isCancel(error)) {
          return _failure('QR approval cancelled.', code: 'CANCELLED');
        }

        if (attempt == 0 && _isTransient(error)) {
          await _retryDelay(_retryInterval);
          continue;
        }

        final response = error.response;
        if (response != null) {
          return _parseRelayResponse(response);
        }

        return _failure(
          'Unable to reach the server. Please try again.',
          code: 'NETWORK_ERROR',
        );
      } catch (_) {
        return _failure(
          'Unable to approve this QR code. Please try again.',
          code: 'UNEXPECTED_ERROR',
        );
      }
    }

    return _failure(
      'Unable to reach the server. Please try again.',
      code: 'NETWORK_ERROR',
    );
  }

  _ParsedQrPayload _parsePayload(String rawPayload) {
    dynamic decoded;
    try {
      decoded = jsonDecode(rawPayload.trim());
    } catch (_) {
      return _ParsedQrPayload.error(
        _failure(
          'This QR code is not a supported Hub login code.',
          code: 'INVALID_QR',
        ),
      );
    }

    if (decoded is! Map) {
      return _ParsedQrPayload.error(
        _failure(
          'This QR code is not a supported Hub login code.',
          code: 'INVALID_QR',
        ),
      );
    }

    final payload = Map<String, dynamic>.from(decoded);
    if (payload.keys.any((key) => !_payloadKeys.contains(key))) {
      return _ParsedQrPayload.error(
        _failure(
          'This QR code is not a supported Hub login code.',
          code: 'INVALID_QR',
        ),
      );
    }

    if (payload['type'] != 'rcc_hub_login') {
      return _ParsedQrPayload.error(
        _failure(
          'This QR code is not a Hub login code.',
          code: 'INVALID_QR_TYPE',
        ),
      );
    }

    if (payload['version'] != 2) {
      return _ParsedQrPayload.error(
        _failure(
          'This Hub QR version is not supported. Please refresh the Hub page.',
          code: 'UNSUPPORTED_VERSION',
        ),
      );
    }

    final challenge = payload['challenge'];
    if (challenge is! String || !_challengePattern.hasMatch(challenge)) {
      return _ParsedQrPayload.error(
        _failure('This Hub QR code is invalid.', code: 'INVALID_CHALLENGE'),
      );
    }

    final expiresAtRaw = payload['expires_at'];
    final expiresAt = expiresAtRaw is String &&
            _explicitTimezonePattern.hasMatch(expiresAtRaw)
        ? DateTime.tryParse(expiresAtRaw)?.toUtc()
        : null;
    if (expiresAt == null) {
      return _ParsedQrPayload.error(
        _failure('This Hub QR code is invalid.', code: 'INVALID_EXPIRY'),
      );
    }

    final now = _clock().toUtc();
    if (expiresAt.add(_clockSkewAllowance).isBefore(now)) {
      return _ParsedQrPayload.error(
        _failure(
          'This Hub QR code has expired. Refresh the Hub page and scan again.',
          code: 'EXPIRED',
        ),
      );
    }

    return _ParsedQrPayload.success(challenge);
  }

  Map<String, dynamic> _parseRelayResponse(Response<dynamic> response) {
    final statusCode = response.statusCode ?? 0;
    final envelope = _asStringMap(response.data);
    final result = _asStringMap(envelope?['result']);
    final payload = result ?? envelope;
    final relayStatus = payload?['status']?.toString().toLowerCase();
    final errorCode = payload?['code']?.toString().toUpperCase();
    final message = payload?['message']?.toString().trim();

    if (statusCode >= 200 &&
        statusCode < 300 &&
        (relayStatus == 'success' || payload?['success'] == true)) {
      return <String, dynamic>{
        'success': true,
        'message': 'Approved. Continue on the Hub.',
      };
    }

    if (statusCode == 401 ||
        errorCode == 'MISSING_TOKEN' ||
        errorCode == 'INVALID_TOKEN' ||
        errorCode == 'TOKEN_EXPIRED') {
      return _failure(
        'Your session has expired. Please sign in again.',
        code: errorCode ?? 'AUTH_REQUIRED',
      );
    }

    if (statusCode == 409 ||
        errorCode == 'ALREADY_USED' ||
        errorCode == 'ALREADY_APPROVED') {
      return _failure(
        'This Hub QR code has already been used. Refresh the Hub page.',
        code: errorCode ?? 'ALREADY_USED',
      );
    }

    if (statusCode == 410 ||
        errorCode == 'EXPIRED' ||
        errorCode == 'CODE_EXPIRED') {
      return _failure(
        'This Hub QR code has expired. Refresh the Hub page and scan again.',
        code: errorCode ?? 'EXPIRED',
      );
    }

    return _failure(
      message == null || message.isEmpty
          ? 'Unable to approve this Hub QR code.'
          : message,
      code: errorCode ?? 'APPROVAL_FAILED',
    );
  }

  static bool _isTransient(DioException error) => <DioExceptionType>{
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      }.contains(error.type);

  static Map<String, dynamic>? _asStringMap(dynamic value) {
    if (value is! Map) return null;
    return Map<String, dynamic>.from(value);
  }

  static Map<String, dynamic> _failure(String message, {required String code}) {
    return <String, dynamic>{
      'success': false,
      'message': message,
      'code': code,
    };
  }
}

class _ParsedQrPayload {
  const _ParsedQrPayload.success(this.challenge) : error = null;

  const _ParsedQrPayload.error(this.error) : challenge = null;

  final String? challenge;
  final Map<String, dynamic>? error;
}
