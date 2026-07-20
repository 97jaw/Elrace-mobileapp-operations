import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Shown when a non-foreman opens the Timesheet module.
///
/// Timesheet is a foreman-only product (labor hours capture). PM / HR
/// review flows live under the Site Management module instead.
class TimesheetRoleRestrictedScreen extends StatelessWidget {
  const TimesheetRoleRestrictedScreen({
    super.key,
    this.roleLabel,
  });

  /// The user's currently resolved role, shown for support context.
  final String? roleLabel;

  @override
  Widget build(BuildContext context) {
    return TmScaffold(
      glassTitle: 'Timesheet',
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: TimesheetModuleColors.primaryTint,
                borderRadius:
                    BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
              ),
              child: Icon(
                PhosphorIcons.lockKey(),
                color: TimesheetModuleColors.primary,
                size: 42,
              ),
            ),
            const SizedBox(height: TimesheetModuleLayout.sectionGap),
            Text(
              'Access restricted',
              textAlign: TextAlign.center,
              style: TimesheetModuleTypography.display(),
            ),
            const SizedBox(height: 10),
            Text(
              'The Timesheet module is available to foreman accounts only. '
              'Please contact IT to have the correct role assigned to your '
              'account.',
              textAlign: TextAlign.center,
              style: TimesheetModuleTypography.body(),
            ),
            if (roleLabel != null && roleLabel!.isNotEmpty) ...[
              const SizedBox(height: TimesheetModuleLayout.sectionGap),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: TimesheetModuleColors.surface,
                  borderRadius: BorderRadius.circular(
                    TimesheetModuleLayout.cardRadiusSm,
                  ),
                  border: Border.all(color: TimesheetModuleColors.divider),
                ),
                child: Text(
                  'Current role: $roleLabel',
                  style: TimesheetModuleTypography.caption(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
