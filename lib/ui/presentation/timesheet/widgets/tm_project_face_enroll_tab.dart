import 'dart:async';

import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/core/timesheet/services/timesheet_employee_lookup.dart';
import 'package:el_race/core/timesheet/providers/timesheet_hr_scope_provider.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/foreman/enrollment/fm_face_enroll_capture_screen.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_route_args.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Project tab — face enrollment (separate from attendance camera).
class TmProjectFaceEnrollTab extends ConsumerStatefulWidget {
  const TmProjectFaceEnrollTab({
    super.key,
    required this.projectId,
    this.projectName,
  });

  final String projectId;
  final String? projectName;

  @override
  ConsumerState<TmProjectFaceEnrollTab> createState() =>
      _TmProjectFaceEnrollTabState();
}

class _TmProjectFaceEnrollTabState extends ConsumerState<TmProjectFaceEnrollTab> {
  final _fileIdController = TextEditingController();
  List<TimesheetOdooEmployee> _roster = const [];
  bool _loadingRoster = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadRoster());
  }

  @override
  void dispose() {
    _fileIdController.dispose();
    super.dispose();
  }

  Future<void> _loadRoster() async {
    setState(() {
      _loadingRoster = true;
      _error = null;
    });
    final client = ref.read(timesheetApiClientProvider);
    try {
      var labors = await client.fetchLaborEmployeesForReport(
        projectId: widget.projectId,
        includeDrivers: true,
        useHrScopeWhenNoProject: false,
      );
      if (labors.isEmpty) {
        labors = await client.fetchEmployeeRoster();
      }
      if (!mounted) return;
      setState(() {
        _roster = dedupeTimesheetEmployeesById(labors);
        _loadingRoster = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingRoster = false;
        _error = 'Could not load employee list';
      });
    }
  }

  Future<void> _startEnrollment() async {
    final query = _fileIdController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the employee file ID')),
      );
      return;
    }
    final match = findTimesheetEmployeeByFileId(_roster, query);
    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No employee found for "$query"')),
      );
      return;
    }

    final enrolled = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FmFaceEnrollCaptureScreen(
          args: TimesheetFaceEnrollCaptureArgs(
            projectId: widget.projectId,
            employee: match,
          ),
        ),
      ),
    );
    if (enrolled == true && mounted) {
      ref.invalidate(timesheetHrScopeProvider);
      await _loadRoster();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${match.name} enrolled — you will be notified when verification completes.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: TimesheetModuleColors.bgGradientEnd,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          TimesheetModuleLayout.screenPaddingH,
          TimesheetModuleLayout.sectionGap,
          TimesheetModuleLayout.screenPaddingH,
          32,
        ),
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: TimesheetModuleColors.surface,
              borderRadius: BorderRadius.circular(
                TimesheetModuleLayout.cardRadiusMd,
              ),
              border: Border.all(color: TimesheetModuleColors.divider),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    PhosphorIcons.scanSmiley(),
                    color: TimesheetModuleColors.primary,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Face enrollment',
                          style: TimesheetModuleTypography.cardTitle(),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Register front, left, right, and up poses. '
                          'After upload you will get a push notification when '
                          'enrollment is verified and ready for attendance.',
                          style: TimesheetModuleTypography.caption(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: TimesheetModuleLayout.sectionGap),
          Text(
            'Employee file ID',
            style: TimesheetModuleTypography.body().copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _fileIdController,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _startEnrollment(),
            decoration: InputDecoration(
              hintText: 'e.g. emp profile / file id',
              prefixIcon: Icon(PhosphorIcons.identificationCard()),
              filled: true,
              fillColor: TimesheetModuleColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  TimesheetModuleLayout.cardRadiusMd,
                ),
              ),
            ),
          ),
          if (_loadingRoster) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TimesheetModuleTypography.caption()),
            TextButton(onPressed: _loadRoster, child: const Text('Retry')),
          ],
          const SizedBox(height: TimesheetModuleLayout.sectionGap),
          TmPrimaryButton(
            label: 'Start enrollment',
            warm: true,
            icon: PhosphorIcons.camera(),
            onPressed: _loadingRoster ? null : _startEnrollment,
          ),
          const SizedBox(height: TimesheetModuleLayout.cardSpacing),
          Text(
            'Attendance camera is unchanged — use this tab only to enroll '
            'or re-enroll labors on ${widget.projectName ?? 'this project'}.',
            style: TimesheetModuleTypography.caption(),
          ),
        ],
      ),
    );
  }
}
