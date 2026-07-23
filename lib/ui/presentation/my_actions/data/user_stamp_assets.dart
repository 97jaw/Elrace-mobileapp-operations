import 'dart:convert';
import 'dart:typed_data';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/services/api_client.dart';
import 'package:el_race/ui/presentation/my_actions/data/stamp_authorized_emp_ids.dart';
import 'package:el_race/utils/di.dart';
import 'package:el_race/utils/urll_utils.dart';
import 'package:flutter/foundation.dart';

/// A stamp image option from Odoo `res.users` binaries.
class UserStampOption {
  final String id;
  final String label;
  final Uint8List bytes;

  const UserStampOption({
    required this.id,
    required this.label,
    required this.bytes,
  });
}

/// Stamp authorization + images.
///
/// - Authorization (`isStampUser`): login flag / emp_id allowlist (no binaries).
/// - Images: fetched **on every Apply Stamp** via `POST /api/users/my_stamps`
///   (not on login, not via session/refresh) so Odoo profile updates show immediately.
class UserStampAssets {
  UserStampAssets._();

  static Future<List<UserStampOption>>? _inFlight;

  static const Duration _timeout = Duration(seconds: 12);

  /// True when this device's login is allowed to stamp.
  static bool get isStampUser {
    final data = SharedPref.getLoginData().result?.data;
    if (data?.xStampUser == true) return true;
    if (_rawLoginStampFlag() == true) return true;

    final empId = data?.emp_id?.toString().trim();
    if (empId != null &&
        empId.isNotEmpty &&
        kStampAuthorizedEmpIds.contains(empId)) {
      return true;
    }
    final employeeId = data?.employee_id?.toString().trim();
    if (employeeId != null &&
        employeeId.isNotEmpty &&
        kStampAuthorizedEmpIds.contains(employeeId)) {
      return true;
    }
    return false;
  }

  /// Clears in-flight fetch (call on logout if needed).
  static void clearCache() {
    _inFlight = null;
  }

  /// Fetch stamp images for Apply Stamp (always hits API for latest Odoo files).
  static Future<List<UserStampOption>> fetchStamps({
    bool forceRefresh = true,
  }) async {
    if (!forceRefresh && _inFlight != null) {
      return _inFlight!;
    }

    final future = _fetchFromApi();
    _inFlight = future;
    try {
      return await future.timeout(_timeout);
    } finally {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    }
  }

  static Future<List<UserStampOption>> _fetchFromApi() async {
    final res = await sl<ApiClient>().post(
      UrlUtil.myStamps,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      data: jsonEncode({
        'jsonrpc': '2.0',
        'method': 'call',
        'params': <String, dynamic>{},
      }),
    );

    final payload = res.data;
    if (payload is! Map) {
      throw Exception('Unexpected stamp response');
    }

    final result = payload['result'];
    if (result is! Map) {
      throw Exception('Stamp API returned no result');
    }
    if (result['success'] == false) {
      throw Exception(
        result['error']?.toString() ?? 'Failed to load stamps',
      );
    }

    final data = result['data'] is Map
        ? Map<String, dynamic>.from(result['data'] as Map)
        : Map<String, dynamic>.from(result);

    final out = <UserStampOption>[];

    // Preferred: data.stamps = [{id, label, image|base64}, ...]
    final list = data['stamps'];
    if (list is List) {
      for (final raw in list) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final id = (map['id'] ?? map['key'] ?? 'stamp').toString();
        final bytes = decodeBinary(
          map['image'] ??
              map['base64'] ??
              map['data'] ??
              map['x_signature'] ??
              map['x_sign_english'],
        );
        if (bytes == null) continue;
        out.add(UserStampOption(id: id, label: 'Stamp', bytes: bytes));
      }
    }

    // Flat fields (same names as res.users binaries).
    if (out.isEmpty) {
      final primary = decodeBinary(data['x_signature']);
      if (primary != null) {
        out.add(UserStampOption(
          id: 'x_signature',
          label: 'Stamp',
          bytes: primary,
        ));
      }
      final english = decodeBinary(data['x_sign_english']);
      if (english != null) {
        out.add(UserStampOption(
          id: 'x_sign_english',
          label: 'Stamp',
          bytes: english,
        ));
      }
    }

    // 1 stamp → "Stamp"; 2+ → "Stamp 1", "Stamp 2", ...
    final labeled = <UserStampOption>[];
    for (var i = 0; i < out.length; i++) {
      final label = out.length == 1 ? 'Stamp' : 'Stamp ${i + 1}';
      labeled.add(UserStampOption(
        id: out[i].id,
        label: label,
        bytes: out[i].bytes,
      ));
    }

    if (kDebugMode) {
      debugPrint(
          '✅ UserStampAssets: loaded ${labeled.length} stamp(s) from API');
    }
    return labeled;
  }

  static Uint8List? decodeBinary(dynamic raw) {
    if (raw == null) return null;
    if (raw is! String) {
      final text = raw.toString().trim();
      if (text.isEmpty || text == 'false' || text == 'null') return null;
      return decodeBinary(text);
    }
    var s = raw.trim();
    if (s.isEmpty || s == 'false' || s == 'null' || s == 'None') return null;

    final comma = s.indexOf(',');
    if (s.startsWith('data:') && comma > 0) {
      s = s.substring(comma + 1);
    }

    try {
      return base64Decode(s);
    } catch (_) {
      return null;
    }
  }

  static bool? _rawLoginStampFlag() {
    try {
      final loginJson =
          SharedPref.sharedPreferences.getString('loginResponse') ??
              SharedPref.sharedPreferences.getString('LOGIN_RESPONSE');
      if (loginJson == null || loginJson.isEmpty) return null;
      final decoded = jsonDecode(loginJson);
      if (decoded is! Map) return null;
      final result = decoded['result'];
      final data = (result is Map ? result['data'] : null) ?? decoded['data'];
      if (data is! Map) return null;
      final v = data['x_stamp_user'] ?? data['stamp_user'];
      if (v == null) return null;
      if (v is bool) return v;
      if (v is num) return v != 0;
      final s = v.toString().trim().toLowerCase();
      if (s == 'true' || s == '1' || s == 'yes') return true;
      if (s == 'false' || s == '0' || s == 'no') return false;
      return null;
    } catch (_) {
      return null;
    }
  }
}
