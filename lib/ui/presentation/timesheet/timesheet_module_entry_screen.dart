import 'package:el_race/core/timesheet/providers/timesheet_role_provider.dart';
import 'package:el_race/core/timesheet/routing/timesheet_route_names.dart';
import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class TimesheetModuleEntryScreen extends ConsumerWidget {
  const TimesheetModuleEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolution = ref.watch(tmRoleResolutionProvider);
    final roleLabel =
        resolution.hrWideScope ? 'HR-wide PM' : resolution.role.label;

    return TmScaffold(
      glassTitle: 'Project Site Timesheet',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TmGreetingHeader(name: 'Timesheet Team'),
          const SizedBox(height: TimesheetModuleLayout.sectionGap),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: TimesheetModuleColors.navyTint,
              borderRadius:
                  BorderRadius.circular(TimesheetModuleLayout.cardRadiusSm),
            ),
            child: Text(
              'Current role: $roleLabel',
              style: TimesheetModuleTypography.caption().copyWith(
                color: TimesheetModuleColors.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: TimesheetModuleLayout.cardSpacing),
          const TmProjectCard(
            name: 'Module 6 Foundation',
            taskCountLabel: 'F.0-F.2',
          ),
          const SizedBox(height: TimesheetModuleLayout.sectionGap),
          TmPrimaryButton(
            label: 'Open Role Home',
            icon: PhosphorIcons.house(),
            onPressed: () {
              Navigator.of(context).pushReplacementNamed(
                TimesheetRouteNames.home,
              );
            },
          ),
          const SizedBox(height: TimesheetModuleLayout.cardSpacing),
          TmPrimaryButton(
            label: 'Open Widget Sandbox',
            icon: PhosphorIcons.gridFour(),
            onPressed: kDebugMode
                ? () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TimesheetWidgetsSandbox(),
                      ),
                    );
                  }
                : null,
          ),
          const SizedBox(height: TimesheetModuleLayout.cardSpacing),
          Text(
            'Role-aware routing and dashboards are scheduled for F.5-F.6.',
            style: TimesheetModuleTypography.caption(),
          ),
        ],
      ),
    );
  }
}
