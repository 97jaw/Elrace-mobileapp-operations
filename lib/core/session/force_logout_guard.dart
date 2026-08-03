import 'dart:async';
import 'dart:convert';

import 'package:el_race/auth/uaepass_auth_cubit.dart';
import 'package:el_race/chat/chat.dart';
import 'package:el_race/core/app_globals.dart';
import 'package:el_race/core/timesheet/providers/timesheet_session_reset.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/data/services/checkin_reminder_notification_service.dart';
import 'package:el_race/data/services/hive_service.dart';
import 'package:el_race/services/api_client.dart';
import 'package:el_race/ui/presentation/attendance_reports/attendance_reports_session.dart';
import 'package:el_race/ui/presentation/home_screen/bloc/home_bloc.dart';
import 'package:el_race/ui/presentation/home_screen/screens/home_screen.dart';
import 'package:el_race/ui/presentation/my_actions/data/user_stamp_assets.dart';
import 'package:el_race/ui/presentation/signin/sign_in_screen.dart';
import 'package:el_race/utils/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;

/// Proactive admin force-logout check (cold start + app resume).
///
/// Backend sets `hr.employee.force_logout`; authenticated APIs then fail with
/// `code: FORCE_LOGOUT`. This guard polls `/api/session/refresh` and presents
/// a blocking dialog with a Re-login action to [SignInScreen].
class ForceLogoutGuard {
  ForceLogoutGuard._();

  static final ForceLogoutGuard instance = ForceLogoutGuard._();

  static const _forceCodes = {'FORCE_LOGOUT', 'SESSION_EXPIRED'};

  bool _inFlight = false;
  bool _dialogVisible = false;
  DateTime? _lastCheckAt;

  /// Skip rapid resume flaps (e.g. notification shade).
  static const _minCheckInterval = Duration(seconds: 8);

  /// Returns `true` when the server reports an admin force-logout.
  Future<bool> isForceLoggedOut() async {
    if (!SharedPref.isUserAuthenticated()) return false;

    final token = SharedPref.getLoginDataOrNull()?.result?.token;
    if (token == null || token.isEmpty) return false;

    try {
      final res = await sl<ApiClient>()
          .post(
            'session/refresh',
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            data: jsonEncode({
              'jsonrpc': '2.0',
              'method': 'call',
              'params': <String, dynamic>{},
            }),
          )
          .timeout(const Duration(seconds: 8));

      final payload = res.data;
      if (payload is! Map) return false;

      final result = payload['result'];
      if (result is! Map) return false;

      if (result['success'] == true) return false;

      final code = (result['code'] ?? '').toString().trim().toUpperCase();
      if (_forceCodes.contains(code)) return true;

      final message = (result['message'] ?? '').toString().toLowerCase();
      return message.contains('forcibly logged out') ||
          message.contains('force logout') ||
          message.contains('administrator');
    } catch (e) {
      debugPrint('[ForceLogoutGuard] check failed: $e');
      return false;
    }
  }

  /// Cold start / resume entry — no-op if not logged in or already handling.
  Future<void> checkOnForeground({bool force = false}) async {
    if (!SharedPref.isUserAuthenticated()) return;
    if (_dialogVisible || _inFlight) return;

    final last = _lastCheckAt;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < _minCheckInterval) {
      return;
    }
    _lastCheckAt = DateTime.now();
    _inFlight = true;
    try {
      final forced = await isForceLoggedOut();
      if (!forced) return;
      await presentForcedLogoutFlow();
    } finally {
      _inFlight = false;
    }
  }

  /// Clears local session, shows the admin dialog, then navigates to sign-in.
  Future<void> presentForcedLogoutFlow({BuildContext? context}) async {
    if (_dialogVisible) return;
    _dialogVisible = true;

    await _clearLocalSession();

    final ctx = context ?? navKey.currentContext;
    if (ctx == null || !ctx.mounted) {
      _goToSignIn();
      _dialogVisible = false;
      return;
    }

    await showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogCtx) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Session Ended',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            content: const Text(
              'Your session was forcibly logged out by the Administrator. '
              'Please sign in again.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogCtx).pop();
                  _goToSignIn();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B387A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Re-login'),
              ),
            ],
          ),
        );
      },
    );

    _dialogVisible = false;
  }

  Future<void> _clearLocalSession() async {
    final root = navKey.currentContext;
    try {
      if (sl.isRegistered<HomeBloc>()) {
        sl<HomeBloc>().add(const ChangeCurrentIndex(index: 1));
      } else if (root != null && root.mounted) {
        root.read<HomeBloc>().add(const ChangeCurrentIndex(index: 1));
      }
    } catch (_) {}

    try {
      if (root != null && root.mounted) {
        final c = ProviderScope.containerOf(root, listen: false);
        resetTimesheetSession(c);
        c.invalidate(attendanceSessionProvider);
      }
    } catch (_) {}

    HomeScreenPage.resetAuthSession();

    try {
      UserStampAssets.clearCache();
    } catch (_) {}
    try {
      await SharedPref().clearPreferences();
    } catch (_) {}
    try {
      await HiveService.setUserLoggedIn(false);
    } catch (_) {}

    unawaited(_backgroundCleanup());
  }

  void _goToSignIn() {
    final nav = navKey.currentState;
    if (nav == null) return;
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (route) => false,
    );
  }

  Future<void> _backgroundCleanup() async {
    try {
      await ChatModuleHelper.instance.cleanup().timeout(
            const Duration(seconds: 5),
          );
    } catch (_) {}
    try {
      if (sl.isRegistered<UaepassAuthCubit>()) {
        await sl<UaepassAuthCubit>().logout().timeout(
              const Duration(seconds: 5),
            );
      }
    } catch (_) {}
    try {
      await CheckInReminderNotificationService().cancelAllReminders();
    } catch (_) {}
  }
}
