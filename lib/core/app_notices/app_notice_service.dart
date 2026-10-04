import 'package:dio/dio.dart';
import 'package:el_race/core/app_notices/app_notice.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/utils/urll_utils.dart';
import 'package:flutter/foundation.dart';

class PublicNotices {
  const PublicNotices({this.maintenance, this.signinNotices = const []});

  final AppNotice? maintenance;
  final List<AppNotice> signinNotices;
}

class UserNotices {
  const UserNotices({this.maintenance, this.notices = const []});

  final AppNotice? maintenance;
  final List<AppNotice> notices;
}

/// Loads App Notices from Odoo. Every call fails open (returns null / empty)
/// so a network or server problem never locks users out.
class AppNoticeService {
  AppNoticeService._();

  static final AppNoticeService instance = AppNoticeService._();

  static const _seenPrefix = 'app_notice_seen_';

  Dio _dio() => Dio(BaseOptions(
        baseUrl: UrlUtil.baseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: {'Content-Type': 'application/json'},
      ));

  Map<String, dynamic>? _result(dynamic data) {
    if (data is! Map) return null;
    final result = data['result'];
    if (result is Map) return Map<String, dynamic>.from(result);
    return null;
  }

  /// Before login: live maintenance and sign-in notices.
  Future<PublicNotices?> fetchPublic() async {
    try {
      final resp = await _dio().get(
        'app/config',
        data: {'jsonrpc': '2.0', 'params': {}},
      );
      final result = _result(resp.data);
      if (result == null) return null;
      return PublicNotices(
        maintenance: AppNotice.tryParse(result['maintenance']),
        signinNotices: AppNotice.parseList(result['signin_notices']),
      );
    } catch (e) {
      debugPrint('app notices: public fetch failed (ignored): $e');
      return null;
    }
  }

  /// After login: maintenance unless this user may bypass it, plus notices
  /// for this user. Null when there is no session or the call failed.
  Future<UserNotices?> fetchForUser() async {
    final token = SharedPref.getLoginDataOrNull()?.result?.token;
    if (token == null || token.isEmpty) return null;
    try {
      final resp = await _dio().post(
        'app/notices',
        data: {'jsonrpc': '2.0', 'params': {}},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final result = _result(resp.data);
      if (result == null || result['success'] != true) return null;
      return UserNotices(
        maintenance: AppNotice.tryParse(result['maintenance']),
        notices: AppNotice.parseList(result['notices']),
      );
    } catch (e) {
      debugPrint('app notices: user fetch failed (ignored): $e');
      return null;
    }
  }

  bool isDue(AppNotice notice) {
    if (notice.isMaintenance || notice.frequency == 'every_time') return true;
    final seen = SharedPref().getPreferenceString('$_seenPrefix${notice.id}');
    if (seen.isEmpty) return true;
    final parts = seen.split('|');
    final seenRevision = parts.first;
    final seenDay = parts.length > 1 ? parts[1] : '';
    if (seenRevision != notice.revision) return true;
    if (notice.frequency == 'daily') return seenDay != _today();
    return false;
  }

  Future<void> markSeen(AppNotice notice) => SharedPref().setPreferencesString(
        '$_seenPrefix${notice.id}',
        '${notice.revision}|${_today()}',
      );

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }
}
