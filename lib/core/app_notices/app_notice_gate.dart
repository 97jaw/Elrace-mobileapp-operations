import 'package:el_race/core/app_globals.dart';
import 'package:el_race/core/app_notices/app_notice.dart';
import 'package:el_race/core/app_notices/app_notice_service.dart';
import 'package:el_race/core/services/android_play_update_service.dart';
import 'package:el_race/core/services/update_service.dart';
import 'package:el_race/core/session/force_logout_guard.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/widgets/app_notice_dialog.dart';
import 'package:el_race/ui/widgets/update_dialog.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// When App Notices are shown. Each entry point returns only once the app may
/// continue: maintenance keeps its popup open until it ends (or the logged-in
/// user is on the bypass list). A maintenance notice with "Log Users Out"
/// signs the user out first.
class AppNoticeGate {
  AppNoticeGate._();

  static final _service = AppNoticeService.instance;
  static bool _signinShown = false;

  /// Set once splash hands off; resume checks never race the splash gates.
  static bool _appReady = false;
  static bool _resumeBusy = false;
  static DateTime? _lastResumeCheck;

  /// Ignores quick flaps (notification shade, permission and picker sheets).
  static const _resumeInterval = Duration(minutes: 1);

  static void markAppReady() => _appReady = true;

  /// Splash, before routing to home or sign-in. A forced maintenance logout
  /// leaves the user signed out, so splash routes to sign-in.
  static Future<void> atStartup(
    BuildContext context, {
    required bool isAuthenticated,
  }) async {
    final public = await _service.fetchPublic();
    UserNotices? user;
    if (isAuthenticated) user = await _service.fetchForUser();

    final maintenance = user != null ? user.maintenance : public?.maintenance;
    if (maintenance != null && context.mounted) {
      final stillSignedIn = await _handleMaintenance(
        context,
        maintenance,
        signedIn: user != null,
      );
      if (!stillSignedIn) return;
    }
    if (user != null && context.mounted) {
      await _showDue(context, user.notices);
    }
  }

  /// ID/password and UAE PASS login, before opening home. Returns false when
  /// maintenance signed the user out; the gate has already opened sign-in.
  static Future<bool> afterLogin(BuildContext context) async {
    final user = await _service.fetchForUser();
    if (user == null || !context.mounted) return true;
    final maintenance = user.maintenance;
    if (maintenance != null) {
      final stillSignedIn = await _handleMaintenance(
        context,
        maintenance,
        signedIn: true,
      );
      if (!stillSignedIn) {
        ForceLogoutGuard.instance.goToSignIn();
        return false;
      }
      if (!context.mounted) return false;
    }
    await _showDue(context, user.notices);
    return true;
  }

  /// Sign-in screen, once per app run.
  static Future<void> atSignIn(BuildContext context) async {
    if (_signinShown) return;
    _signinShown = true;
    final public = await _service.fetchPublic();
    if (public == null || !context.mounted) return;
    await _showDue(context, public.signinNotices);
  }

  /// App back in the foreground: app update first, then maintenance.
  /// Login notices are not repeated here.
  static Future<void> onResume() async {
    if (!_appReady || _resumeBusy) return;
    final last = _lastResumeCheck;
    if (last != null && DateTime.now().difference(last) < _resumeInterval) {
      return;
    }
    _lastResumeCheck = DateTime.now();
    _resumeBusy = true;
    try {
      if (!await _checkUpdate()) return;

      final signedIn = SharedPref.isUserAuthenticated();
      final maintenance = signedIn
          ? (await _service.fetchForUser())?.maintenance
          : (await _service.fetchPublic())?.maintenance;
      final context = navKey.currentContext;
      if (maintenance == null || context == null || !context.mounted) return;

      final stillSignedIn = await _handleMaintenance(
        context,
        maintenance,
        signedIn: signedIn,
      );
      if (signedIn && !stillSignedIn) ForceLogoutGuard.instance.goToSignIn();
    } catch (e) {
      debugPrint('app notices: resume check failed (ignored): $e');
    } finally {
      _resumeBusy = false;
    }
  }

  /// False while a forced update keeps the app blocked.
  static Future<bool> _checkUpdate() async {
    final info = await PackageInfo.fromPlatform();
    final result = await UpdateService.instance.checkForUpdate(info.version);
    if (!result.forceUpdate && !result.optionalUpdate) return true;

    if (await AndroidPlayUpdateService.instance
        .startImmediateUpdateIfAvailable()) {
      return false;
    }
    final context = navKey.currentContext;
    if (context == null || !context.mounted) return true;
    final blocked = await UpdateDialog.showIfNeeded(
      context,
      result,
      isRtl: Directionality.of(context) == TextDirection.rtl,
    );
    return !blocked;
  }

  /// Blocks until maintenance ends. Returns false when the user was signed in
  /// and the notice signed them out.
  static Future<bool> _handleMaintenance(
    BuildContext context,
    AppNotice notice, {
    required bool signedIn,
  }) async {
    final logout = signedIn && notice.forceLogout;
    if (logout) await ForceLogoutGuard.instance.signOutLocally();
    if (!context.mounted) return !logout;

    await AppNoticeDialog.show(
      context,
      notice,
      onRetry: () async {
        if (signedIn && !logout) {
          final user = await _service.fetchForUser();
          if (user != null) return user.maintenance == null;
        }
        return (await _service.fetchPublic())?.maintenance == null;
      },
    );
    return !logout;
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
