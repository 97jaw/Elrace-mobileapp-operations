import 'package:dio/dio.dart';
import 'package:el_race/config/uaepass_config.dart';
import 'package:el_race/core/services/mobile_device_id_service.dart';
import 'package:el_race/core/session/post_login_setup.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/data/services/hive_service.dart';
import 'package:el_race/firebase_service.dart';
import 'package:el_race/services/api_client.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:el_race/utils/api_query.dart';
import 'package:el_race/utils/string_utils.dart';
import 'package:el_race/utils/uaepass_logger.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

enum AuthFailureType { existingOnly, unverified, generic, cancelled, noSession }

class UaepassAuthResult {
  final bool isSuccess;
  final LoginResponseModel? loginResponse;
  final AuthFailureType? failureType;
  final String? backendErrorCode;

  const UaepassAuthResult.success(this.loginResponse)
      : isSuccess = true,
        failureType = null,
        backendErrorCode = null;

  const UaepassAuthResult.failure(this.failureType, {this.backendErrorCode})
      : isSuccess = false,
        loginResponse = null;
}

class UaepassAuthService {
  static const _stateKey = 'uaepass_state';
  static const _sessionKey = 'uaepass_session';
  static const _txKey = 'uaepass_tx';

  static Future<UaepassAuthResult>? _activeExchange;
  static String? _activeExchangeSession;

  final UaepassConfig config;
  final ApiClient apiClient;
  final FlutterSecureStorage secureStorage;
  final Uuid _uuid;

  String? _pendingState;

  UaepassAuthService({
    required this.config,
    required this.apiClient,
    required this.secureStorage,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  Future<void> startLogin() async {
    UaepassLogger.logSection('UAE PASS LOGIN START');
    UaepassLogger.logKV('Environment', 'STAGING');
    UaepassLogger.logKV('Timestamp', DateTime.now().toIso8601String());
    UaepassLogger.logKV('client_id', config.clientId);
    UaepassLogger.logKV('redirect_uri (raw)', config.redirectUrl);
    UaepassLogger.logKV('redirect_uri (encoded)', Uri.encodeComponent(config.redirectUrl));
    UaepassLogger.logKV('scope (raw)', config.scope);
    UaepassLogger.logKV('scope (encoded)', Uri.encodeComponent(config.scope));
    UaepassLogger.logKV('response_type', config.responseType);
    UaepassLogger.logKV('acr_values (raw)', config.acrValues);
    UaepassLogger.logKV('acr_values (encoded)', Uri.encodeComponent(config.acrValues));

    final state = _uuid.v4();
    _pendingState = state;
    await secureStorage.write(key: _stateKey, value: state);
    UaepassLogger.logKV('state', state);
    UaepassLogger.logKV('state stored in', 'memory + secure_storage');

    final authUrl = config.buildAuthorizationUrl(state);
    UaepassLogger.log('Authorization URL (with acr_values):');
    UaepassLogger.logKV('Full URL', authUrl.toString());

    UaepassLogger.log('Opening system browser for UAE PASS');
    UaepassLogger.logKV('LaunchMode', 'externalApplication (Custom Tabs / Safari)');

    try {
      final launched = await launchUrl(
        authUrl,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        UaepassLogger.logError('Failed to open browser - launchUrl returned false');
        throw Exception('Unable to open UAE PASS');
      }
      UaepassLogger.logSuccess('Browser opened successfully');
    } catch (e) {
      UaepassLogger.logError('Exception opening browser', e);
      rethrow;
    }
  }

  Future<UaepassAuthResult> handleCallbackOrResult(Uri uri) async {
    UaepassLogger.logSection('DEEPLINK RECEIVED');
    UaepassLogger.logUri('Incoming URI', uri);

    if (_isCancelled(uri)) {
      UaepassLogger.logWarning('User cancelled or declined');
      UaepassLogger.logError('UAEPASS LOGIN FAILED', 'User cancel');
      return const UaepassAuthResult.failure(AuthFailureType.cancelled);
    }

    final storedState = await secureStorage.read(key: _stateKey);
    final incomingState = uri.queryParameters['state'];
    UaepassLogger.logKV('Stored state', storedState);
    UaepassLogger.logKV('Incoming state', incomingState);

    if (incomingState != null && storedState != null) {
      if (incomingState != storedState) {
        UaepassLogger.logError('State mismatch - possible CSRF attack');
        UaepassLogger.logError('UAEPASS LOGIN FAILED', 'Invalid state');
        return const UaepassAuthResult.failure(AuthFailureType.generic);
      }
      UaepassLogger.logSuccess('State validation passed');
    }

    if (config.useBackendRedirectDeepLink) {
      final session = uri.queryParameters['session'];
      final tx = uri.queryParameters['tx'] ?? uri.queryParameters['transaction'];
      final errorParam = uri.queryParameters['error'];
      final errorCode = uri.queryParameters['error_code'] ?? uri.queryParameters['code'];

      UaepassLogger.logKV('session param', session ?? '<not present>');
      UaepassLogger.logKV('tx param', tx ?? '<not present>');
      UaepassLogger.logKV('error param', errorParam ?? '<not present>');
      UaepassLogger.logKV('error_code param', errorCode ?? '<not present>');

      // Handle error deep links first (e.g. elrace://uaepass/error?code=GENERIC)
      // Check before session/tx so error responses are properly caught.
      if (config.isErrorLink(uri)) {
        final deepLinkErrorCode = errorCode ?? errorParam ?? 'GENERIC';
        UaepassLogger.logWarning('Error deep link received: $deepLinkErrorCode');
        final failureType = mapBackendErrorToFailureType(
          errorCode: deepLinkErrorCode,
        );
        UaepassLogger.logError('UAEPASS LOGIN FAILED', 'Error deep link: $deepLinkErrorCode');
        UaepassLogger.logKV('Mapped failure type', _failureTypeToString(failureType));
        return UaepassAuthResult.failure(failureType, backendErrorCode: deepLinkErrorCode);
      }

      if (session != null && session.isNotEmpty) {
        await secureStorage.write(key: _sessionKey, value: session);
        UaepassLogger.log('Session stored, proceeding to exchange');
        UaepassLogger.logKV('session (prefix)', '${session.substring(0, session.length.clamp(0, 8))}...');
        return _exchangeSession(session);
      }

      if (tx != null && tx.isNotEmpty) {
        await secureStorage.write(key: _txKey, value: tx);
        UaepassLogger.log('Transaction stored, exchanging as session');
        return _exchangeSession(tx);
      }

      // Check for error codes in the deep link (e.g. NOT_ELIGIBLE, EXISTING_USERS_ONLY)
      final deepLinkErrorCode = errorCode ?? errorParam;
      if (deepLinkErrorCode != null && deepLinkErrorCode.isNotEmpty) {
        UaepassLogger.logWarning('Error code from deep link: $deepLinkErrorCode');
        final failureType = mapBackendErrorToFailureType(
          errorCode: deepLinkErrorCode,
        );
        UaepassLogger.logError('UAEPASS LOGIN FAILED', 'Deep link error: $deepLinkErrorCode');
        UaepassLogger.logKV('Mapped failure type', _failureTypeToString(failureType));
        return UaepassAuthResult.failure(failureType, backendErrorCode: deepLinkErrorCode);
      }

      UaepassLogger.logError('No session or tx in deeplink');
      UaepassLogger.logError('UAEPASS LOGIN FAILED', 'Missing session/tx');
      return const UaepassAuthResult.failure(AuthFailureType.generic);
    }

    UaepassLogger.log('Using polling fallback');
    final session = await secureStorage.read(key: _sessionKey);
    final tx = await secureStorage.read(key: _txKey);
    final pollKey = (session != null && session.isNotEmpty)
        ? session
        : (tx != null && tx.isNotEmpty)
            ? tx
            : null;
    if (pollKey == null) {
      return const UaepassAuthResult.failure(AuthFailureType.noSession);
    }
    return _pollForResult(pollKey: pollKey);
  }

  AuthFailureType mapBackendErrorToFailureType({
    int? statusCode,
    String? errorCode,
    String? message,
  }) {
    final normalized = (errorCode ?? message ?? '').toLowerCase();

    if (normalized.contains('existing') || normalized.contains('signup')) {
      return AuthFailureType.existingOnly;
    }

    if (normalized.contains('unverified') ||
        normalized.contains('not_eligible') ||
        normalized.contains('not eligible')) {
      return AuthFailureType.unverified;
    }

    if (normalized.contains('cancel') || normalized.contains('decline')) {
      return AuthFailureType.cancelled;
    }

    if (statusCode != null && statusCode >= 400) {
      return AuthFailureType.generic;
    }

    return AuthFailureType.generic;
  }

  /// Try to finalize login from stored session/tx/state data
  /// Called when user taps "I have approved in UAE PASS" button
  Future<UaepassAuthResult> tryFinalizeFromStoredData() async {
    UaepassLogger.logSection('TRY FINALIZE FROM STORED DATA');

    final session = await secureStorage.read(key: _sessionKey);
    if (session != null && session.isNotEmpty) {
      UaepassLogger.log('Found stored session, exchanging...');
      UaepassLogger.logKV('session (prefix)', '${session.substring(0, 8)}...');
      final result = await _exchangeSession(session);
      if (result.isSuccess || result.failureType != AuthFailureType.generic) {
        return result;
      }
    }

    final tx = await secureStorage.read(key: _txKey);
    if (tx != null && tx.isNotEmpty && tx != session) {
      UaepassLogger.log('Found stored tx, exchanging as session...');
      UaepassLogger.logKV('tx (prefix)', '${tx.substring(0, 8)}...');
      final result = await _exchangeSession(tx);
      if (result.isSuccess || result.failureType != AuthFailureType.generic) {
        return result;
      }
    }

    // OAuth state is NOT a backend session id — never send it to /mobile/session.
    if ((session == null || session.isEmpty) && (tx == null || tx.isEmpty)) {
      UaepassLogger.logWarning(
        'No session from deep link yet — user must return via elrace://uaepass/success',
      );
      return const UaepassAuthResult.failure(AuthFailureType.noSession);
    }

    if (config.enablePollingFallback) {
      final pollKey = session ?? tx;
      if (pollKey != null && pollKey.isNotEmpty) {
        UaepassLogger.log('Polling session exchange...');
        return _pollForResult(pollKey: pollKey);
      }
    }

    return const UaepassAuthResult.failure(AuthFailureType.noSession);
  }

  Future<void> logout() async {
    UaepassLogger.logSection('LOGOUT');
    UaepassLogger.log('Clearing UAE PASS session data');

    _pendingState = null;
    await secureStorage.delete(key: _stateKey);
    await secureStorage.delete(key: _sessionKey);
    await secureStorage.delete(key: _txKey);
    UaepassLogger.logSuccess('Secure storage cleared (state, session, tx)');

    await SharedPref().setPreferencesBoolean('isRegistered', false);
    await SharedPref().removePreference('loginResponse');
    await HiveService.setUserLoggedIn(false);
    UaepassLogger.logSuccess('SharedPreferences cleared');
    UaepassLogger.log('Navigation should return to Login screen');
  }

  Future<UaepassAuthResult> _exchangeSession(String session) async {
    if (_activeExchangeSession == session && _activeExchange != null) {
      UaepassLogger.log('Reusing in-flight session exchange');
      return _activeExchange!;
    }

    final exchange = _exchangeSessionOnce(session);
    _activeExchangeSession = session;
    _activeExchange = exchange;
    try {
      return await exchange;
    } finally {
      if (_activeExchangeSession == session) {
        _activeExchange = null;
        _activeExchangeSession = null;
      }
    }
  }

  Future<UaepassAuthResult> _exchangeSessionOnce(String session) async {
    UaepassLogger.logSection('API: SESSION EXCHANGE');
    try {
      // Drop stale login payload so session exchange is not affected by old JWT.
      await SharedPref().removePreference('loginResponse');

      final deviceId = await MobileDeviceIdService.getOrCreate();

      try {
        await FirebaseService.ensureFCMToken();
      } catch (e) {
        UaepassLogger.logError('Failed to ensure FCM token', e);
      }
      final String fcmTokenValue = SharedPref().getPreferenceString(fcm_token);

      final Map<String, dynamic> requestBody = {
        'jsonrpc': '2.0',
        'params': {
          'session': session,
          'device_id': deviceId,
          if (fcmTokenValue.isNotEmpty) 'fcm_token': fcmTokenValue,
        },
      };

      UaepassLogger.logKV('Endpoint', config.sessionExchangePath);
      UaepassLogger.logKV('Method', 'POST');
      UaepassLogger.logKV('device_id', deviceId);
      UaepassLogger.logKV('session (prefix)', '${session.substring(0, session.length.clamp(0, 8))}...');
      UaepassLogger.logKV('fcm_token', fcmTokenValue.isNotEmpty ? '${fcmTokenValue.substring(0, 20)}...' : '(empty)');

      final apiQuery = ApiQuery();
      const headers = {'Content-Type': 'application/json'};
      final response = await apiQuery.postQuery(
        config.sessionExchangePath,
        headers,
        requestBody,
        'uaepass_session',
        true,
      );

      UaepassLogger.logKV('Response status', response?.statusCode);
      UaepassLogger.log('Response body (masked):');
      if (response?.data is Map) {
        UaepassLogger.log(
          UaepassLogger.safeJsonEncode(
            Map<String, dynamic>.from(response!.data as Map),
          ),
        );
      } else {
        UaepassLogger.logKV('Response', response?.data?.toString());
      }

      if (response == null || response.statusCode != 200) {
        return const UaepassAuthResult.failure(AuthFailureType.generic);
      }

      return await _parseBackendResponse(response.data, response.statusCode);
    } catch (e) {
      UaepassLogger.logError('Session exchange error', e);
      UaepassLogger.logError('UAEPASS LOGIN FAILED', 'Session exchange exception');
      return const UaepassAuthResult.failure(AuthFailureType.generic);
    }
  }

  /// Backend exposes POST [sessionExchangePath] only — there is no GET result API.
  /// Treat [tx] as a session token and exchange it.
  Future<UaepassAuthResult> _fetchResultByTransaction(String tx) async {
    UaepassLogger.logSection('API: EXCHANGE TX AS SESSION');
    UaepassLogger.logKV('tx/session', tx);
    return _exchangeSession(tx);
  }

  Future<UaepassAuthResult> _pollForResult({required String pollKey}) async {
    UaepassLogger.logSection('API: SINGLE SESSION EXCHANGE (one-time token)');
    UaepassLogger.logKV('Poll session (prefix)', '${pollKey.substring(0, pollKey.length.clamp(0, 8))}...');
    return _exchangeSession(pollKey);
  }

  Future<UaepassAuthResult> _parseBackendResponse(
    dynamic data,
    int? statusCode,
  ) async {
    UaepassLogger.log('Parsing backend response');
    UaepassLogger.logKV('Status code', statusCode);

    if (data is! Map) {
      UaepassLogger.logError('Response is not a Map', 'Type: ${data.runtimeType}');
      UaepassLogger.logError('UAEPASS LOGIN FAILED', 'Invalid response format');
      return const UaepassAuthResult.failure(AuthFailureType.generic);
    }

    var map = PostLoginSetup.normalizeLoginPayload(
      PostLoginSetup.unwrapRawResponse(Map<String, dynamic>.from(data as Map)),
    );
    final resultMap = map['result'];
    final nestedResult = resultMap is Map
        ? Map<String, dynamic>.from(resultMap)
        : null;
    final errorCode = map['error_code']?.toString() ??
        nestedResult?['error_code']?.toString() ??
        map['code']?.toString();
    final errorMessage = map['message']?.toString() ??
        nestedResult?['message']?.toString() ??
        map['error']?.toString();

    UaepassLogger.logKV('error_code', errorCode ?? '<none>');
    UaepassLogger.logKV('message', errorMessage ?? '<none>');

    final success = nestedResult?['success'] == true ||
        map['result']?['success'] == true ||
        map['success'] == true;

    UaepassLogger.logKV('Success flag', success);

    if (!success) {
      final failureType = mapBackendErrorToFailureType(
        statusCode: statusCode,
        errorCode: errorCode,
        message: errorMessage,
      );
      UaepassLogger.logError('UAEPASS LOGIN FAILED');
      UaepassLogger.logKV('Error mapping result', _failureTypeToString(failureType));
      UaepassLogger.logKV('Backend error_code', errorCode ?? '<none>');
      return UaepassAuthResult.failure(
        failureType,
        backendErrorCode: errorCode,
      );
    }

    final token = nestedResult?['token'] ?? map['result']?['token'];
    if (token == null || token.toString().isEmpty) {
      UaepassLogger.logError('UAEPASS LOGIN FAILED', 'Missing token in response');
      return const UaepassAuthResult.failure(AuthFailureType.generic);
    }

    await _persistLogin(map);

    if (!PostLoginSetup.hasCompleteLoginData(map)) {
      UaepassLogger.logWarning(
        'Session exchange payload incomplete — hydrating from token',
      );
      final hydrated = await PostLoginSetup.hydrateLoginFromToken(map);
      if (hydrated != null) {
        map = hydrated;
        await _persistLogin(map);
      }
    }

    if (!PostLoginSetup.hasCompleteLoginData(map)) {
      UaepassLogger.logError(
        'Login payload still incomplete after hydrate',
        'missing employee/widgets',
      );
      return const UaepassAuthResult.failure(AuthFailureType.generic);
    }

    final finalLoginResponse = _tryParseLoginResponse(map);
    if (finalLoginResponse == null) {
      return const UaepassAuthResult.failure(AuthFailureType.generic);
    }

    final dataBlock = map['result'] is Map ? map['result']['data'] : null;
    UaepassLogger.logKV(
      'persisted odoo_user_id',
      dataBlock is Map ? dataBlock['odoo_user_id'] : '<no data>',
    );
    UaepassLogger.logKV(
      'employee_configured',
      dataBlock is Map ? dataBlock['employee_configured'] : '<no data>',
    );
    UaepassLogger.logKV(
      'has firebase_custom_token',
      dataBlock is Map && dataBlock['firebase_custom_token'] != null,
    );
    UaepassLogger.logSuccess('UAEPASS LOGIN SUCCESS');
    UaepassLogger.logKV('User ID', finalLoginResponse.result?.data?.uid ?? finalLoginResponse.result?.data?.emp_id);
    UaepassLogger.logKV('Name', finalLoginResponse.result?.data?.name);
    final widgetKeys = finalLoginResponse.result?.data?.defaultWidgets?.data;
    UaepassLogger.logKV(
      'default_widgets parsed',
      widgetKeys != null ? 'yes' : 'MISSING',
    );
    return UaepassAuthResult.success(finalLoginResponse);
  }

  String _failureTypeToString(AuthFailureType type) {
    switch (type) {
      case AuthFailureType.existingOnly:
        return 'EXISTING_USERS_ONLY';
      case AuthFailureType.unverified:
        return 'NOT_ELIGIBLE';
      case AuthFailureType.cancelled:
        return 'CANCELLED';
      case AuthFailureType.generic:
        return 'GENERIC';
      case AuthFailureType.noSession:
        return 'NO_SESSION';
    }
  }

  LoginResponseModel? _tryParseLoginResponse(Map<String, dynamic> map) {
    try {
      final normalized = PostLoginSetup.normalizeLoginPayload(map);
      if (normalized.containsKey('result')) {
        return LoginResponseModel.fromJson(normalized);
      }
      if (normalized.containsKey('loginResponse')) {
        return LoginResponseModel.fromJson(
          Map<String, dynamic>.from(normalized['loginResponse'] as Map),
        );
      }
    } catch (_) {}
    return null;
  }

  Future<void> _persistLogin(Map<String, dynamic> rawJsonRpc) async {
    await PostLoginSetup.persistLoginResponse(rawJsonRpc);
  }

  bool _isCancelled(Uri uri) {
    final error = uri.queryParameters['error']?.toLowerCase();
    final status = uri.queryParameters['status']?.toLowerCase();
    final result = uri.queryParameters['result']?.toLowerCase();

    // Only treat explicit user cancellation signals as "cancelled".
    // Do NOT treat all error deep links as cancelled — they may carry
    // specific error codes (NOT_ELIGIBLE, EXISTING_USERS_ONLY, etc.)
    // that should flow through to handleCallbackOrResult for proper mapping.
    final isExplicitCancel = error == 'access_denied' ||
        status == 'cancel' ||
        status == 'cancelled' ||
        result == 'cancel' ||
        result == 'cancelled';

    // If it's an error deep link, only treat it as cancelled when there is
    // NO specific error code attached — i.e. a bare error link means the
    // user dismissed UAE PASS without completing.
    if (config.isErrorLink(uri) && !isExplicitCancel) {
      final errorCode = uri.queryParameters['code']?.toLowerCase() ??
          uri.queryParameters['error_code']?.toLowerCase();
      if (errorCode != null && errorCode.isNotEmpty) {
        // Has a specific error code → let handleCallbackOrResult map it
        UaepassLogger.logKV('Error link with code', 'code=$errorCode — not treating as cancel');
        return false;
      }
      // Bare error link with no code → treat as cancel
      UaepassLogger.logKV('Bare error link', 'no code — treating as cancel');
      return true;
    }

    if (isExplicitCancel) {
      UaepassLogger.logKV('Cancel detected', 'error=$error, status=$status, result=$result');
    }
    return isExplicitCancel;
  }
}
