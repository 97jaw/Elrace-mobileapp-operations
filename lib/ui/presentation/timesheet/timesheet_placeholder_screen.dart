import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_module_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Legacy alias — routes to the Timesheet card entry.
@Deprecated('Use TimesheetModuleHomeScreen')
typedef TimesheetRoleHomeScreen = TimesheetModuleHomeScreen;

class TimesheetPlaceholderScreen extends StatelessWidget {
  const TimesheetPlaceholderScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TmScaffold(
      appBar: AppBar(
        title: Text(title, style: TimesheetModuleTypography.h2()),
        backgroundColor: TimesheetModuleColors.surface,
        foregroundColor: TimesheetModuleColors.text,
        elevation: 0,
      ),
      bottomNavigationBar: TmBottomNavBar(
        items: [
          TmBottomNavItem(label: 'Home', icon: PhosphorIcons.house()),
          TmBottomNavItem(label: 'Tasks', icon: PhosphorIcons.clipboardText()),
        ],
        currentIndex: 0,
        onItemTap: (_) {},
        onFabTap: () {},
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: TimesheetModuleColors.primaryTint,
              borderRadius:
                  BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
            ),
            child: Icon(
              icon,
              color: TimesheetModuleColors.primary,
              size: 34,
            ),
          ),
          const SizedBox(height: TimesheetModuleLayout.sectionGap),
          Text(title, style: TimesheetModuleTypography.display()),
          const SizedBox(height: 8),
          Text(subtitle, style: TimesheetModuleTypography.body()),
          const SizedBox(height: TimesheetModuleLayout.sectionGap),
          const TmProjectCard(
            name: 'Midtown Tower Project',
            taskCountLabel: '8 Tasks',
          ),
          const SizedBox(height: TimesheetModuleLayout.cardSpacing),
          TmTaskRow(
            title: "Site's Inspection",
            subtitle: 'F.6 route placeholder',
            icon: PhosphorIcons.clipboardText(),
            trailing: const TmAvatarStack(labels: ['A', 'B', 'C']),
          ),
        ],
      ),
    );
  }
}
