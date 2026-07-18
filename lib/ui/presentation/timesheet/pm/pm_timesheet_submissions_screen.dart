import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// PM **read-only** view of timesheets submitted by foremen for their labors.
class PmTimesheetSubmissionsScreen extends ConsumerStatefulWidget {
  const PmTimesheetSubmissionsScreen({
    super.key,
    required this.projectId,
    this.projectName,
  });

  final String projectId;
  final String? projectName;

  @override
  ConsumerState<PmTimesheetSubmissionsScreen> createState() =>
      _PmTimesheetSubmissionsScreenState();
}

class _PmTimesheetSubmissionsScreenState
    extends ConsumerState<PmTimesheetSubmissionsScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final rowsAsync = ref.watch(
      timesheetPmSubmittedRowsProvider(
        TimesheetAttendanceQuery(
          projectId: widget.projectId,
          date: _selectedDate,
        ),
      ),
    );

    return TmScaffold(
      glassTitle: 'Timesheet report',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.projectName ?? widget.projectId,
            style: TimesheetModuleTypography.caption(),
          ),
          const SizedBox(height: 6),
          Text(
            'Submitted by your foremen · labors only (x_labor_ids / x_foreman_ids)',
            style: TimesheetModuleTypography.caption(),
          ),
          const SizedBox(height: TimesheetModuleLayout.cardSpacing),
          TmSectionHeader(
            title: DateFormat('EEE, dd MMM yyyy').format(_selectedDate),
            actionLabel: 'Previous day',
            onActionTap: () => setState(
              () => _selectedDate = _selectedDate.subtract(const Duration(days: 1)),
            ),
          ),
          const SizedBox(height: TimesheetModuleLayout.sectionGap),
          Expanded(
            child: rowsAsync.when(
              loading: () => const TimesheetLoadingState(
                style: TimesheetLoadingStyle.list,
                itemCount: 6,
              ),
              error: (_, __) => TimesheetErrorState(
                message: 'Could not load timesheet submissions',
                onRetry: () => ref.invalidate(
                  timesheetPmSubmittedRowsProvider(
                    TimesheetAttendanceQuery(
                      projectId: widget.projectId,
                      date: _selectedDate,
                    ),
                  ),
                ),
              ),
              data: (rows) {
                if (rows.isEmpty) {
                  return const TimesheetEmptyState(
                    message: 'No timesheet submissions for this day',
                  );
                }
                return ListView(
                  children: [
                    for (final row in rows) ...[
                      TmTaskRow(
                        title: row['employee']?.toString() ?? 'Labor',
                        subtitle:
                            '${row['unit_amount'] ?? 0} hrs · ${row['state'] ?? ''}',
                        icon: PhosphorIcons.identificationBadge(),
                      ),
                      const SizedBox(
                        height: TimesheetModuleLayout.cardSpacing,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
