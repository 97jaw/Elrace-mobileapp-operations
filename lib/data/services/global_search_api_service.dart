import 'package:dio/dio.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/data/models/global_search_item.dart';
import 'package:flutter/foundation.dart';

/// Exception for global search API errors
class GlobalSearchApiException implements Exception {
  final String message;
  final int? statusCode;

  GlobalSearchApiException(this.message, {this.statusCode});

  @override
  String toString() =>
      'GlobalSearchApiException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

/// Parsed global search response including per-category totals from meta.
class GlobalSearchResultPage {
  const GlobalSearchResultPage({
    required this.items,
    this.countsByCategory = const {},
    this.totalCount = 0,
    this.limitPerCategory = 5,
  });

  final List<GlobalSearchItem> items;
  final Map<String, int> countsByCategory;
  final int totalCount;
  final int limitPerCategory;
}

/// Service for unified global search (`category=all` on ERP).
class GlobalSearchApiService {
  GlobalSearchApiService({
    Dio? dio,
    this.baseUrl = 'https://erp.elrace.com/api',
  }) : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 20),
              contentType: 'application/json',
              headers: {'Accept': 'application/json'},
            ));

  final Dio _dio;
  final String baseUrl;
  CancelToken? _cancelToken;

  /// Unified search across all ERP domains in one request.
  Future<GlobalSearchResultPage> globalSearchAll({
    required String keyword,
    int limitPerCategory = 5,
    CancelToken? cancelToken,
  }) async {
    if (keyword.trim().isEmpty) {
      return const GlobalSearchResultPage(items: []);
    }

    return _search(
      keyword: keyword,
      params: {
        'category': 'all',
        'keyword': keyword.trim(),
        'limit_per_category': limitPerCategory.clamp(1, 10),
      },
      limitPerCategory: limitPerCategory,
      cancelToken: cancelToken,
    );
  }

  /// Load additional rows for one category (uses ERP single-category search).
  Future<GlobalSearchResultPage> globalSearchCategory({
    required String category,
    required String keyword,
    int limit = 50,
    CancelToken? cancelToken,
  }) async {
    if (keyword.trim().isEmpty) {
      return const GlobalSearchResultPage(items: []);
    }

    return _search(
      keyword: keyword,
      params: {
        'category': category,
        'keyword': keyword.trim(),
        'limit': limit.clamp(1, 50),
      },
      limitPerCategory: limit,
      cancelToken: cancelToken,
    );
  }

  Future<GlobalSearchResultPage> _search({
    required String keyword,
    required Map<String, dynamic> params,
    required int limitPerCategory,
    CancelToken? cancelToken,
  }) async {
    try {
      final token = SharedPref.getLoginData().result?.token;
      if (token == null || token.isEmpty) {
        throw GlobalSearchApiException('Authentication token not found');
      }

      final url = '$baseUrl/global/search';
      final requestBody = {
        'jsonrpc': '2.0',
        'params': params,
      };

      final response = await _dio.post(
        url,
        data: requestBody,
        cancelToken: cancelToken,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        return _parseResponse(response.data, limitPerCategory: limitPerCategory);
      }
      throw GlobalSearchApiException(
        'Search failed',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      if (e is GlobalSearchApiException) rethrow;
      throw GlobalSearchApiException('Unexpected error: ${e.toString()}');
    }
  }

  GlobalSearchResultPage _parseResponse(
    dynamic data, {
    required int limitPerCategory,
  }) {
    try {
      dynamic result;

      if (data is Map<String, dynamic>) {
        if (data.containsKey('result')) {
          result = data['result'];
        } else if (data.containsKey('data')) {
          result = data['data'];
        } else {
          result = data;
        }
      } else {
        result = data;
      }

      _throwIfApiError(result);

      List<dynamic> items = [];
      if (result is List) {
        items = result;
      } else if (result is Map<String, dynamic>) {
        if (result.containsKey('data') && result['data'] is List) {
          items = result['data'] as List;
        } else if (result.containsKey('items') && result['items'] is List) {
          items = result['items'] as List;
        } else if (result.containsKey('results') &&
            result['results'] is List) {
          items = result['results'] as List;
        }
      }

      final parsed = items
          .where((item) => item is Map<String, dynamic>)
          .map((item) {
            try {
              return GlobalSearchItem.fromJson(item as Map<String, dynamic>);
            } catch (e) {
              if (kDebugMode) {
                debugPrint('Error parsing search item: $e');
              }
              return null;
            }
          })
          .whereType<GlobalSearchItem>()
          .toList();

      final meta = _extractMeta(result);
      return GlobalSearchResultPage(
        items: parsed,
        countsByCategory: meta.countsByCategory,
        totalCount: meta.totalCount,
        limitPerCategory: limitPerCategory,
      );
    } catch (e) {
      if (e is GlobalSearchApiException) rethrow;
      if (kDebugMode) {
        debugPrint('Error parsing search response: $e');
      }
      throw GlobalSearchApiException('Failed to parse search results');
    }
  }

  ({Map<String, int> countsByCategory, int totalCount}) _extractMeta(
    dynamic result,
  ) {
    Map<String, dynamic>? meta;
    if (result is Map<String, dynamic>) {
      final nested = result['meta'];
      if (nested is Map<String, dynamic>) {
        meta = nested;
      } else {
        meta = result;
      }
    }

    var totalCount = 0;
    final counts = <String, int>{};
    if (meta != null) {
      final rawTotal = meta['total_count'];
      if (rawTotal is int) {
        totalCount = rawTotal;
      } else if (rawTotal != null) {
        totalCount = int.tryParse(rawTotal.toString()) ?? 0;
      }

      final rawCounts = meta['counts_by_category'];
      if (rawCounts is Map) {
        rawCounts.forEach((key, value) {
          final n = value is int ? value : int.tryParse(value.toString());
          if (n != null && n > 0) {
            counts[key.toString()] = n;
          }
        });
      }
    }

    return (countsByCategory: counts, totalCount: totalCount);
  }

  void _throwIfApiError(dynamic payload) {
    if (payload is! Map<String, dynamic>) return;
    final status = payload['status']?.toString();
    if (status == 'error') {
      final message = payload['message']?.toString() ?? 'Search failed';
      throw GlobalSearchApiException(message);
    }
  }

  GlobalSearchApiException _handleDioError(DioException error) {
    if (error.type == DioExceptionType.cancel) {
      return GlobalSearchApiException('Search cancelled');
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return GlobalSearchApiException(
          'Connection timeout. Please check your internet connection.',
        );

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final message = _extractErrorMessage(error.response?.data);

        if (statusCode == 401) {
          return GlobalSearchApiException(
            'Unauthorized. Please login again.',
            statusCode: statusCode,
          );
        } else if (statusCode == 404) {
          return GlobalSearchApiException(
            'Search endpoint not found.',
            statusCode: statusCode,
          );
        } else if (statusCode != null && statusCode >= 500) {
          return GlobalSearchApiException(
            'Server error. Please try again later.',
            statusCode: statusCode,
          );
        }

        return GlobalSearchApiException(
          message ?? 'Search failed',
          statusCode: statusCode,
        );

      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
      default:
        return GlobalSearchApiException(
          'Network error. Please check your internet connection.',
        );
    }
  }

  String? _extractErrorMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data.containsKey('error')) {
        final error = data['error'];
        if (error is Map<String, dynamic>) {
          return error['message'] ?? error['data']?['message'];
        } else if (error is String) {
          return error;
        }
      }
      if (data.containsKey('message')) {
        return data['message'];
      }
    }
    return null;
  }

  CancelToken createCancelToken() {
    cancelRequests();
    _cancelToken = CancelToken();
    return _cancelToken!;
  }

  void cancelRequests() {
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('cancelled');
    }
    _cancelToken = null;
  }
}
