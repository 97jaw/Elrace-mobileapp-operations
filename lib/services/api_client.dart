import 'package:dio/dio.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/utils/uaepass_logger.dart';
import 'package:flutter/foundation.dart';

class _UaepassLoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      UaepassLogger.log('────────────────────────────────────────');
      UaepassLogger.log('API REQUEST');
      UaepassLogger.logKV('Method', options.method);
      UaepassLogger.logKV('URL', '${options.baseUrl}${options.path}');
      if (options.queryParameters.isNotEmpty) {
        UaepassLogger.log('Query Params (masked):');
        UaepassLogger.log(UaepassLogger.safeJsonEncode(options.queryParameters));
      }
      if (options.data != null && options.data is Map) {
        UaepassLogger.log('Request Body (masked):');
        UaepassLogger.log(UaepassLogger.safeJsonEncode(Map<String, dynamic>.from(options.data as Map)));
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      UaepassLogger.log('API RESPONSE');
      UaepassLogger.logKV('Status', response.statusCode);
      UaepassLogger.logKV('URL', response.requestOptions.uri.toString());
      if (response.data is Map) {
        UaepassLogger.log('Response Body (masked):');
        UaepassLogger.log(UaepassLogger.safeJsonEncode(Map<String, dynamic>.from(response.data as Map)));
      } else {
        UaepassLogger.logKV('Response', response.data?.toString()?.substring(0, 200));
      }
      UaepassLogger.log('────────────────────────────────────────');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      UaepassLogger.logError('API ERROR');
      UaepassLogger.logKV('URL', err.requestOptions.uri.toString());
      UaepassLogger.logKV('Status', err.response?.statusCode);
      UaepassLogger.logKV('Message', err.message);
      if (err.response?.data is Map) {
        UaepassLogger.log('Error Body (masked):');
        UaepassLogger.log(UaepassLogger.safeJsonEncode(Map<String, dynamic>.from(err.response!.data as Map)));
      }
      UaepassLogger.log('────────────────────────────────────────');
    }
    handler.next(err);
  }
}

/// Attaches `Authorization: Bearer <token>` once per request instead of
/// leaving each call site to do it manually (143 call sites did this
/// independently before this interceptor existed — see
/// INDEPENDENT_PERFORMANCE_AND_ARCHITECTURE_REVIEW.md §2). Requests that
/// already set their own Authorization header (e.g. a pre-login exchange)
/// are left alone, and requests made before login simply get no header
/// (no token in SharedPref yet).
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!options.headers.containsKey('Authorization')) {
      final token = SharedPref.getLoginDataOrNull()?.result?.token;
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }
}

/// Central hook for reacting to a session expiring (401) from any request
/// made through [ApiClient], instead of each of the ~19 independent Dio call
/// sites in the app handling (or, in most cases, not handling) this on their
/// own — this is the mechanism most likely behind the "logout stuck /
/// permission-denied" bug documented in
/// PERFORMANCE_OPTIMIZATION_TECHNICAL_REPORT.md.
///
/// [onSessionExpired] is deliberately left unset by this file — wiring it to
/// a concrete logout/re-auth navigation flow belongs to app startup code
/// outside lib/services/api_client.dart's scope for this change.
class AuthSessionExpiredHandler {
  AuthSessionExpiredHandler._();
  static final AuthSessionExpiredHandler instance = AuthSessionExpiredHandler._();

  void Function()? onSessionExpired;

  DateTime? _lastHandledAt;
  static const _dedupeWindow = Duration(seconds: 3);

  /// Multiple in-flight requests can all 401 around the same time once a
  /// session actually expires; only react to the first one in the window.
  void handle() {
    final now = DateTime.now();
    final last = _lastHandledAt;
    if (last != null && now.difference(last) < _dedupeWindow) {
      return;
    }
    _lastHandledAt = now;

    final callback = onSessionExpired;
    if (callback == null) {
      debugPrint(
          '⚠️ [ApiClient] 401 received but AuthSessionExpiredHandler.onSessionExpired is not wired up.');
      return;
    }
    callback();
  }
}

class AuthErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      AuthSessionExpiredHandler.instance.handle();
    }
    handler.next(err);
  }
}

/// Retries idempotent GETs with capped exponential backoff on transient
/// connection failures. Hand-rolled instead of adding the dio_smart_retry
/// dependency (per FIX_IMPLEMENTATION_PLAN.md Phase 4.1). POST/PUT/PATCH/
/// DELETE are never retried here — the backend has no documented idempotency
/// key support, so retrying a write could double-submit it.
class RetryInterceptor extends Interceptor {
  RetryInterceptor(this._dio);
  final Dio _dio;

  static const _maxAttempts = 3;
  static const _retryableTypes = {
    DioExceptionType.connectionError,
    DioExceptionType.connectionTimeout,
  };

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    if (options.method.toUpperCase() != 'GET' ||
        !_retryableTypes.contains(err.type)) {
      handler.next(err);
      return;
    }

    final attempt = (options.extra['retryAttempt'] as int? ?? 0) + 1;
    if (attempt > _maxAttempts) {
      handler.next(err);
      return;
    }

    final delay = Duration(milliseconds: 300 * (1 << (attempt - 1))); // 300/600/1200ms
    debugPrint(
        '🔁 [ApiClient] retrying GET ${options.path} (attempt $attempt/$_maxAttempts) after ${delay.inMilliseconds}ms');
    await Future.delayed(delay);

    try {
      options.extra['retryAttempt'] = attempt;
      final response = await _dio.fetch(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    } catch (_) {
      handler.next(err);
    }
  }
}

class ApiClient {
  final Dio _dio;

  ApiClient({required String baseUrl})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 20),
          ),
        ) {
    _dio.interceptors.addAll([
      AuthInterceptor(),
      AuthErrorInterceptor(),
      RetryInterceptor(_dio),
    ]);
    if (kDebugMode) {
      _dio.interceptors.add(_UaepassLoggingInterceptor());
    }
  }

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
  }) {
    return _dio.get(
      path,
      queryParameters: queryParameters,
      options: Options(headers: headers),
      cancelToken: cancelToken,
    );
  }

  Future<Response<dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
  }) {
    return _dio.post(
      path,
      data: data,
      queryParameters: queryParameters,
      options: Options(headers: headers),
      cancelToken: cancelToken,
    );
  }

  Future<Response<dynamic>> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
  }) {
    return _dio.put(
      path,
      data: data,
      queryParameters: queryParameters,
      options: Options(headers: headers),
      cancelToken: cancelToken,
    );
  }

  Future<Response<dynamic>> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
  }) {
    return _dio.patch(
      path,
      data: data,
      queryParameters: queryParameters,
      options: Options(headers: headers),
      cancelToken: cancelToken,
    );
  }

  Future<Response<dynamic>> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
  }) {
    return _dio.delete(
      path,
      data: data,
      queryParameters: queryParameters,
      options: Options(headers: headers),
      cancelToken: cancelToken,
    );
  }
}
