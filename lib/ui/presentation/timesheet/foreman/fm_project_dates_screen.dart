import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/core/timesheet/timesheet_defaults.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/foreman/fm_timesheet_capture_submit_screen.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_route_args.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/fm_project_timesheet_header.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_timesheet_entry_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Project calendar — Timesheet + Site Report tabs; day drill-down for timesheets.
class FmProjectDatesScreen extends ConsumerStatefulWidget {
  const FmProjectDatesScreen({
    super.key,
    required this.projectId,
    this.projectName,
    this.clientImageUrl,
  });

  final String projectId;
  final String? projectName;
  final String? clientImageUrl;

  @override
  ConsumerState<FmProjectDatesScreen> createState() =>
      _FmProjectDatesScreenState();
}

class _FmProjectDatesScreenState extends ConsumerState<FmProjectDatesScreen> {
  late DateTime _rangeEnd;
  late DateTime _rangeStart;
  bool _rangeActive = false;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _rangeEnd = DateTime(now.year, now.month, now.day);
    _rangeStart = _rangeEnd.subtract(const Duration(days: 13));
    _rangeActive = true;
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _rangeStart, end: _rangeEnd),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _rangeStart = DateTime(
        picked.start.year,
        picked.start.month,
        picked.start.day,
      );
      _rangeEnd = DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
      );
      _rangeActive = true;
      _selectedDay = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final taskAsync =
        ref.watch(timesheetMaintenanceTaskProvider(widget.projectId));
    final title = widget.projectName ?? widget.projectId;
    final imageUrl = widget.clientImageUrl ?? '';

    return Scaffold(
      backgroundColor: _selectedDay != null
          ? TimesheetModuleColors.surface
          : TimesheetModuleColors.bgGradientEnd,
      body: taskAsync.when(
        loading: () => const TimesheetLoadingState(
          style: TimesheetLoadingStyle.list,
          itemCount: 6,
        ),
        error: (_, __) => TimesheetErrorState(
          message: 'Could not load foreman task for this project',
          onRetry: () => ref.invalidate(
            timesheetMaintenanceTaskProvider(widget.projectId),
          ),
        ),
        data: (task) {
          if (_selectedDay != null) {
            return _DayBody(
              projectId: widget.projectId,
              projectName: title,
              clientImageUrl: imageUrl,
              taskId: task.id,
              taskName: task.name,
              date: _selectedDay!,
              rangeStart: _rangeStart,
              rangeEnd: _rangeEnd,
              rangeActive: _rangeActive,
              onClearDay: () => setState(() => _selectedDay = null),
              onPickRange: _pickDateRange,
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FmProjectHeroHeader(
                projectName: title,
                clientImageUrl: imageUrl,
                rangeActive: _rangeActive,
                onBack: () => Navigator.of(context).maybePop(),
              ),
              FmProjectDatesContextBar(
                taskLabel: task.name,
                taskId: task.id,
                rangeStart: _rangeStart,
                rangeEnd: _rangeEnd,
                onPickRange: _pickDateRange,
              ),
              Expanded(
                child: _TimesheetRangeTab(
                  taskId: task.id,
                  rangeStart: _rangeStart,
                  rangeEnd: _rangeEnd,
                  onDayTap: (day) => setState(() => _selectedDay = day),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TimesheetRangeTab extends ConsumerWidget {
  const _TimesheetRangeTab({
    required this.taskId,
    required this.rangeStart,
    required this.rangeEnd,
    required this.onDayTap,
  });

  final String taskId;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countsAsync = ref.watch(
      timesheetTaskDayCountsProvider(
        TimesheetTaskDayCountsQuery(
          taskId: taskId,
          startDate: rangeStart,
          endDate: rangeEnd,
        ),
      ),
    );

    return ColoredBox(
      color: TimesheetModuleColors.bgGradientEnd,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TimesheetModuleLayout.screenPaddingH,
          TimesheetModuleLayout.cardSpacing,
          TimesheetModuleLayout.screenPaddingH,
          TimesheetModuleLayout.sectionGap,
        ),
        child: countsAsync.when(
          loading: () => const TimesheetLoadingState(
            style: TimesheetLoadingStyle.list,
            itemCount: 6,
          ),
          error: (_, __) => TimesheetErrorState(
            message: 'Could not load timesheet days',
            onRetry: () => ref.invalidate(
              timesheetTaskDayCountsProvider(
                TimesheetTaskDayCountsQuery(
                  taskId: taskId,
                  startDate: rangeStart,
                  endDate: rangeEnd,
                ),
              ),
            ),
          ),
          data: (days) {
            if (days.isEmpty) {
              return const TimesheetEmptyState(
                message: 'No days in this range',
              );
            }
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                for (final day in days) ...[
                  TmTaskRow(
                    title: DateFormat('EEE, dd MMM yyyy').format(day.date),
                    subtitle:
                        'In progress ${day.inProgress} · Submitted ${day.submitted} · Approved ${day.approved}',
                    icon: PhosphorIcons.calendarBlank(),
                    onTap: () => onDayTap(day.date),
                  ),
                  const SizedBox(height: TimesheetModuleLayout.cardSpacing),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DayBody extends ConsumerWidget {
  const _DayBody({
    required this.projectId,
    required this.projectName,
    required this.clientImageUrl,
    required this.taskId,
    required this.taskName,
    required this.date,
    required this.rangeStart,
    required this.rangeEnd,
    required this.rangeActive,
    required this.onClearDay,
    required this.onPickRange,
  });

  final String projectId;
  final String projectName;
  final String clientImageUrl;
  final String taskId;
  final String taskName;
  final DateTime date;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final bool rangeActive;
  final VoidCallback onClearDay;
  final VoidCallback onPickRange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = TimesheetProjectDayArgs(
      projectId: projectId,
      projectName: projectName,
      taskId: taskId,
      taskName: taskName,
      date: date,
    );
    final timesheetsAsync = ref.watch(_dayTimesheetsProvider(_DayQuery(
      projectId: projectId,
      taskId: taskId,
      date: date,
    )));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FmProjectHeroHeader(
          projectName: projectName,
          clientImageUrl: clientImageUrl,
          rangeActive: rangeActive,
          onBack: onClearDay,
        ),
        FmProjectDatesContextBar(
          taskLabel: taskName,
          taskId: taskId,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          selectedDay: date,
          onPickRange: onPickRange,
          onClearDay: onClearDay,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TimesheetModuleLayout.screenPaddingH,
            TimesheetModuleLayout.cardSpacing,
            TimesheetModuleLayout.screenPaddingH,
            TimesheetModuleLayout.cardSpacing,
          ),
          child: TmPrimaryButton(
            label: 'Add timesheet / attendance',
            warm: true,
            icon: PhosphorIcons.plusCircle(),
            onPressed: () async {
              final submitted = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) =>
                      FmTimesheetCaptureSubmitScreen(args: args),
                ),
              );
              if (submitted == true && context.mounted) {
                ref.invalidate(_dayTimesheetsProvider(_DayQuery(
                  projectId: projectId,
                  taskId: taskId,
                  date: date,
                )));
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TimesheetModuleLayout.screenPaddingH,
          ),
          child: Row(
            children: [
              Text(
                'Timesheets on this day',
                style: TimesheetModuleTypography.h2(),
              ),
              const Spacer(),
              timesheetsAsync.maybeWhen(
                data: (rows) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: TimesheetModuleColors.navyTint,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${rows.length}',
                    style: TimesheetModuleTypography.caption().copyWith(
                      fontWeight: FontWeight.w800,
                      color: TimesheetModuleColors.navy,
                    ),
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        const SizedBox(height: TimesheetModuleLayout.cardSpacing),
        Expanded(
          child: ColoredBox(
            color: TimesheetModuleColors.bgGradientEnd,
            child: timesheetsAsync.when(
              loading: () => const TimesheetLoadingState(
                style: TimesheetLoadingStyle.list,
                itemCount: 4,
              ),
              error: (_, __) => const TimesheetErrorState(
                message: 'Could not load timesheets for this day',
              ),
              data: (rows) {
                if (rows.isEmpty) {
                  return TimesheetEmptyState(
                    message:
                        'No timesheets with work date '
                        '${DateFormat('dd MMM yyyy').format(date)}.\n'
                        'Odoo may show a different created date in list views.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    TimesheetModuleLayout.screenPaddingH,
                    0,
                    TimesheetModuleLayout.screenPaddingH,
                    24,
                  ),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    return TmTimesheetEntryRow(
                      row: rows[index],
                      index: index + 1,
                      homeLight: true,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _DayQuery {
  const _DayQuery({
    required this.projectId,
    required this.taskId,
    required this.date,
  });

  final String projectId;
  final String taskId;
  final DateTime date;

  @override
  bool operator ==(Object other) {
    return other is _DayQuery &&
        other.projectId == projectId &&
        other.taskId == taskId &&
        other.date == date;
  }

  @override
  int get hashCode => Object.hash(projectId, taskId, date);
}

final _dayTimesheetsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, _DayQuery>((ref, query) async {
  final client = ref.watch(timesheetApiClientProvider);
  if (TimesheetDefaults.isOdooIntegerId(query.taskId)) {
    return client.fetchTaskTimesheetRowsForDate(
      taskId: query.taskId,
      date: query.date,
    );
  }
  return client.fetchProjectTimesheetRows(
    projectId: query.projectId,
    date: query.date,
  );
});
