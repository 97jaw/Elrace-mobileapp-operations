import 'dart:async';

import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/network/timesheet_functions_client.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/core/timesheet/providers/timesheet_hr_scope_provider.dart';
import 'package:el_race/core/timesheet/routing/timesheet_route_names.dart';
import 'package:el_race/core/timesheet/services/capture_queue_service.dart';
import 'package:el_race/core/site_management/face_recognition/data/repositories/face_db_repository.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/foreman/attendance/timesheet_capture_camera_panel.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_route_args.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class At2CaptureCameraScreen extends ConsumerStatefulWidget {
  const At2CaptureCameraScreen({
    super.key,
    required this.capture,
  });

  final TimesheetCaptureArgs capture;

  @override
  ConsumerState<At2CaptureCameraScreen> createState() =>
      _At2CaptureCameraScreenState();
}

class _At2CaptureCameraScreenState extends ConsumerState<At2CaptureCameraScreen> {
  final GlobalKey<TimesheetCaptureCameraPanelState> _cameraKey =
      GlobalKey<TimesheetCaptureCameraPanelState>();

  List<TimesheetOdooEmployee> _faceMatchRoster = const [];
  bool _phaseBActive = false;

  bool get isGroup => widget.capture.mode == 'group';

  @override
  void initState() {
    super.initState();
    unawaited(_bootCapture());
  }

  Future<void> _bootCapture() async {
    await _syncFaceDb();
    await _loadRoster();
  }

  Future<void> _syncFaceDb() async {
    final service = ref.read(faceRecognitionServiceProvider);
    final result = await service.syncFaceDb();
    if (!mounted) return;
    final phaseB = service.isReady ? 'Phase B on' : 'Phase B off';
    final msg = switch (result.status) {
      FaceSyncStatus.synced => 'Face DB updated (${result.count} templates)',
      FaceSyncStatus.upToDate => 'Face DB ready (${result.count} templates)',
      FaceSyncStatus.failed when result.message?.startsWith('offline_cache') ==
              true =>
        'Face DB offline (${result.count} cached)',
      FaceSyncStatus.failed => 'Face DB sync failed — manual flow only',
      FaceSyncStatus.empty => 'No enrolled faces on server',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$msg ($phaseB)'),
        duration: const Duration(seconds: 5),
      ),
    );
    setState(() => _phaseBActive = service.isReady);
  }

  Future<void> _loadRoster() async {
    final client = ref.read(timesheetApiClientProvider);
    List<TimesheetOdooEmployee> labors;
    try {
      labors = await client.fetchLaborEmployeesForReport(
        projectId: widget.capture.projectId,
        includeDrivers: true,
        useHrScopeWhenNoProject: false,
      );
    } catch (e) {
      debugPrint('At2Capture: labor_list failed: $e');
      final scope = await ref.read(timesheetHrScopeProvider.future);
      final roster = await client.fetchEmployeeRoster();
      labors = scope.hasLaborScope
          ? roster
              .where((e) => scope.laborEmployeeIds.contains(e.employeeId))
              .toList()
          : roster;
    }
    if (!mounted) return;
    final faceRoster = _phaseBActive
        ? const <TimesheetOdooEmployee>[]
        : labors.where((e) => e.canUseFaceMatch).toList(growable: false);
    if (_phaseBActive) {
      debugPrint(
        'At2Capture: Phase B active — skip HR photo roster (${labors.length} labors)',
      );
    }
    setState(() => _faceMatchRoster = faceRoster);
  }

  void _onRosterMatched(
    TimesheetOdooEmployee employee,
    AttendanceCaptureDraft draft,
    double matchScore, {
    double secondBestScore = 0,
    bool closeSecondCandidate = false,
  }) {
    _navigateToSummary(
      TimesheetMatchAttendanceResult(
        result: 'matched',
        similarity: 99,
        workerId: employee.fileId ?? 'emp_${employee.employeeId}',
        outsideGeofence: false,
        taskMembership: true,
      ),
      draft,
    );
  }

  void _onOutOfTeamRecognized(
    TimesheetOdooEmployee employee,
    AttendanceCaptureDraft _,
    double matchScore,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${employee.name} is recognized (${(matchScore * 100).toStringAsFixed(0)}%) '
          'but not in your team.',
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TmScaffold(
      appBar: AppBar(
        title: Text(
          widget.capture.taskName ?? (isGroup ? 'Group capture' : 'Capture'),
          style: TimesheetModuleTypography.h2(),
        ),
        backgroundColor: TimesheetModuleColors.surface,
        foregroundColor: TimesheetModuleColors.text,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pushReplacementNamed(
              TimesheetRouteNames.captureCamera,
              arguments: widget.capture.copyWith(
                mode: isGroup ? 'individual' : 'group',
              ),
            ),
            child: Text(isGroup ? 'Individual' : 'Group'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: TimesheetCaptureCameraPanel(
              key: _cameraKey,
              capture: widget.capture,
              showShutter: false,
              rosterEmployees: _faceMatchRoster,
              faceRecognition: ref.read(faceRecognitionServiceProvider),
              onRosterEmployeeMatched: _onRosterMatched,
              onOutOfTeamRecognized: _onOutOfTeamRecognized,
              onCaptureMatched: _navigateToSummary,
            ),
          ),
          const SizedBox(height: TimesheetModuleLayout.sectionGap),
          Row(
            children: [
              Expanded(
                child: TmSecondaryButton(
                  label: 'Cancel',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              const SizedBox(width: TimesheetModuleLayout.cardSpacing),
              Expanded(
                child: TmPrimaryButton(
                  label: 'Shutter',
                  icon: PhosphorIcons.camera(),
                  onPressed: _cameraKey.currentState?.canCapture == true
                      ? () => _cameraKey.currentState?.triggerCapture()
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _navigateToSummary(
    TimesheetMatchAttendanceResult match,
    AttendanceCaptureDraft draft,
  ) {
    final capture = widget.capture;
    final workerId = capture.targetWorkerId ?? match.workerId;
    final rowName = capture.targetWorkerName ??
        _displayNameForWorker(workerId) ??
        'Unknown worker';

    Navigator.of(context).pushNamed(
      TimesheetRouteNames.captureSummary,
      arguments: TimesheetCaptureSummaryArgs(
        capture: capture,
        mode: capture.mode,
        draftId: draft.id,
        rows: [
          TimesheetCaptureSummaryRow(
            name: rowName,
            status: match.result,
            score: '${match.similarity.toStringAsFixed(1)}%',
            outsideGeofence: match.outsideGeofence,
            workerId: workerId,
            odooEmployeeId: capture.targetEmployeeOdooId,
            draftId: draft.id,
          ),
        ],
      ),
    );
  }

  String? _displayNameForWorker(String? workerId) {
    switch (workerId) {
      case 'w_ahmed':
        return 'Ahmed Khan';
      case 'w_bilal':
        return 'Bilal Ali';
      case 'w_carlos':
        return 'Carlos Rodriguez';
      case null:
        return null;
      default:
        return workerId;
    }
  }
}
