import 'package:el_race/core/app_notices/app_notice.dart';
import 'package:el_race/core/app_notices/app_notice_service.dart';
import 'package:el_race/ui/widgets/app_notice_dialog.dart';
import 'package:flutter/material.dart';

/// When App Notices are shown. Each entry point returns only once the app may
/// continue: maintenance keeps its popup open until it ends (or the logged-in
/// user is on the bypass list).
class AppNoticeGate {
  AppNoticeGate._();

  static final _service = AppNoticeService.instance;
  static bool _signinShown = false;

  /// Splash, before routing to home or sign-in.
  static Future<void> atStartup(
    BuildContext context, {
    required bool isAuthenticated,
  }) async {
    final public = await _service.fetchPublic();
    UserNotices? user;
    if (isAuthenticated) user = await _service.fetchForUser();

    final maintenance = user != null ? user.maintenance : public?.maintenance;
    if (maintenance != null && context.mounted) {
      await _blockWhileMaintenance(
        context,
        maintenance,
        () async {
          final p = await _service.fetchPublic();
          if (p?.maintenance == null) return null;
          if (!isAuthenticated) return p!.maintenance;
          final u = await _service.fetchForUser();
          return u != null ? u.maintenance : p!.maintenance;
        },
      );
    }
    if (user != null && context.mounted) {
      await _showDue(context, user.notices);
    }
  }

  /// ID/password and UAE PASS login, before opening home.
  static Future<void> afterLogin(BuildContext context) async {
    final user = await _service.fetchForUser();
    if (user == null || !context.mounted) return;
    final maintenance = user.maintenance;
    if (maintenance != null) {
      await _blockWhileMaintenance(
        context,
        maintenance,
        () async => (await _service.fetchForUser())?.maintenance,
      );
      if (!context.mounted) return;
    }
    await _showDue(context, user.notices);
  }

  /// Sign-in screen, once per app run.
  static Future<void> atSignIn(BuildContext context) async {
    if (_signinShown) return;
    _signinShown = true;
    final public = await _service.fetchPublic();
    if (public == null || !context.mounted) return;
    await _showDue(context, public.signinNotices);
  }

  static Future<void> _blockWhileMaintenance(
    BuildContext context,
    AppNotice notice,
    Future<AppNotice?> Function() recheck,
  ) {
    return AppNoticeDialog.show(
      context,
      notice,
      onRetry: () async => (await recheck()) == null,
    );
  }

  static Future<void> _showDue(
    BuildContext context,
    List<AppNotice> notices,
  ) async {
    for (final notice in notices) {
      if (!context.mounted) return;
      if (!_service.isDue(notice)) continue;
      await AppNoticeDialog.show(context, notice);
      await _service.markSeen(notice);
    }
  }
}
