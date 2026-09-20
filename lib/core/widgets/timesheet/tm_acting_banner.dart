import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/providers/timesheet_acting_session_provider.dart';
import 'package:el_race/core/timesheet/routing/timesheet_route_names.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Persistent "Viewing as <foreman>" bar shown on every Timesheet screen while
/// a PM / HR user is in an acting session.
///
/// Renders nothing for a real foreman login, so the foreman layout is
/// byte-identical to before this feature existed.
class TmActingBanner extends ConsumerWidget {
  const TmActingBanner({super.key});

  /// Clears the session. If the user is deeper than Timesheet home (project
  /// detail, etc.), pops back to that home route so the restricted screen is
  /// shown. When already on Timesheet home, clearing the provider is enough —
  /// [TimesheetModuleHomeScreen] rebuilds to the restricted notice.
  void _exit(BuildContext context, WidgetRef ref) {
    ref.read(tmActingSessionProvider.notifier).exit();
    final navigator = Navigator.of(context);
    final isOnTimesheetHome = ModalRoute.of(context)?.settings.name ==
        TimesheetRouteNames.home;
    if (!isOnTimesheetHome) {
      navigator.popUntil(
        (route) =>
            route.settings.name == TimesheetRouteNames.home || route.isFirst,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(tmActingSessionProvider);
    if (session == null) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.fromLTRB(
          TimesheetModuleLayout.screenPaddingH,
          8,
          TimesheetModuleLayout.screenPaddingH,
          0,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: TimesheetModuleColors.accentTint,
          borderRadius:
              BorderRadius.circular(TimesheetModuleLayout.cardRadiusSm),
          border: Border.all(
            color: TimesheetModuleColors.accent.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(
              PhosphorIcons.eye(PhosphorIconsStyle.fill),
              size: 18,
              color: TimesheetModuleColors.accent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Viewing as ${session.foremanName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TimesheetModuleTypography.caption().copyWith(
                  color: TimesheetModuleColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => _exit(context, ref),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Text(
                  'Exit',
                  style: TimesheetModuleTypography.caption().copyWith(
                    color: TimesheetModuleColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
