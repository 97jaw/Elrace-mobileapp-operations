import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_models.dart';
import 'package:el_race/core/timesheet/models/timesheet_team_member.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/core/timesheet/routing/timesheet_route_names.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_timesheet_widget_provider.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_route_args.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_dashboard_header.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_dashboard_projects_section.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_team_members_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// PM Timesheet hub — weekly summary and read-only foreman submissions.
class PmTimesheetHomeScreen extends ConsumerWidget {
  const PmTimesheetHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(timesheetLoginProfileProvider);
    final widgetData = ref.watch(homeTimesheetWidgetProvider);
    final bucketsAsync = ref.watch(timesheetProjectBucketsProvider);
    final projectsAsync = ref.watch(timesheetProjectsProvider);
    final foremenAsync = ref.watch(timesheetPmForemenProvider);

    final foremanCount = foremenAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );

    return TmScaffold(
      padding: const EdgeInsets.symmetric(
        horizontal: TimesheetModuleLayout.screenPaddingH,
        vertical: 12,
      ),
      appBar: AppBar(
        title: Text('Timesheet', style: TimesheetModuleTypography.h2()),
        backgroundColor: TimesheetModuleColors.surface,
        foregroundColor: TimesheetModuleColors.text,
        elevation: 0,
      ),
      body: bucketsAsync.when(
        loading: () => const TimesheetLoadingState(
          style: TimesheetLoadingStyle.list,
          itemCount: 4,
        ),
        error: (_, __) => TimesheetErrorState(
          message: 'Could not load PM projects',
          onRetry: () => ref.invalidate(timesheetProjectBucketsProvider),
        ),
        data: (buckets) {
          return projectsAsync.when(
            loading: () => const TimesheetLoadingState(
              style: TimesheetLoadingStyle.list,
              itemCount: 4,
            ),
            error: (_, __) => const TimesheetErrorState(
              message: 'Could not load active projects',
            ),
            data: (projects) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TmDashboardHeader(
                      key: ValueKey(
                        '${profile.fileId}|${profile.displayName}|${profile.imageUrl}',
                      ),
                      profile: profile,
                      counterLabel: 'Foremen',
                      counterValue: foremanCount,
                      onCounterTap: () => _showForemen(context, ref),
                    ),
                    const SizedBox(height: TimesheetModuleLayout.sectionGap),
                    Text(
                      'Review timesheets submitted by your foremen. '
                      'PMs do not submit attendance.',
                      style: TimesheetModuleTypography.caption(),
                    ),
                    const SizedBox(height: TimesheetModuleLayout.sectionGap),
                    _WeeklySummaryCard(data: widgetData),
                    const SizedBox(height: TimesheetModuleLayout.sectionGap),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: TmStatTile(
                              value: '${widgetData.recordsCount}',
                              label: 'Records this week',
                              icon: PhosphorIcons.clipboardText(),
                              badgeTone: TmStatBadgeTone.inProgress,
                              onTap: projects.isNotEmpty
                                  ? () => _openFirstProjectReport(
                                        context,
                                        projects.first,
                                      )
                                  : null,
                            ),
                          ),
                          const SizedBox(
                            width: TimesheetModuleLayout.cardSpacing,
                          ),
                          Expanded(
                            child: TmStatTile(
                              value: '${buckets.inProgress.length}',
                              label: 'Active projects',
                              icon: PhosphorIcons.briefcase(),
                              badgeTone: TmStatBadgeTone.neutral,
                              onTap: () => Navigator.of(context).pushNamed(
                                TimesheetRouteNames.projectsList,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: TimesheetModuleLayout.sectionGap),
                    if (projects.isEmpty)
                      const TimesheetEmptyState(
                        message: 'No in-progress projects',
                      )
                    else ...[
                      TmSectionHeader(
                        title: 'Project submissions',
                        actionLabel: 'See all',
                        onActionTap: () => Navigator.of(context).pushNamed(
                          TimesheetRouteNames.projectsList,
                        ),
                      ),
                      const SizedBox(height: TimesheetModuleLayout.cardSpacing),
                      TmDashboardProjectsSection(
                        projects: projects,
                        onProjectTap: (project) => _openProjectReport(
                          context,
                          project,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showForemen(BuildContext context, WidgetRef ref) {
    final members = ref.read(timesheetPmForemenProvider).maybeWhen(
          data: (value) => value,
          orElse: () => <TimesheetTeamMember>[],
        );
    TmTeamMembersSheet.show(
      context,
      title: 'My foremen',
      members: members,
    );
  }

  void _openFirstProjectReport(BuildContext context, Project project) {
    _openProjectReport(context, project);
  }

  void _openProjectReport(BuildContext context, Project project) {
    Navigator.of(context).pushNamed(
      TimesheetRouteNames.pmTimesheetReport,
      arguments: TimesheetProjectArgs(
        projectId: project.id,
        projectName: project.name,
        clientImageUrl: project.clientImageUrl,
        woRefNo: project.woRefNo,
      ),
    );
  }
}

class _WeeklySummaryCard extends StatelessWidget {
  const _WeeklySummaryCard({required this.data});

  final TimesheetWidgetRecord data;

  String _formatHours(double value) {
    if (value % 1 == 0) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TimesheetModuleColors.surface,
        borderRadius:
            BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
        border: Border.all(color: TimesheetModuleColors.mutedText.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.titleLine,
            style: TimesheetModuleTypography.h2(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Total hours',
                  value: _formatHours(data.totalHours),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Overtime',
                  value: _formatHours(data.overtimeHours),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Workers',
                  value: '${data.workersCount}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            data.deltaTrendLabel,
            style: TimesheetModuleTypography.caption().copyWith(
              color: data.deltaVsLastWeek >= 0
                  ? const Color(0xFF1F9D63)
                  : const Color(0xFFE05A4F),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TimesheetModuleTypography.caption()),
        const SizedBox(height: 4),
        Text(value, style: TimesheetModuleTypography.h2()),
      ],
    );
  }
}
