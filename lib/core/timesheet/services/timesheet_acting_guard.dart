import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/providers/timesheet_acting_session_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Refuses every Timesheet write while a PM / HR user is acting as a foreman.
///
/// `/api/timesheet/submit` records no submitter on `account.analytic.line`, so
/// an impersonated submit would be indistinguishable from a genuine on-site
/// capture. Reads follow the acted-as foreman; writes need a real login.
abstract final class TimesheetActingGuard {
  /// Returns `true` when the caller must abort because an acting session is
  /// in progress. Shows the explanatory notice as a side effect.
  ///
  /// [action] is used in the message, e.g. `'Submitting attendance'`.
  static bool blockWrite(
    BuildContext context,
    WidgetRef ref, {
    String action = 'This action',
  }) {
    final session = ref.read(tmActingSessionProvider);
    if (session == null) return false;
    showNotice(context, session, action: action);
    return true;
  }

  /// Same check without a `WidgetRef`, for callbacks that only hold a context.
  static bool blockWriteWithoutRef(
    BuildContext context, {
    String action = 'This action',
  }) {
    final session = TimesheetActingScope.current;
    if (session == null) return false;
    showNotice(context, session, action: action);
    return true;
  }

  static Future<void> showNotice(
    BuildContext context,
    TimesheetActingSession session, {
    String action = 'This action',
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: TimesheetModuleColors.warmGradientStart,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
        ),
        title: Row(
          children: [
            Icon(
              PhosphorIcons.lockKey(),
              color: TimesheetModuleColors.accent,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Foreman login required',
                style: TimesheetModuleTypography.cardTitle().copyWith(
                  color: TimesheetModuleColors.ink,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'You are viewing Timesheet as ${session.foremanName}. '
          '$action needs a real login for this foreman.',
          style: TimesheetModuleTypography.body().copyWith(
            color: TimesheetModuleColors.warmMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Got it',
              style: TextStyle(
                color: TimesheetModuleColors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
