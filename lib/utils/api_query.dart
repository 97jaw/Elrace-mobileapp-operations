import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:el_race/utils/urll_utils.dart';
import 'package:path_provider/path_provider.dart';

class ApiQuery {
  var dio = Dio();

  String _joinUrl(String base, String path) {
    final normalizedBase = base.endsWith('/') ? base : '$base/';
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return '$normalizedBase$normalizedPath';
  }

  //post query
  Future<Response?> postQuery(String url, Map<String, String> headers,
      dynamic data, String apiName, bool isBaseUrlAdded) async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;

    var cookieJar = PersistCookieJar(
        ignoreExpires: true, storage: FileStorage("$appDocPath/.cookies/"));
    Response response;

    try {
      dio.interceptors.add(CookieManager(cookieJar));

      Options options = Options(method: 'POST', headers: headers);

      //dio.options.headers = headers;
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          return handler.next(options); //continue
        },
        onResponse: (response, handler) {
          return handler.next(response); //continue
        },
        onError: (DioException e, handler) {
          return handler.next(e); //continue
        },
      ));

      final primaryUrl = isBaseUrlAdded ? _joinUrl(UrlUtil.baseUrl, url) : url;
      response =
          await dio.post(primaryUrl, data: jsonEncode(data), options: options);

      return _normalizeResponse(response);
    } on DioException catch (exception) {
      if (exception.toString().contains('SocketException')) {
        return _normalizeResponse(exception.response);
      } else if (exception.type == DioException.receiveTimeout) {
        return _normalizeResponse(exception.response);
      } else {
        return _normalizeResponse(exception.response);
      }
    }
  }

  //put query
  Future<Response?> putQuery(String url, Map<String, String> headers,
      dynamic data, String apiName) async {
    Response response;
    try {
      Options options = Options(headers: headers);

      //dio.options.headers = headers;
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          return handler.next(options); //continue
        },
        onResponse: (response, handler) {
          return handler.next(response); //continue
        },
        onError: (DioException e, handler) {
          return handler.next(e); //continue
        },
      ));
      response = await dio.put(_joinUrl(UrlUtil.baseUrl, url),
          data: data, options: options);
      return _normalizeResponse(response);
    } on DioException catch (exception) {
      if (exception.toString().contains('SocketException')) {
        return _normalizeResponse(exception.response);
      } else if (exception.type == DioException.receiveTimeout) {
        return _normalizeResponse(exception.response);
      } else {
        return _normalizeResponse(exception.response);
      }
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
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;

    // Options _cacheOptions = buildCacheOptions(const Duration(days: 1),
    //     forceRefresh: forceRefresh, primaryKey: apiName);
    var cookieJar = PersistCookieJar(
        ignoreExpires: true, storage: FileStorage("$appDocPath/.cookies/"));
    Response? response;

    try {
      dio.interceptors.add(CookieManager(cookieJar));

      Options options = Options(headers: headers);

      // if (isCached) {
      //   dio.interceptors.add(_dioCacheManager.interceptor);
      // }
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          return handler.next(options); //continue
        },
        onResponse: (response, handler) {
          return handler.next(response); //continue
        },
        onError: (DioException e, handler) {
          print(e.toString());
          return handler.next(e); //continue
        },
      ));
      if (isBaseUrlToBeAdded) {
        final primaryUrl = _joinUrl(UrlUtil.baseUrl, url);
        log(primaryUrl);
        if (isCached) {
          response = await dio.get(primaryUrl,
              options: options, queryParameters: query);
        } else {
          response = await dio.get(primaryUrl,
              options: options,
              queryParameters: (query != null) ? query : null);
        }
      } else {
        if (isCached) {
          response = await dio.get(url,
              options: options,
              queryParameters: (query != null) ? query : null);
        } else {
          response = await dio.get(url,
              options: options,
              queryParameters: (query != null) ? query : null);
        }
      }
      return _normalizeResponse(response);
    } on DioException catch (exception) {
      if (exception.toString().contains('SocketException')) {
        return _normalizeResponse(exception.response);
      } else if (exception.type == DioException.receiveTimeout) {
        return _normalizeResponse(exception.response);
      } else {
        return _normalizeResponse(exception.response);
      }
    }
  }

  //patch query
  Future<Response?> patchQuery(
      String url, dynamic data, String apiName, bool isBaseUrlToBeAdded) async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;
    var cookieJar = PersistCookieJar(
        ignoreExpires: true, storage: FileStorage("$appDocPath/.cookies/"));
    Response response;
    try {
      dio.interceptors.add(CookieManager(cookieJar));
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          return handler.next(options); //continue
        },
        onResponse: (response, handler) {
          return handler.next(response); //continue
        },
        onError: (DioException e, handler) {
          return handler.next(e); //continue
        },
      ));
      if (isBaseUrlToBeAdded) {
        response = await dio.patch(_joinUrl(UrlUtil.baseUrl, url), data: data);
      } else {
        response = await dio.patch(url, data: data);
      }
      return _normalizeResponse(response);
    } on DioException catch (exception) {
      if (exception.toString().contains('SocketException')) {
        return _normalizeResponse(exception.response);
      } else if (exception.type == DioException.receiveTimeout) {
        return _normalizeResponse(exception.response);
      } else {
        return _normalizeResponse(exception.response);
      }
    }
  }

  //logout query
  Future<Response?> logoutQuery(String url, dynamic data) async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;
    var cookieJar = PersistCookieJar(
        ignoreExpires: true, storage: FileStorage("$appDocPath/.cookies/"));
    cookieJar.deleteAll();
    Response response;
    try {
      dio.interceptors.add(CookieManager(cookieJar));
      dio.interceptors.clear();
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          return handler.next(options); //continue
        },
        onResponse: (response, handler) {
          return handler.next(response); //continue
        },
        onError: (DioException e, handler) {
          return handler.next(e); //continue
        },
      ));
      response = await dio.post(_joinUrl(UrlUtil.baseUrl, url), data: data);

      return _normalizeResponse(response);
    } on DioException catch (exception) {
      if (exception.toString().contains('SocketException')) {
        return _normalizeResponse(exception.response);
      } else if (exception.type == DioException.receiveTimeout) {
        return _normalizeResponse(exception.response);
      } else {
        return _normalizeResponse(exception.response);
      }
    }
  }

  //delete query
  Future<Response?> deleteQuery(String url, Map<String, String> headers,
      dynamic data, String apiName, bool isBaseUrlToBeAdded) async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;

    Options options = Options(headers: headers);
    Response response;
    try {
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          return handler.next(options); //continue
        },
        onResponse: (response, handler) {
          return handler.next(response); //continue
        },
        onError: (DioException e, handler) {
          return handler.next(e); //continue
        },
      ));
      if (isBaseUrlToBeAdded) {
        response = await dio.delete(_joinUrl(UrlUtil.baseUrl, url),
            queryParameters: data, options: options);
      } else {
        response =
            await dio.delete(url, queryParameters: data, options: options);
      }
      return _normalizeResponse(response);
    } on DioException catch (exception) {
      if (exception.toString().contains('SocketException')) {
        return _normalizeResponse(exception.response);
      } else if (exception.type == DioException.receiveTimeout) {
        return _normalizeResponse(exception.response);
      } else {
        return _normalizeResponse(exception.response);
      }
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
