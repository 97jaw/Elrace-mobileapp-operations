import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/routing/timesheet_route_names.dart';
import 'package:el_race/core/timesheet/timesheet_defaults.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/task_sheet/EmployeeShiftRequestPage.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_route_args.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Merges legacy **Add a new request** with **Take attendance** (camera).
///
/// Reference flow (home widget `time_sheet` → [TaskSheetPage]):
/// project/task → [TaskDetailsPage] dates → [EmptyShiftPage] day →
/// Add request ([AddTaskSheet] / [EmployeeShiftRequestPage]) or shift list.
///
/// Camera path is unchanged: AT1 → AT2 → AT4 → `/api/timesheet/submit`.
class FmAddRequestHubScreen extends StatelessWidget {
  const FmAddRequestHubScreen({
    super.key,
    required this.args,
  });

  final TimesheetProjectDayArgs args;

  TimesheetCaptureArgs get _captureArgs => TimesheetCaptureArgs(
        projectId: args.projectId,
        taskId: args.taskId,
        taskName: args.taskName,
        workDate: args.date,
      );

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEE, dd MMM yyyy').format(args.date);

    return TmScaffold(
      glassTitle: 'Add timesheet',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(args.projectName, style: TimesheetModuleTypography.caption()),
          const SizedBox(height: 4),
          Text(
            '$dateLabel · ${args.taskName} (${TimesheetDefaults.maintenanceTaskName})',
            style: TimesheetModuleTypography.caption(),
          ),
          const SizedBox(height: TimesheetModuleLayout.sectionGap),
          Text(
            'Choose how to record this day',
            style: TimesheetModuleTypography.display(),
          ),
          const SizedBox(height: TimesheetModuleLayout.sectionGap),
          TmPrimaryButton(
            label: 'Take attendance',
            icon: PhosphorIcons.camera(),
            onPressed: () => Navigator.of(context).pushNamed(
              TimesheetRouteNames.captureMode,
              arguments: _captureArgs,
            ),
          ),
          const SizedBox(height: TimesheetModuleLayout.cardSpacing),
          TmSecondaryButton(
            label: 'Add a new request',
            icon: PhosphorIcons.plusCircle(),
            onPressed: () => _openManualRequest(context),
          ),
          const SizedBox(height: TimesheetModuleLayout.sectionGap),
          Text(
            'Both options submit via /api/timesheet/submit. '
            'Camera uses face match first, then confirm on the summary screen.',
            style: TimesheetModuleTypography.caption(),
          ),
        ],
      ),
    );
  }

  void _openManualRequest(BuildContext context) {
    final login = SharedPref.getLoginData();
    final projectId = int.tryParse(args.projectId) ?? 0;
    final taskId = int.tryParse(args.taskId) ?? 0;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EmployeeShiftRequestPage(
          loginResponseModel: login,
          taskId: taskId,
          project_id: projectId,
          selectedDate: args.date,
        ),
      ),
    );
  }
}
