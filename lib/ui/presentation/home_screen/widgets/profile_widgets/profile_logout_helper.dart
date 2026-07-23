import 'dart:async';

import 'package:el_race/auth/uaepass_auth_cubit.dart';
import 'package:el_race/chat/chat.dart';
import 'package:el_race/core/app_globals.dart';
import 'package:el_race/core/timesheet/providers/timesheet_session_reset.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/data/services/checkin_reminder_notification_service.dart';
import 'package:el_race/data/services/hive_service.dart';
import 'package:el_race/ui/presentation/attendance_reports/attendance_reports_session.dart';
import 'package:el_race/ui/presentation/home_screen/bloc/home_bloc.dart';
import 'package:el_race/ui/presentation/home_screen/screens/home_screen.dart';
import 'package:el_race/ui/presentation/my_actions/data/user_stamp_assets.dart';
import 'package:el_race/ui/presentation/signin/sign_in_screen.dart';
import 'package:el_race/utils/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_translate/flutter_translate.dart';

class ProfileLogoutHelper {
  ProfileLogoutHelper._();

  static BuildContext? _rootContext(BuildContext context) {
    return navKey.currentContext ?? context;
  }

  static Future<void> confirmAndLogout(BuildContext context) async {
    final root = _rootContext(context);
    if (root == null || !root.mounted) return;

    final shouldLogout = await showDialog<bool>(
      context: root,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: Text(
          translate('profile.logout_confirmation_title'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(translate('profile.logout_confirmation_message')),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              translate('common.cancel'),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xffBA1719),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              translate('profile.logout'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    final nav = navKey.currentState;
    if (nav == null) return;

    // 1) Reset in-memory session state before navigating away.
    try {
      sl<HomeBloc>().add(const ChangeCurrentIndex(index: 1));
    } catch (_) {
      try {
        root.read<HomeBloc>().add(const ChangeCurrentIndex(index: 1));
      } catch (_) {}
    }
    try {
      final c = ProviderScope.containerOf(root, listen: false);
      resetTimesheetSession(c);
      c.invalidate(attendanceSessionProvider);
    } catch (_) {}
    HomeScreenPage.resetAuthSession();

    // 2) Navigate to sign-in IMMEDIATELY. This disposes the home widget tree
    //    (and its Firestore listeners) BEFORE Firebase signs out, which avoids
    //    the post-signout `permission-denied` churn that previously froze
    //    logout on a loading spinner. Logout is now instant — no blocking
    //    dialog.
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (route) => false,
    );

    // 3) Persist the logged-out state.
    try {
      UserStampAssets.clearCache();
    } catch (_) {}
    try {
      await SharedPref().clearPreferences();
    } catch (_) {}
    try {
      await HiveService.setUserLoggedIn(false);
    } catch (_) {}

    // 4) Heavy teardown runs in the background so it can never block the UI.
    unawaited(_backgroundLogoutCleanup());
  }

  /// Best-effort teardown that must never block navigation to the sign-in
  /// screen. Runs after the user is already on the sign-in screen.
  static Future<void> _backgroundLogoutCleanup() async {
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
