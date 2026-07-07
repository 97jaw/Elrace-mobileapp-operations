import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/core/timesheet/routing/timesheet_route_names.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class TimesheetMenuTile extends StatelessWidget {
  const TimesheetMenuTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: TimesheetModuleColors.surface,
          borderRadius:
              BorderRadius.circular(TimesheetModuleLayout.cardRadiusLg),
          border: Border.all(color: TimesheetModuleColors.divider),
          boxShadow: TimesheetModuleShadows.cardShadow,
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius:
                  BorderRadius.circular(TimesheetModuleLayout.cardRadiusLg),
              onTap: () {
                Navigator.of(context).pushNamed(TimesheetRouteNames.home);
              },
              child: Padding(
                padding:
                    const EdgeInsets.all(TimesheetModuleLayout.cardPadding),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: TimesheetModuleColors.primaryTint,
                        borderRadius: BorderRadius.circular(
                          TimesheetModuleLayout.cardRadiusSm,
                        ),
                      ),
                      child: Icon(
                        PhosphorIcons.hardHat(),
                        color: TimesheetModuleColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Project Site Timesheet',
                            style: TimesheetModuleTypography.cardTitle(),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Site attendance, tasks, photos, reports',
                            style: TimesheetModuleTypography.caption(),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      PhosphorIcons.caretRight(),
                      color: TimesheetModuleColors.mutedText,
                    ),
                  ],
                ),
              ),
            ),
            if (kDebugMode) ...[
              const Divider(height: 1, color: TimesheetModuleColors.divider),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TimesheetWidgetsSandbox(),
                    ),
                  );
                },
                icon: Icon(PhosphorIcons.gridFour(), size: 18),
                label: const Text('F.2 widget sandbox'),
                style: TextButton.styleFrom(
                  foregroundColor: TimesheetModuleColors.primary,
                  textStyle: TimesheetModuleTypography.button(
                    color: TimesheetModuleColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
