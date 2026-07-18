import 'dart:convert';
import 'dart:developer';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:el_race/utils/urll_utils.dart';
import 'package:path_provider/path_provider.dart';

class ApiQuery {
  // One Dio + one persistent cookie jar shared by every ApiQuery instance.
  // Previously each request re-created the cookie jar (disk I/O per call)
  // and stacked new interceptors onto the Dio instance without ever
  // removing them, degrading performance over the app session.
  static Future<Dio>? _dioFuture;
  static PersistCookieJar? _cookieJar;

  static Future<Dio> _sharedDio() {
    return _dioFuture ??= _createDio();
  }

  static Future<Dio> _createDio() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final cookieJar = PersistCookieJar(
      ignoreExpires: true,
      storage: FileStorage('${appDocDir.path}/.cookies/'),
    );
    _cookieJar = cookieJar;

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
      ),
    );
    dio.interceptors.add(CookieManager(cookieJar));
    return dio;
  }

  String _joinUrl(String base, String path) {
    final normalizedBase = base.endsWith('/') ? base : '$base/';
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return '$normalizedBase$normalizedPath';
  }

  //post query
  Future<Response?> postQuery(String url, Map<String, String> headers,
      dynamic data, String apiName, bool isBaseUrlAdded) async {
    try {
      final dio = await _sharedDio();
      final options = Options(method: 'POST', headers: headers);
      final primaryUrl = isBaseUrlAdded ? _joinUrl(UrlUtil.baseUrl, url) : url;
      final response =
          await dio.post(primaryUrl, data: jsonEncode(data), options: options);
      return _normalizeResponse(response);
    } on DioException catch (exception) {
      return _normalizeResponse(exception.response);
    }
  }

  //put query
  Future<Response?> putQuery(String url, Map<String, String> headers,
      dynamic data, String apiName) async {
    try {
      final dio = await _sharedDio();
      final options = Options(headers: headers);
      final response = await dio.put(_joinUrl(UrlUtil.baseUrl, url),
          data: data, options: options);
      return _normalizeResponse(response);
    } on DioException catch (exception) {
      return _normalizeResponse(exception.response);
    }
  }

  Future<Response?> getQuery(
    String url,
    Map<String, String> headers,
    Map<String, dynamic>? query,
    String apiName,
    bool isCached,
    bool isBaseUrlToBeAdded,
    bool forceRefresh,
  ) async {
    try {
      final dio = await _sharedDio();
      final options = Options(headers: headers);
      final primaryUrl =
          isBaseUrlToBeAdded ? _joinUrl(UrlUtil.baseUrl, url) : url;
      if (isBaseUrlToBeAdded) log(primaryUrl);
      final response = await dio.get(primaryUrl,
          options: options, queryParameters: query);
      return _normalizeResponse(response);
    } on DioException catch (exception) {
      return _normalizeResponse(exception.response);
    }
  }

  //patch query
  Future<Response?> patchQuery(
      String url, dynamic data, String apiName, bool isBaseUrlToBeAdded) async {
    try {
      final dio = await _sharedDio();
      final primaryUrl =
          isBaseUrlToBeAdded ? _joinUrl(UrlUtil.baseUrl, url) : url;
      final response = await dio.patch(primaryUrl, data: data);
      return _normalizeResponse(response);
    } on DioException catch (exception) {
      return _normalizeResponse(exception.response);
    }
  }

  //logout query
  Future<Response?> logoutQuery(String url, dynamic data) async {
    try {
      final dio = await _sharedDio();
      await _cookieJar?.deleteAll();
      final response =
          await dio.post(_joinUrl(UrlUtil.baseUrl, url), data: data);
      return _normalizeResponse(response);
    } on DioException catch (exception) {
      return _normalizeResponse(exception.response);
    }
  }

  //delete query
  Future<Response?> deleteQuery(String url, Map<String, String> headers,
      dynamic data, String apiName, bool isBaseUrlToBeAdded) async {
    try {
      final dio = await _sharedDio();
      final options = Options(headers: headers);
      final primaryUrl =
          isBaseUrlToBeAdded ? _joinUrl(UrlUtil.baseUrl, url) : url;
      final response =
          await dio.delete(primaryUrl, queryParameters: data, options: options);
      return _normalizeResponse(response);
    } on DioException catch (exception) {
      return _normalizeResponse(exception.response);
    }
  }

  dynamic _decodeIfJsonString(dynamic data) {
    if (data is String) {
      try {
        return jsonDecode(data);
      } catch (e) {
        log('Response decode failed: $e');
      }
    }
    return data;
  }

  Response? _normalizeResponse(Response? response) {
    if (response == null) return null;
    final decoded = _decodeIfJsonString(response.data);
    if (decoded is Map) {
      response.data = Map<String, dynamic>.from(decoded);
    } else {
      response.data = decoded;
    }
    return response;
  }
}
