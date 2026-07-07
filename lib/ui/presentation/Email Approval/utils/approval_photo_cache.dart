import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/Email%20Approval/utils/approval_display_helpers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Matches waiting-approval list categories. Detail APIs expose photos in
/// `form_view` that grouped list APIs omit.
enum ApprovalListCategory {
  hr,
  rfq,
  invoice,
  pettyCash,
}

abstract final class ApprovalPhotoCache {
  static const _baseUrl = 'https://erp.elrace.com';

  static final Map<String, String> _cache = {};
  static final Map<String, Future<String>> _inFlight = {};

  static ApprovalListCategory? fromCategoryKey(String categoryKey) {
    switch (categoryKey) {
      case 'hr':
        return ApprovalListCategory.hr;
      case 'rfq':
        return ApprovalListCategory.rfq;
      case 'invoice':
        return ApprovalListCategory.invoice;
      case 'petty_cash':
        return ApprovalListCategory.pettyCash;
      default:
        return null;
    }
  }

  static ApprovalAvatarKind avatarKind(ApprovalListCategory category) {
    return switch (category) {
      ApprovalListCategory.hr => ApprovalAvatarKind.employee,
      ApprovalListCategory.rfq ||
      ApprovalListCategory.invoice =>
        ApprovalAvatarKind.vendor,
      ApprovalListCategory.pettyCash => ApprovalAvatarKind.pettyCashHolder,
    };
  }

  static String _cacheKey(ApprovalListCategory category, String id) =>
      '${category.name}_$id';

  static String cachedPhoto(
    ApprovalListCategory category,
    Map<dynamic, dynamic> item,
  ) {
    final id = item['id']?.toString().trim() ?? '';
    if (id.isEmpty) return '';
    return _cache[_cacheKey(category, id)] ?? '';
  }

  static Future<String> resolve(
    ApprovalListCategory category,
    Map<dynamic, dynamic> item,
  ) async {
    final kind = avatarKind(category);
    final fromItem = ApprovalDisplayHelpers.pickImageUrl(item, kind);
    if (fromItem.isNotEmpty) {
      return ApprovalDisplayHelpers.normalizeImageUrl(fromItem);
    }

    final id = item['id']?.toString().trim() ?? '';
    if (id.isEmpty) return '';

    final key = _cacheKey(category, id);
    final cached = _cache[key];
    if (cached != null && cached.isNotEmpty) return cached;

    final pending = _inFlight[key];
    if (pending != null) return pending;

    final future = _fetchDetailPhoto(category, id);
    _inFlight[key] = future;
    try {
      final resolved = await future;
      if (resolved.isNotEmpty) {
        _cache[key] = resolved;
      }
      return resolved;
    } finally {
      _inFlight.remove(key);
    }
  }

  /// Prefetch detail photos for visible list rows (deduped + limited concurrency).
  static Future<void> warmList(
    ApprovalListCategory category,
    List<Map<String, dynamic>> items, {
    int concurrency = 4,
  }) async {
    if (items.isEmpty) return;

    final pending = <Future<void>>[];
    var index = 0;

    Future<void> worker() async {
      while (index < items.length) {
        final current = index++;
        final item = items[current];
        final kind = avatarKind(category);
        if (ApprovalDisplayHelpers.pickImageUrl(item, kind).isNotEmpty) {
          continue;
        }
        await resolve(category, item);
      }
    }

    for (var i = 0; i < concurrency && i < items.length; i++) {
      pending.add(worker());
    }
    await Future.wait(pending);
  }

  static Future<String> _fetchDetailPhoto(
    ApprovalListCategory category,
    String recordId,
  ) async {
    final parsedId = int.tryParse(recordId);
    if (parsedId == null) return '';

    final token = SharedPref.getLoginData().result?.token;
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final endpoint = switch (category) {
      ApprovalListCategory.hr => '$_baseUrl/api/get_hr_request_details',
      ApprovalListCategory.rfq => '$_baseUrl/api/get_rfq_details',
      ApprovalListCategory.invoice => '$_baseUrl/api/get_invoice_details',
      ApprovalListCategory.pettyCash => '$_baseUrl/api/get_petty_cash_details',
    };

    final params = switch (category) {
      ApprovalListCategory.hr => {'request_id': parsedId},
      ApprovalListCategory.rfq => {
          'rfq_id': parsedId,
          'comment': '',
        },
      ApprovalListCategory.invoice => {
          'invoice_id': parsedId,
          'comment': '',
        },
      ApprovalListCategory.pettyCash => {'petty_cash_id': parsedId},
    };

    try {
      final request = http.Request('GET', Uri.parse(endpoint))
        ..headers.addAll(headers)
        ..body = jsonEncode({'jsonrpc': '2.0', 'params': params});

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode != 200) return '';

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return '';

      final result = decoded['result'];
      if (result is! Map) return '';

      final formMap = _extractFormMap(category, result);
      if (formMap.isEmpty) return '';

      final kind = avatarKind(category);
      final photo = ApprovalDisplayHelpers.pickImageUrl(formMap, kind);
      if (photo.isEmpty) {
        debugPrint(
          '[ApprovalPhotoCache] $category/$recordId detail has no photo',
        );
        return '';
      }

      return ApprovalDisplayHelpers.normalizeImageUrl(photo);
    } catch (e) {
      debugPrint('[ApprovalPhotoCache] $category/$recordId failed: $e');
      return '';
    }
  }

  static Map<dynamic, dynamic> _extractFormMap(
    ApprovalListCategory category,
    Map result,
  ) {
    final data = result['data'];
    if (data is! Map) return const {};

    final map = Map<dynamic, dynamic>.from(data);

    switch (category) {
      case ApprovalListCategory.hr:
        final formView = map['form_view'];
        final merged = formView is Map
            ? Map<dynamic, dynamic>.from(formView)
            : Map<dynamic, dynamic>.from(map);
        for (final key in const ['employee_info', 'request_info']) {
          final nested = map[key] ?? merged[key];
          if (nested is Map) {
            merged.addAll(Map<dynamic, dynamic>.from(nested));
          }
        }
        return merged;

      case ApprovalListCategory.rfq:
      case ApprovalListCategory.invoice:
        final formView = map['form_view'];
        if (formView is Map) {
          map.addAll(Map<dynamic, dynamic>.from(formView));
        }
        return map;

      case ApprovalListCategory.pettyCash:
        final formView = map['form_view'];
        if (formView is Map) {
          map.addAll(Map<dynamic, dynamic>.from(formView));
        }
        return map;
    }
  }
}
