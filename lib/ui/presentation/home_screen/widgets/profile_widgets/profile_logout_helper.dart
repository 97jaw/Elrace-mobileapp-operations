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
import 'package:el_race/ui/presentation/signin/sign_in_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_translate/flutter_translate.dart';

class ProfileLogoutHelper {
  ProfileLogoutHelper._();

  static Future<void> confirmAndLogout(BuildContext context) async {
    final dialogContext = navKey.currentContext ?? context;

    final shouldLogout = await showDialog<bool>(
      context: dialogContext,
      barrierDismissible: false,
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

    final loadingContext = navKey.currentContext ?? context;
    showDialog(
      context: loadingContext,
      barrierDismissible: false,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xffBA1719)),
        ),
      ),
    );

    try {
      try {
        await ChatModuleHelper.instance.cleanup().timeout(
              const Duration(seconds: 5),
            );
      } catch (_) {}

      try {
        await context.read<UaepassAuthCubit>().logout().timeout(
              const Duration(seconds: 5),
            );
      } catch (_) {}

      try {
        await CheckInReminderNotificationService().cancelAllReminders();
      } catch (_) {}

      await SharedPref().clearPreferences();
      await HiveService.setUserLoggedIn(false);
    } catch (_) {
    } finally {
      try {
        context.read<HomeBloc>().add(const ChangeCurrentIndex(index: 1));
      } catch (_) {}

      try {
        final c = ProviderScope.containerOf(context, listen: false);
        resetTimesheetSession(c);
        c.invalidate(attendanceSessionProvider);
      } catch (_) {}

      HomeScreenPage.resetAuthSession();

      final navContext = navKey.currentContext ?? context;
      Navigator.pushAndRemoveUntil(
        navContext,
        MaterialPageRoute(builder: (context) => const SignInScreen()),
        (route) => false,
      );
    }
  }
}
