import 'dart:async';

import 'package:el_race/core/site_management/face_recognition/face_recognition_provider.dart';
import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/core/timesheet/timesheet_defaults.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/foreman/fm_timesheet_capture_submit_screen.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_route_args.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_timesheet_entry_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Day hub — list entries + single action to add timesheet (camera + form).
class FmDayHubScreen extends ConsumerStatefulWidget {
  const FmDayHubScreen({
    super.key,
    required this.args,
  });

  final TimesheetProjectDayArgs args;

  @override
  ConsumerState<FmDayHubScreen> createState() => _FmDayHubScreenState();
}

class _FmDayHubScreenState extends ConsumerState<FmDayHubScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(ref.read(faceDbBackgroundSyncProvider.future));
  }

  TimesheetProjectDayArgs get args => widget.args;

  @override
  Widget build(BuildContext context) {
    final timesheetsAsync = ref.watch(
      _dayTimesheetsProvider(
        _DayTimesheetsQuery(
          projectId: args.projectId,
          taskId: args.taskId,
          date: args.date,
        ),
      ),
    );

    final formattedDate = DateFormat('EEE, dd MMM yyyy').format(args.date);

    return TmScaffold(
      appBar: AppBar(
        title: Text(formattedDate, style: TimesheetModuleTypography.h2()),
        backgroundColor: TimesheetModuleColors.surface,
        foregroundColor: TimesheetModuleColors.text,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(args.projectName, style: TimesheetModuleTypography.caption()),
          const SizedBox(height: 4),
          Text(
            args.taskName,
            style: TimesheetModuleTypography.caption(),
          ),
          const SizedBox(height: TimesheetModuleLayout.sectionGap),
          TmPrimaryButton(
            label: 'Add timesheet / attendance',
            icon: PhosphorIcons.plusCircle(),
            onPressed: () async {
              final submitted = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => FmTimesheetCaptureSubmitScreen(args: args),
                ),
              );
              if (submitted == true && context.mounted) {
                ref.invalidate(
                  _dayTimesheetsProvider(
                    _DayTimesheetsQuery(
                      projectId: args.projectId,
                      taskId: args.taskId,
                      date: args.date,
                    ),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: TimesheetModuleLayout.sectionGap),
          TmSectionHeader(title: 'Timesheets on this day'),
          const SizedBox(height: TimesheetModuleLayout.cardSpacing),
          Expanded(
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
                        '${DateFormat('dd MMM yyyy').format(args.date)}.\n'
                        'Odoo may show a different created date in list views.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: rows.length,
                  itemBuilder: (context, index) => TmTimesheetEntryRow(
                    row: rows[index],
                    index: index + 1,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DayTimesheetsQuery {
  const _DayTimesheetsQuery({
    required this.projectId,
    required this.taskId,
    required this.date,
  });

  final String projectId;
  final String taskId;
  final DateTime date;

  @override
  bool operator ==(Object other) {
    return other is _DayTimesheetsQuery &&
        other.projectId == projectId &&
        other.taskId == taskId &&
        other.date == date;
  }

  @override
  int get hashCode => Object.hash(projectId, taskId, date);
}

final _dayTimesheetsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, _DayTimesheetsQuery>((ref, query) async {
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
