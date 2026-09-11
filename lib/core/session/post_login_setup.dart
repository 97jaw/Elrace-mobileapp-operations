import 'dart:convert';

import 'package:el_race/chat/chat.dart';
import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/services/attendance_status_sync_service.dart';
import 'package:el_race/core/services/mobile_device_id_service.dart';
import 'package:el_race/core/timesheet/providers/timesheet_session_reset.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/data/services/hive_service.dart';
import 'package:el_race/firebase_service.dart';
import 'package:el_race/ui/presentation/attendance_reports/attendance_reports_session.dart';
import 'package:el_race/ui/presentation/home_screen/bloc/home_bloc.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:el_race/ui/presentation/signin/data/repository.dart';
import 'package:el_race/utils/Util.dart';
import 'package:el_race/utils/api_query.dart';
import 'package:el_race/utils/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared post-login steps for email/password and UAE PASS — must stay in sync.
class PostLoginSetup {
  PostLoginSetup._();

  /// Persist the **raw** Odoo jsonrpc login payload (same as email login).
  /// Re-serializing through [LoginResponseModel.toJson] drops widget flags.
  static Future<LoginResponseModel?> persistLoginResponse(
    Map<String, dynamic> rawJsonRpc, {
    String? deviceId,
  }) async {
    final normalized = normalizeLoginPayload(unwrapRawResponse(rawJsonRpc));
    final loginResponse = LoginResponseModel.fromJson(normalized);

    await SharedPref().setPreferencesString(
      'loginResponse',
      jsonEncode(normalized),
    );
    await SharedPref().setPreferencesBoolean('isRegistered', true);
    await HiveService.setUserLoggedIn(true);

    if (sl.isRegistered<UserRepo>()) {
      await sl<UserRepo>().setLoginResponse(loginResponse, rawJson: normalized);
      final resolvedDeviceId =
          deviceId ?? await MobileDeviceIdService.getOrCreate();
      await sl<UserRepo>().setDeviceInfo(resolvedDeviceId);
      await sl<UserRepo>().setISLoggedIn(true);
    }

    try {
      await FirebaseService.ensureFCMToken();
      await FirebaseService.syncFcmTokenToOdoo(force: true);
    } catch (_) {}

    ChatModuleHelper.instance
        .initializeFromLoginResponse(normalized)
        .catchError((_) {});

    return loginResponse;
  }

  /// Run UI/session side effects after login (widgets, attendance, home data).
  static Future<void> applyAfterLogin(BuildContext context) async {
    try {
      ProviderScope.containerOf(context, listen: false)
          .read(hrDevViewOverrideProvider.notifier)
          .setOverride(null);
    } catch (_) {}

    try {
      context.read<HomeBloc>().add(const ChangeCurrentIndex(index: 1));
    } catch (_) {}

    try {
      final c = ProviderScope.containerOf(context, listen: false);
      resetTimesheetSession(c);
      c.invalidate(attendanceSessionProvider);
    } catch (_) {}

    Util.fetchHomeScreenData(context);
    AttendanceStatusSyncService.refreshFromServer(reason: 'login')
        .catchError((_) => null);
  }

  /// Ensure UAE PASS / email payloads share the jsonrpc shape home widgets expect.
  static Map<String, dynamic> normalizeLoginPayload(
    Map<String, dynamic> raw,
  ) {
    var map = Map<String, dynamic>.from(raw);

    // Some endpoints return the login body directly instead of jsonrpc-wrapped.
    if (!map.containsKey('result') &&
        (map.containsKey('success') ||
            map.containsKey('token') ||
            map.containsKey('data'))) {
      map = {
        'jsonrpc': '2.0',
        'id': null,
        'result': Map<String, dynamic>.from(map),
      };
    }

    final result = map['result'];
    if (result is! Map) return map;

    final resultMap = Map<String, dynamic>.from(result);
    final userId = _coalesceId(
      resultMap['user_id'],
      resultMap['uid'],
    );

    var dataRaw = resultMap['data'];
    if (dataRaw is String && dataRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(dataRaw);
        if (decoded is Map) dataRaw = decoded;
      } catch (_) {}
    }
    if (dataRaw is! Map) {
      dataRaw = <String, dynamic>{};
    }
    final dataMap = Map<String, dynamic>.from(dataRaw);

    if (userId != null) {
      if (_isBlankId(dataMap['uid'])) dataMap['uid'] = userId;
      if (_isBlankId(dataMap['odoo_user_id'])) dataMap['odoo_user_id'] = userId;
      if (_isBlankId(dataMap['user_id'])) dataMap['user_id'] = userId;
      if (_isBlankId(dataMap['firebase_uid'])) {
        dataMap['firebase_uid'] = 'odoo_$userId';
      }
      if (dataMap['employee_configured'] != true &&
          (dataMap['emp_name'] != null &&
              dataMap['emp_name'].toString().trim().isNotEmpty)) {
        dataMap['employee_configured'] = true;
      }
    }

    if (_isBlankId(resultMap['token'])) {
      final tokenFromData = dataMap['token'];
      if (tokenFromData != null && tokenFromData.toString().isNotEmpty) {
        resultMap['token'] = tokenFromData;
      }
    }

    resultMap['data'] = dataMap;
    map['result'] = resultMap;
    return map;
  }

  /// Unwrap Odoo jsonrpc bodies to the inner `result` object when present.
  static Map<String, dynamic> unwrapRawResponse(Map<String, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);
    final result = map['result'];
    if (result is Map) {
      final inner = Map<String, dynamic>.from(result);
      if (inner.containsKey('success') ||
          inner.containsKey('token') ||
          inner.containsKey('data') ||
          inner.containsKey('firebase_custom_token') ||
          inner.containsKey('error_code')) {
        return inner;
      }
    }
    return map;
  }

  /// True when login `result.data` has employee profile + widgets.
  static bool hasCompleteLoginData(Map<String, dynamic> jsonRpc) {
    final normalized = normalizeLoginPayload(jsonRpc);
    final result = normalized['result'];
    if (result is! Map) return false;
    final data = result['data'];
    if (data is! Map) return false;

    final userId = _coalesceId(
      data['odoo_user_id'],
      data['uid'],
      result['user_id'],
    );
    if (userId == null) return false;

    if (data['employee_configured'] == true) return true;

    final widgets = data['default_widgets'];
    if (widgets is Map) {
      final widgetData = widgets['data'];
      if (widgetData is Map && widgetData.isNotEmpty) return true;
    }

    return false;
  }

  /// Firebase-only hydrate — do not call session/refresh during login
  /// (that re-runs widget builders and can hit concurrent DB updates).
  static Future<Map<String, dynamic>?> hydrateLoginFromToken(
    Map<String, dynamic> jsonRpc,
  ) async {
    final normalized = normalizeLoginPayload(jsonRpc);
    final result = normalized['result'];
    if (result is! Map) return null;

    final token = result['token']?.toString();
    if (token == null || token.isEmpty) return null;

    final dataRaw = result['data'];
    final dataMap = dataRaw is Map
        ? Map<String, dynamic>.from(dataRaw)
        : <String, dynamic>{};

    final existingFb = dataMap['firebase_custom_token']?.toString();
    if (existingFb != null && existingFb.isNotEmpty) return null;

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final apiQuery = ApiQuery();
    const emptyParams = {'jsonrpc': '2.0', 'params': {}};

    String? firebaseToken;
    try {
      final fbResp = await apiQuery.postQuery(
        'firebase/refresh_token',
        headers,
        emptyParams,
        'firebase_refresh',
        true,
      );
      final raw = fbResp?.data;
      if (raw is Map) {
        final unwrapped = unwrapRawResponse(Map<String, dynamic>.from(raw));
        firebaseToken = unwrapped['firebase_custom_token']?.toString();
      }
    } catch (_) {}

    if (firebaseToken == null || firebaseToken.isEmpty) return null;

    dataMap['firebase_custom_token'] = firebaseToken;
    final uid = _coalesceId(
      dataMap['odoo_user_id'],
      dataMap['uid'],
      result['user_id'],
    );
    if (uid != null && _isBlankId(dataMap['firebase_uid'])) {
      dataMap['firebase_uid'] = 'odoo_$uid';
    }

    final resultMap = Map<String, dynamic>.from(result);
    resultMap['data'] = dataMap;
    normalized['result'] = resultMap;
    return normalized;
  }

  static bool _isBlankId(dynamic value) {
    if (value == null || value == false) return true;
    if (value is String && value.trim().isEmpty) return true;
    if (value is num && value == 0) return true;
    return false;
  }

  static int? _coalesceId(dynamic a, dynamic b, [dynamic c]) {
    if (!_isBlankId(a)) {
      if (a is int) return a;
      return int.tryParse(a.toString());
    }
    if (!_isBlankId(b)) {
      if (b is int) return b;
      return int.tryParse(b.toString());
    }
    if (!_isBlankId(c)) {
      if (c is int) return c;
      return int.tryParse(c.toString());
    }
    return null;
  }

}
