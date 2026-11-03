import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Waiting-approvals badge count (HR + RFQ + Invoice + Petty Cash [+ Sign Document]).
///
/// Odoo and Sign Document are cached separately so a live Firestore watcher can
/// update SD without refetching Odoo, and an early "0" before Firebase sign-in
/// cannot permanently wipe a later SD total.
class ApprovalCountService {
  ApprovalCountService._();

  static final Map<Object, VoidCallback> _listeners = {};

  /// -1 means Odoo has not been fetched yet.
  static int _cachedOdooCount = -1;

  static int _signDocumentCount = 0;
  static bool _signDocumentFlagOn = false;

  /// Last known total for instant header paint (0 if Odoo never loaded).
  static int get cachedCountOrZero =>
      _cachedOdooCount < 0 ? _sdPart : (_cachedOdooCount + _sdPart);

  /// Null when Odoo has never been fetched / was invalidated.
  static int? get cachedCount =>
      _cachedOdooCount < 0 ? null : (_cachedOdooCount + _sdPart);

  static int get _sdPart =>
      _signDocumentFlagOn ? (_signDocumentCount < 0 ? 0 : _signDocumentCount) : 0;

  /// Pure sum used by [getTotalApprovalCount] and unit tests.
  static int sumApprovalCounts({
    required int hr,
    required int rfq,
    required int invoice,
    required int pettyCash,
    required bool timesheetApprovalEnabled,
    required int signDocumentCount,
  }) {
    final odoo = hr + rfq + invoice + pettyCash;
    if (!timesheetApprovalEnabled) return odoo;
    final sd = signDocumentCount < 0 ? 0 : signDocumentCount;
    return odoo + sd;
  }

  /// Total from separately cached Odoo + SD parts (for tests / callers).
  static int combineCachedParts({
    required int odooCount,
    required bool timesheetApprovalEnabled,
    required int signDocumentCount,
  }) {
    final odoo = odooCount < 0 ? 0 : odooCount;
    if (!timesheetApprovalEnabled) return odoo;
    final sd = signDocumentCount < 0 ? 0 : signDocumentCount;
    return odoo + sd;
  }

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

  /// Called by the Approval screen with the **Odoo** waiting total only.
  static void updateCachedCount(int odooCount) {
    final next = odooCount < 0 ? 0 : odooCount;
    final changed = _cachedOdooCount != next;
    _cachedOdooCount = next;
    if (changed) {
      notifyListeners();
    }
  }

  /// Live Sign Document pending count from Firestore (does not touch Odoo).
  static void updateSignDocumentCount(int count, {bool flagOn = true}) {
    final next = count < 0 ? 0 : count;
    final changed =
        _signDocumentCount != next || _signDocumentFlagOn != flagOn;
    _signDocumentCount = next;
    _signDocumentFlagOn = flagOn;
    if (changed) {
      notifyListeners();
    }
  }

  static void clearSignDocumentPart() {
    updateSignDocumentCount(0, flagOn: false);
  }

  /// Invalidates the Odoo cache only; SD stays until the watcher clears it.
  static void invalidateCache() {
    _cachedOdooCount = -1;
  }

  static Future<int> getTotalApprovalCount() async {
    if (_cachedOdooCount >= 0) {
      return _cachedOdooCount + _sdPart;
    }
    try {
      final token = SharedPref.getLoginData().result?.token;
      if (token == null || token.isEmpty) {
        return _sdPart;
      }

      final results = await Future.wait([
        _fetchCategoryCount('hr', token),
        _fetchCategoryCount('rfq', token),
        _fetchCategoryCount('invoice', token),
        _fetchCategoryCount('petty_cash', token),
      ]);

      final odoo = results.reduce((a, b) => a + b);
      _cachedOdooCount = odoo;
      // Sign Document comes from TimesheetBadgeWatcher (live), not a one-shot.
      return odoo + _sdPart;
    } catch (e) {
      debugPrint('ApprovalCountService.getTotalApprovalCount failed: $e');
      return _cachedOdooCount >= 0 ? _cachedOdooCount + _sdPart : _sdPart;
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
