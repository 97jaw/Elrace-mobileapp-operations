import 'dart:convert';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Waiting-approvals badge count (HR + RFQ + Invoice + Petty Cash pending).
///
/// Strategy:
/// - Badge = total pending waiting items (not “unviewed”).
/// - Warm cache is the source of truth between screens.
/// - Multiple headers may listen; do **not** invalidate on every header mount.
class ApprovalCountService {
  ApprovalCountService._();

  static final Map<Object, VoidCallback> _listeners = {};

  /// -1 means no cache yet (will fetch from API).
  static int _cachedCount = -1;

  /// Last known count for instant header paint (0 if never loaded).
  static int get cachedCountOrZero => _cachedCount < 0 ? 0 : _cachedCount;

  /// Null when never fetched / invalidated.
  static int? get cachedCount => _cachedCount < 0 ? null : _cachedCount;

  static void addListener(Object key, VoidCallback callback) {
    _listeners[key] = callback;
  }

  static void removeListener(Object key) {
    _listeners.remove(key);
  }

  static void notifyListeners() {
    for (final callback in List.of(_listeners.values)) {
      try {
        callback();
      } catch (e) {
        debugPrint('ApprovalCountService listener failed: $e');
      }
    }
  }

  /// Called by the Approval screen after it has loaded real list data.
  static void updateCachedCount(int count) {
    final next = count < 0 ? 0 : count;
    final changed = _cachedCount != next;
    _cachedCount = next;
    if (changed) {
      notifyListeners();
    }
  }

  /// Call on logout, resume refresh, or after approve/reject before refetch.
  static void invalidateCache() {
    _cachedCount = -1;
  }

  static Future<int> getTotalApprovalCount() async {
    if (_cachedCount >= 0) {
      return _cachedCount;
    }
    try {
      final token = SharedPref.getLoginData().result?.token;
      if (token == null || token.isEmpty) {
        return 0;
      }

      final results = await Future.wait([
        _fetchCategoryCount('hr', token),
        _fetchCategoryCount('rfq', token),
        _fetchCategoryCount('invoice', token),
        _fetchCategoryCount('petty_cash', token),
      ]);

      final totalCount = results.reduce((a, b) => a + b);
      _cachedCount = totalCount;
      return totalCount;
    } catch (e) {
      debugPrint('ApprovalCountService.getTotalApprovalCount failed: $e');
      return 0;
    }
  }

  static Future<int> _fetchCategoryCount(String category, String token) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final url = Uri.parse('https://erp.elrace.com/api/my_approvals_grouped');

      final body = jsonEncode({
        'jsonrpc': '2.0',
        'params': {
          'group_type': category,
        },
      });

      final request = http.Request('GET', url)
        ..headers.addAll(headers)
        ..body = body;

      final response = await request.send().timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final Map<String, dynamic> jsonData = json.decode(responseBody);
        final result = jsonData['result'];

        if (result != null && result['data'] != null) {
          const Map<String, String> responseKeys = {
            'hr': 'human_resources',
            'rfq': 'rfq',
            'invoice': 'invoices',
            'petty_cash': 'petty_cash',
          };

          final actualKey = responseKeys[category] ?? category;
          final data = result['data'][actualKey];

          if (data is List) {
            return data.length;
          }
        }
      }
      return 0;
    } catch (e) {
      debugPrint('ApprovalCountService._fetchCategoryCount($category): $e');
      return 0;
    }
  }
}
