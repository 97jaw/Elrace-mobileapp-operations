import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_team_member.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/core/timesheet/providers/timesheet_entry_mode_provider.dart';
import 'package:el_race/core/timesheet/routing/timesheet_route_names.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/project_record_card.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_route_args.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/tm_site_reports_list_screen.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_team_members_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class Pm2ProjectDetail extends ConsumerWidget {
  const Pm2ProjectDetail({
    super.key,
    required this.projectId,
  });

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(timesheetProjectProvider(projectId));
    final entryMode = ref.watch(timesheetEntryModeProvider);
    final siteMode = entryMode == TimesheetEntryMode.siteManagement;

    return TmScaffold(
      padding: EdgeInsets.zero,
      appBar: AppBar(
        title: Text('Project Detail', style: TimesheetModuleTypography.h2()),
        backgroundColor: TimesheetModuleColors.surface,
        foregroundColor: TimesheetModuleColors.text,
        elevation: 0,
      ),
      bottomNavigationBar: _ProjectActionsBar(
        projectId: projectId,
        items: siteMode
            ? [
                _ProjectAction(
                  label: 'Live',
                  icon: PhosphorIcons.mapTrifold(),
                  routeName: TimesheetRouteNames.liveMap,
                ),
                _ProjectAction(
                  label: 'Submissions',
                  icon: PhosphorIcons.clipboardText(),
                  routeName: TimesheetRouteNames.pmTimesheetReport,
                ),
              ]
            : [
                _ProjectAction(
                  label: 'Timesheets',
                  icon: PhosphorIcons.clipboardText(),
                  routeName: TimesheetRouteNames.pmTimesheetReport,
                ),
                _ProjectAction(
                  label: 'Live',
                  icon: PhosphorIcons.mapTrifold(),
                  routeName: TimesheetRouteNames.liveMap,
                ),
              ],
      ),
      body: projectAsync.when(
        loading: () => const TimesheetLoadingState(
          style: TimesheetLoadingStyle.list,
          itemCount: 4,
        ),
        error: (_, __) => const TimesheetErrorState(
          message: 'Could not load project detail',
        ),
        data: (project) => DefaultTabController(
          length: 3,
          child: Column(
            children: [
              Container(
                color: TimesheetModuleColors.surface,
                child: const TabBar(
                  labelColor: TimesheetModuleColors.primary,
                  unselectedLabelColor: TimesheetModuleColors.mutedText,
                  indicatorColor: TimesheetModuleColors.primary,
                  tabs: [
                    Tab(text: 'Overview'),
                    Tab(text: 'Site Reports'),
                    Tab(text: 'Teams'),
                  ],
                ),
              ),
              const SizedBox(height: TimesheetModuleLayout.cardSpacing),
              Expanded(
                child: TabBarView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: TimesheetModuleLayout.screenPaddingH,
                        vertical: TimesheetModuleLayout.cardSpacing,
                      ),
                      child: siteMode
                          ? SingleChildScrollView(
                              child: ProjectRecordCard(project: project),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final height = constraints.maxHeight;
                                return ProjectRecordCard(
                                  project: project,
                                  viewportHeight:
                                      height > 0 ? height : null,
                                );
                              },
                            ),
                    ),
                    const TmSiteReportsListScreen(
                      embedInParent: true,
                      title: 'Site Reports',
                    ),
                    _PmTeamsTab(projectId: project.id),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectAction {
  const _ProjectAction({
    required this.label,
    required this.icon,
    required this.routeName,
  });

  final String label;
  final IconData icon;
  final String routeName;
}

class _ProjectActionsBar extends StatelessWidget {
  const _ProjectActionsBar({
    required this.projectId,
    required this.items,
  });

  final String projectId;
  final List<_ProjectAction> items;

  @override
  Widget build(BuildContext context) {
    return TmBottomNavBar(
      dark: true,
      fabIcon: PhosphorIcons.chatCircleText(),
      items: [
        for (final item in items)
          TmBottomNavItem(label: item.label, icon: item.icon),
      ],
      currentIndex: -1,
      onItemTap: (index) => Navigator.of(context).pushNamed(
        items[index].routeName,
        arguments: TimesheetProjectArgs(projectId: projectId),
      ),
      onFabTap: () => Navigator.of(context).pushNamed(
        TimesheetRouteNames.projectChat,
        arguments: TimesheetProjectArgs(projectId: projectId),
      ),
    );
  }
}

class _PmTeamsTab extends ConsumerWidget {
  const _PmTeamsTab({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foremenAsync = ref.watch(timesheetPmForemenProvider);

    return foremenAsync.when(
      loading: () => const TimesheetLoadingState(
        style: TimesheetLoadingStyle.list,
        itemCount: 4,
      ),
      error: (_, __) => const TimesheetErrorState(
        message: 'Could not load foremen',
      ),
      data: (foremen) {
        return ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: TimesheetModuleLayout.screenPaddingH,
            vertical: TimesheetModuleLayout.cardSpacing,
          ),
          children: [
            TmTaskRow(
              title: 'Map Pins',
              subtitle: 'Foreman, active workers, and geofence',
              icon: PhosphorIcons.mapTrifold(),
              onTap: () => Navigator.of(context).pushNamed(
                TimesheetRouteNames.liveMap,
                arguments: TimesheetProjectArgs(projectId: projectId),
              ),
            ),
            const SizedBox(height: TimesheetModuleLayout.cardSpacing),
            TmTaskRow(
              title: 'Add Worker',
              subtitle: 'Enrol and assign to project tasks',
              icon: PhosphorIcons.userPlus(),
              onTap: () => Navigator.of(context).pushNamed(
                TimesheetRouteNames.workerEnrol,
                arguments: TimesheetProjectArgs(projectId: projectId),
              ),
            ),
            const SizedBox(height: TimesheetModuleLayout.sectionGap),
            TmTaskRow(
              title: 'Foremen',
              subtitle: foremen.isEmpty
                  ? 'No foremen assigned'
                  : '${foremen.length} foreman${foremen.length == 1 ? '' : 'en'}',
              icon: PhosphorIcons.usersThree(),
              trailing: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: TimesheetModuleColors.navyTint,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${foremen.length}',
                  style: TimesheetModuleTypography.caption().copyWith(
                    color: TimesheetModuleColors.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              onTap: foremen.isEmpty
                  ? null
                  : () => _showForemen(context, foremen),
            ),
          ],
        );
      },
    );
  }

  void _showForemen(BuildContext context, List<TimesheetTeamMember> foremen) {
    TmTeamMembersSheet.show(
      context,
      title: 'Project foremen',
      members: foremen,
    );
  }
}
