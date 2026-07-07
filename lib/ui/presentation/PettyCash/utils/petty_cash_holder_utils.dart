import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:intl/intl.dart';

abstract final class PettyCashHolderUtils {
  static int? resolveHolderId() {
    final loginData = SharedPref.getLoginData();
    final modeledHolderId = loginData.result?.data?.holder_id;
    if (modeledHolderId != null) return modeledHolderId;

    final loginJson = SharedPref.sharedPreferences.getString('loginResponse') ??
        SharedPref.sharedPreferences.getString('LOGIN_RESPONSE');
    if (loginJson == null || loginJson.isEmpty) return null;

    try {
      final decoded = jsonDecode(loginJson) as Map<String, dynamic>;
      final result = decoded['result'];
      if (result is! Map<String, dynamic>) return null;
      final data = result['data'];
      if (data is! Map<String, dynamic>) return null;
      final rawHolderId = data['holder_id'];
      if (rawHolderId is int) return rawHolderId;
      if (rawHolderId is List &&
          rawHolderId.isNotEmpty &&
          rawHolderId.first is int) {
        return rawHolderId.first as int;
      }
      return int.tryParse(rawHolderId?.toString() ?? '');
    } catch (_) {
      return null;
    }
  }

  static String resolveHolderName() {
    final data = SharedPref.getLoginData().result?.data;
    for (final v in [data?.emp_name, data?.name, data?.username]) {
      final s = (v ?? '').toString().trim();
      if (s.isNotEmpty) return s;
    }
    return 'Petty Cash Holder';
  }

  static String formatAed(num value) {
    final fmt = NumberFormat('#,##0.##');
    return 'AED ${fmt.format(value)}';
  }

  static String formatAmount(num value) {
    final fmt = NumberFormat('#,##0.##');
    final amount =
        value % 1 == 0 ? NumberFormat('#,##0').format(value) : fmt.format(value);
    return 'AED $amount';
  }
}
