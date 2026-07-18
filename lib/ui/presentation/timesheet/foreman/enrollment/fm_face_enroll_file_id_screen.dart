import 'dart:async';

import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/core/timesheet/routing/timesheet_route_names.dart';
import 'package:el_race/core/timesheet/services/timesheet_employee_lookup.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_route_args.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Step 1 — enter file ID, then open pose capture for that employee.
class FmFaceEnrollFileIdScreen extends ConsumerStatefulWidget {
  const FmFaceEnrollFileIdScreen({
    super.key,
    required this.args,
  });

  final TimesheetFaceEnrollArgs args;

  @override
  ConsumerState<FmFaceEnrollFileIdScreen> createState() =>
      _FmFaceEnrollFileIdScreenState();
}

class _FmFaceEnrollFileIdScreenState
    extends ConsumerState<FmFaceEnrollFileIdScreen> {
  final _fileIdController = TextEditingController();
  List<TimesheetOdooEmployee> _roster = const [];
  bool _loadingRoster = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final prefill = widget.args.prefillFileId?.trim();
    if (prefill != null && prefill.isNotEmpty) {
      _fileIdController.text = prefill;
    }
    unawaited(_loadRoster());
  }

  @override
  void dispose() {
    _fileIdController.dispose();
    super.dispose();
  }

  Future<void> _loadRoster() async {
    final client = ref.read(timesheetApiClientProvider);
    try {
      var labors = await client.fetchLaborEmployeesForReport(
        projectId: widget.args.projectId,
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

  Future<void> _onNext() async {
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
    final enrolled = await Navigator.of(context).pushNamed<bool>(
      TimesheetRouteNames.faceEnrollCapture,
      arguments: TimesheetFaceEnrollCaptureArgs(
        projectId: widget.args.projectId,
        employee: match,
        returnToCapture: widget.args.returnToCapture,
      ),
    );
    if (enrolled == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TmScaffold(
      glassTitle: 'Enroll employee',
      body: Padding(
        padding: const EdgeInsets.all(TimesheetModuleLayout.screenPaddingH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter the employee file ID to start face enrollment. '
              'You will capture front, left, right, and up poses.',
              style: TimesheetModuleTypography.body(),
            ),
            const SizedBox(height: TimesheetModuleLayout.sectionGap),
            TextField(
              controller: _fileIdController,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _onNext(),
              decoration: InputDecoration(
                labelText: 'File ID',
                hintText: 'e.g. E12345',
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
            ],
            const Spacer(),
            TmPrimaryButton(
              label: 'Next',
              icon: PhosphorIcons.arrowRight(),
              onPressed: _loadingRoster ? null : _onNext,
            ),
          ],
        ),
      ),
    );
  }
}
