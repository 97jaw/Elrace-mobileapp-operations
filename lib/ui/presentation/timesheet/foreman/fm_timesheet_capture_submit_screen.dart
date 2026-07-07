import 'dart:async';

import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_submit_request.dart';
import 'package:el_race/core/timesheet/network/timesheet_functions_client.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/core/timesheet/providers/timesheet_hr_scope_provider.dart';
import 'package:el_race/core/timesheet/providers/timesheet_role_provider.dart';
import 'package:el_race/core/timesheet/services/capture_queue_service.dart';
import 'package:el_race/core/site_management/face_recognition/data/repositories/face_db_repository.dart';
import 'package:el_race/core/site_management/face_recognition/face_match_session.dart';
import 'package:el_race/core/site_management/face_recognition/face_pilot_log_store.dart';
import 'package:el_race/core/timesheet/services/timesheet_roster_face_matcher.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/core/widgets/timesheet/tm_marquee_text.dart';
import 'package:el_race/ui/presentation/timesheet/foreman/attendance/timesheet_capture_camera_panel.dart';
import 'package:el_race/ui/presentation/timesheet/models/timesheet_capture_session_entry.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_route_args.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/face_recognition/tm_face_capture_status_icon_row.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/face_recognition/tm_face_capture_notice_tile.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/timesheet_liveness_gate.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/face_recognition/tm_face_db_fallback_banner.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/face_recognition/tm_liveness_overlay.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/face_recognition/tm_face_no_match_notice.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/face_recognition/tm_timesheet_capture_confirm_sheet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Full-screen camera with overlays (Add timesheet).
class FmTimesheetCaptureSubmitScreen extends ConsumerStatefulWidget {
  const FmTimesheetCaptureSubmitScreen({
    super.key,
    required this.args,
  });

  final TimesheetProjectDayArgs args;

  @override
  ConsumerState<FmTimesheetCaptureSubmitScreen> createState() =>
      _FmTimesheetCaptureSubmitScreenState();
}

class _FmTimesheetCaptureSubmitScreenState
    extends ConsumerState<FmTimesheetCaptureSubmitScreen> {
  final GlobalKey<TimesheetCaptureCameraPanelState> _cameraKey =
      GlobalKey<TimesheetCaptureCameraPanelState>();

  List<TimesheetOdooEmployee> _employees = const [];
  List<TimesheetOdooEmployee> _faceMatchRoster = const [];
  final List<TimesheetCaptureSessionEntry> _captures = [];
  TimesheetFaceOverlayHint? _overlayHint;
  TimesheetCaptureNoticeToast? _noticeToast;
  bool _showNoMatchNotice = false;
  double? _noMatchBestScore;
  String? _noMatchClosestName;
  TimesheetCaptureChromeSnapshot? _chrome;
  late DateTime _startDateTime;
  late DateTime _endDateTime;
  int _breakHours = 1;
  bool _isSubmitting = false;
  bool _phaseBActive = false;
  bool _faceDbReady = false;
  int _faceDbTemplateCount = 0;
  bool _faceDbRefreshing = false;
  FaceRecognitionAvailability _availability =
      FaceRecognitionAvailability.notInitialized;
  Timer? _overlayClearTimer;

  Set<int> get _capturedEmployeeIds =>
      _captures.map((e) => e.employeeId).toSet();

  Set<int> get _projectLaborEmployeeIds =>
      _employees.map((e) => e.employeeId).toSet();

  TimesheetCaptureArgs get _captureArgs => TimesheetCaptureArgs(
        projectId: widget.args.projectId,
        taskId: widget.args.taskId,
        taskName: widget.args.taskName,
        workDate: widget.args.date,
        event: 'checkIn',
      );

  @override
  void initState() {
    super.initState();
    final day = widget.args.date;
    final now = DateTime.now();
    _startDateTime = DateTime(day.year, day.month, day.day, now.hour, now.minute)
        .subtract(const Duration(hours: 9));
    _endDateTime = DateTime(day.year, day.month, day.day, now.hour, now.minute);
    unawaited(_bootCapture());
  }

  @override
  void dispose() {
    _overlayClearTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootCapture() async {
    final result = await ref.read(faceDbSyncProvider.future);
    if (!mounted) return;
    _applySyncResult(result);
    await _loadEmployees();
  }

  Future<void> _refreshFaceDb() async {
    if (_faceDbRefreshing) return;
    setState(() => _faceDbRefreshing = true);
    try {
      final result =
          await ref.read(faceRecognitionServiceProvider).syncFaceDbForceRefresh();
      if (!mounted) return;
      _applySyncResult(result, manualRefresh: true);
    } finally {
      if (mounted) setState(() => _faceDbRefreshing = false);
    }
  }

  void _applySyncResult(FaceSyncResult result, {bool manualRefresh = false}) {
    final service = ref.read(faceRecognitionServiceProvider);
    final countSuffix =
        result.count > 0 ? ' · ${result.count} templates' : '';
    final prefix = switch (result.status) {
      FaceSyncStatus.synced => manualRefresh
          ? 'Face DB reloaded$countSuffix'
          : 'Face DB updated$countSuffix',
      FaceSyncStatus.upToDate => manualRefresh
          ? 'Face DB checked$countSuffix'
          : 'Face DB ready$countSuffix',
      FaceSyncStatus.failed when result.message?.startsWith('offline_cache') ==
              true =>
        'Face DB offline$countSuffix',
      FaceSyncStatus.failed => 'Face DB sync failed',
      FaceSyncStatus.empty => 'No enrolled faces on server',
    };
    final phaseB = service.isReady ? 'Phase B on' : 'Phase B off';
    var snackText = '$prefix ($phaseB)';
    if (kDebugMode && FacePilotLogStore.lastExportPath != null) {
      snackText =
          '$snackText · pilot log: ${FacePilotLogStore.lastExportPath}';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(snackText),
        duration: const Duration(seconds: 5),
      ),
    );
    setState(() {
      _phaseBActive = service.isReady;
      _faceDbReady = service.isReady ||
          result.status == FaceSyncStatus.synced ||
          result.status == FaceSyncStatus.upToDate;
      _faceDbTemplateCount = result.count;
      _availability = service.availability;
    });
  }

  Future<void> _loadEmployees() async {
    final client = ref.read(timesheetApiClientProvider);
    List<TimesheetOdooEmployee> labors;
    try {
      labors = await client.fetchLaborEmployeesForReport(
        projectId: widget.args.projectId,
        includeDrivers: true,
        useHrScopeWhenNoProject: false,
      );
    } catch (e) {
      debugPrint('FmTimesheetCaptureSubmit: labor_list failed: $e');
      final scope = await ref.read(timesheetHrScopeProvider.future);
      final roster = await client.fetchEmployeeRoster();
      labors = scope.hasLaborScope
          ? roster
              .where((e) => scope.laborEmployeeIds.contains(e.employeeId))
              .toList()
          : roster;
    }

    final faceRoster = _phaseBActive
        ? const <TimesheetOdooEmployee>[]
        : labors.where((e) => e.canUseFaceMatch).toList(growable: false);

    if (!_phaseBActive && faceRoster.isNotEmpty) {
      final token = SharedPref.getLoginData().result?.token?.trim();
      final headers = (token != null && token.isNotEmpty)
          ? {'Authorization': 'Bearer $token'}
          : null;
      unawaited(
        TimesheetRosterFaceMatcher().warmReferences(
          roster: faceRoster,
          httpHeaders: headers,
        ),
      );
    }

    if (!mounted) return;
    final deduped = dedupeTimesheetEmployeesById(labors);
    setState(() {
      _employees = deduped;
      _faceMatchRoster = faceRoster;
    });
    debugPrint(
      'FmTimesheetCaptureSubmit: project labor_list loaded ${deduped.length} employees',
    );
  }

  void _setOverlayHint(TimesheetFaceOverlayHint? hint, {Duration? hold}) {
    _overlayClearTimer?.cancel();
    setState(() => _overlayHint = hint);
    if (hint != null && hold != null) {
      _overlayClearTimer = Timer(hold, () {
        if (mounted) setState(() => _overlayHint = null);
      });
    }
  }

  void _showCaptureNotice(
    TimesheetOdooEmployee employee,
    TmFaceCaptureNoticeKind kind, {
    double? matchScore,
  }) {
    setState(() {
      _noticeToast = TimesheetCaptureNoticeToast(
        employee: employee,
        kind: kind,
        matchScore: matchScore,
      );
    });
  }

  void _clearNoticeToast() {
    if (!mounted) return;
    setState(() => _noticeToast = null);
  }

  /// Labor row with HR photo — only when employee is on project labor_list.
  TimesheetOdooEmployee? _laborEmployeeOrNull(TimesheetOdooEmployee employee) =>
      timesheetEmployeeForDropdown(employee, _employees);

  void _onRosterMatched(
    TimesheetOdooEmployee employee,
    AttendanceCaptureDraft draft,
    double matchScore, {
    double secondBestScore = 0,
    bool closeSecondCandidate = false,
  }) {
    final resolved = _laborEmployeeOrNull(employee);
    if (resolved == null) {
      _onOutOfTeamRecognized(employee, draft, matchScore);
      return;
    }

    ref.read(faceMatchSessionProvider.notifier).record(
          FaceMatchSessionRecord(
            outcome: FaceMatchUiOutcome.inTeam,
            bestScore: matchScore,
            secondBestScore: secondBestScore,
            employeeId: resolved.employeeId,
            employeeName: resolved.name,
            inForemanTeam: true,
            capturedAt: DateTime.now(),
          ),
        );
    ref.read(faceMatchSessionProvider.notifier).markConfirmed();
  _setOverlayHint(
      TimesheetFaceOverlayHint.inTeam(
        name: resolved.name,
        fileId: resolved.displayFileId,
      ),
      hold: const Duration(seconds: 3),
    );
    setState(() {
      _showNoMatchNotice = false;
      _captures.add(
        TimesheetCaptureSessionEntry(
          employee: resolved,
          matchScore: matchScore,
          draft: draft,
          capturedAt: DateTime.now(),
        ),
      );
    });
    _showCaptureNotice(
      resolved,
      TmFaceCaptureNoticeKind.captured,
      matchScore: matchScore,
    );
    if (closeSecondCandidate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Another labor is nearly as close '
            '(${(secondBestScore * 100).toStringAsFixed(0)}%). '
            'Verify identity if unsure.',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _onAlreadyAttended(TimesheetOdooEmployee employee) {
    final resolved = _laborEmployeeOrNull(employee) ?? employee;
    _showCaptureNotice(resolved, TmFaceCaptureNoticeKind.alreadyAttended);
    debugPrint('FaceCaptureSession: already attended emp=${resolved.employeeId}');
  }

  void _onOutOfTeamRecognized(
    TimesheetOdooEmployee employee,
    AttendanceCaptureDraft _,
    double matchScore,
  ) {
    ref.read(faceMatchSessionProvider.notifier).record(
          FaceMatchSessionRecord(
            outcome: FaceMatchUiOutcome.outOfTeam,
            bestScore: matchScore,
            secondBestScore: matchScore,
            employeeId: employee.employeeId,
            employeeName: employee.name,
            capturedAt: DateTime.now(),
          ),
        );
    _clearNoticeToast();
    _setOverlayHint(
      TimesheetFaceOverlayHint.outOfTeam(
        name: employee.name,
        fileId: employee.displayFileId,
      ),
      hold: const Duration(seconds: 3),
    );
    setState(() => _showNoMatchNotice = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${employee.name} is not on this project labor list — cannot add to timesheet.',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _onNoEmbeddingMatch(
    AttendanceCaptureDraft _, {
    double? bestScore,
    String? closestName,
  }) {
    ref.read(faceMatchSessionProvider.notifier).record(
          FaceMatchSessionRecord(
            outcome: FaceMatchUiOutcome.belowThreshold,
            bestScore: bestScore ?? 0,
            secondBestScore: 0,
            employeeName: closestName,
            capturedAt: DateTime.now(),
          ),
        );
    setState(() {
      _showNoMatchNotice = true;
      _noMatchBestScore = bestScore;
      _noMatchClosestName = closestName;
      _overlayHint = null;
    });
  }

  void _dismissNoMatch() {
    setState(() => _showNoMatchNotice = false);
  }

  void _onCaptureMatched(
    TimesheetMatchAttendanceResult match,
    AttendanceCaptureDraft draft,
  ) {
    final workerId = match.workerId;
    if (workerId == null) return;

    int? employeeId;
    if (workerId.startsWith('emp_')) {
      employeeId = int.tryParse(workerId.substring(4));
    } else {
      employeeId = int.tryParse(workerId);
    }

    TimesheetOdooEmployee? picked;
    final searchIn = [..._employees, ..._faceMatchRoster];
    if (employeeId != null) {
      for (final member in searchIn) {
        if (member.employeeId == employeeId) {
          picked = member;
          break;
        }
      }
    }
    if (picked == null) return;
    if (_capturedEmployeeIds.contains(picked.employeeId)) {
      _onAlreadyAttended(picked);
      return;
    }
    _onRosterMatched(picked, draft, 0);
  }

  void _onChromeChanged(TimesheetCaptureChromeSnapshot chrome) {
    if (!mounted) return;
    setState(() => _chrome = chrome);
  }

  Future<void> _submit() async {
    if (_captures.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Capture at least one employee face first'),
        ),
      );
      return;
    }

    final confirmed = await TmTimesheetCaptureConfirmSheet.show(
      context,
      captures: List.unmodifiable(_captures),
      startDateTime: _startDateTime,
      endDateTime: _endDateTime,
      breakHours: _breakHours,
      onStartChanged: (v) => _startDateTime = v,
      onEndChanged: (v) => _endDateTime = v,
      onBreakChanged: (v) => _breakHours = v,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final client = ref.read(timesheetApiClientProvider);
      final ids = _captures.map((e) => e.employeeId).toList(growable: false);
      final names = _captures.map((e) => e.employee.name).join(', ');
      final result = await client.submitTimesheet(
        TimesheetSubmitRequest(
          projectId: widget.args.projectId,
          taskId: widget.args.taskId,
          employeeIds: ids,
          employeeName: names,
          date: widget.args.date,
          dateTime: _startDateTime,
          dateTimeEnd: _endDateTime,
          breakTimeHours: _breakHours,
        ),
      );
      if (!mounted) return;
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Timesheet submitted')),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Submission failed')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolution = ref.watch(tmRoleResolutionProvider);
    if (!resolution.canSubmitTimesheet) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add timesheet')),
        body: const Center(
          child: Text('Only foremen can submit timesheets for their labors.'),
        ),
      );
    }

    final dateLabel = DateFormat('EEE, dd MMM yyyy').format(widget.args.date);
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final chrome = _chrome;
    final camera = _cameraKey.currentState;
    final headerTop = topPad + 52;
    final captureCount = _captures.length;
    final notice = _noticeToast;

    return Scaffold(
      backgroundColor: TimesheetModuleColors.navy,
      body: Stack(
        fit: StackFit.expand,
        children: [
          TimesheetCaptureCameraPanel(
            key: _cameraKey,
            capture: _captureArgs,
            showShutter: false,
            fillHeight: true,
            externalChrome: true,
            autoCaptureEnabled: true,
            overlayHint: _overlayHint,
            capturedEmployeeIds: _capturedEmployeeIds,
            projectLaborEmployeeIds: _projectLaborEmployeeIds,
            rosterEmployees: _faceMatchRoster,
            faceRecognition: ref.read(faceRecognitionServiceProvider),
            onRosterEmployeeMatched: _onRosterMatched,
            onAlreadyAttended: _onAlreadyAttended,
            onOutOfTeamRecognized: _onOutOfTeamRecognized,
            onNoEmbeddingMatch: _onNoEmbeddingMatch,
            onCaptureMatched: _onCaptureMatched,
            onChromeChanged: _onChromeChanged,
          ),
          const Positioned(top: 0, left: 0, right: 0, child: _NavyTitleBar()),
          Positioned(
            top: headerTop,
            left: 10,
            right: 10,
            child: _CaptureProjectHeader(
              projectName: widget.args.projectName,
              taskName: widget.args.taskName,
              dateLabel: dateLabel,
            ),
          ),
          Positioned(
            top: headerTop + 88,
            right: 10,
            child: _CaptureCameraRail(
              chrome: chrome,
              onFlip: camera?.switchCameraExternal,
              onFlash: camera?.toggleFlashExternal,
              onCapture: camera?.capturePhoto,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TmFaceDbFallbackBanner(
                  availability: _availability,
                  phaseAFallback:
                      !_phaseBActive && _faceMatchRoster.isNotEmpty,
                ),
                if (chrome?.livenessShowSpoofWarning == true)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: TmLivenessBlockedBanner(
                      message: chrome?.livenessMessage?.trim().isNotEmpty == true
                          ? chrome!.livenessMessage!.trim()
                          : 'Live face verification failed.',
                      onRetry: camera?.retryLivenessSpoofExternal,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: TmFaceCaptureStatusIconRow(
                    embeddingOn: _phaseBActive,
                    faceDbReady: _faceDbReady,
                    faceDbTemplateCount: _faceDbTemplateCount,
                    onRefreshFaceDb: _refreshFaceDb,
                    refreshingFaceDb: _faceDbRefreshing,
                    geofenceOk: chrome?.geofenceOk == true,
                    canCapture: chrome?.canCapture == true,
                    livenessPhase: chrome?.livenessPhase ?? LivenessGatePhase.idle,
                    livenessMessage: chrome?.livenessMessage,
                    onRetryLiveness: chrome?.livenessShowSpoofWarning == true
                        ? camera?.retryLivenessSpoofExternal
                        : null,
                  ),
                ),
                _CaptureSubmitBar(
                  captureCount: captureCount,
                  isSubmitting: _isSubmitting,
                  bottomInset: bottomInset,
                  onSubmit: _submit,
                ),
              ],
            ),
          ),
          if (notice != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: bottomInset + 132,
              child: TmFaceCaptureNoticeTile(
                key: ValueKey(
                  '${notice.employee.employeeId}_${notice.kind.name}',
                ),
                employee: notice.employee,
                kind: notice.kind,
                matchScore: notice.matchScore,
                onDismissed: _clearNoticeToast,
              ),
            ),
          if (_showNoMatchNotice)
            TmFaceNoMatchNotice(
              bestScore: _noMatchBestScore,
              suspectedName: _noMatchClosestName,
              onDismiss: _dismissNoMatch,
            ),
        ],
      ),
    );
  }
}

class TimesheetCaptureNoticeToast {
  const TimesheetCaptureNoticeToast({
    required this.employee,
    required this.kind,
    this.matchScore,
  });

  final TimesheetOdooEmployee employee;
  final TmFaceCaptureNoticeKind kind;
  final double? matchScore;
}

/// Only the title row gets navy gradient; everything else floats on camera.
class _NavyTitleBar extends StatelessWidget {
  const _NavyTitleBar();

  @override
  Widget build(BuildContext context) {
    final faded = TimesheetModuleColors.surface.withValues(alpha: 0.9);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            TimesheetModuleColors.navy,
            TimesheetModuleColors.navy.withValues(alpha: 0.92),
            TimesheetModuleColors.navy.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.65, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: Icon(PhosphorIcons.caretLeft(), color: faded),
                tooltip: 'Back',
              ),
              Expanded(
                child: Text(
                  'Add timesheet',
                  textAlign: TextAlign.center,
                  style: TimesheetModuleTypography.h2().copyWith(
                    color: faded,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptureProjectHeader extends StatelessWidget {
  const _CaptureProjectHeader({
    required this.projectName,
    required this.taskName,
    required this.dateLabel,
  });

  final String projectName;
  final String taskName;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              TmMarqueeText(
                text: projectName,
                height: 22,
                style: TimesheetModuleTypography.cardTitle().copyWith(
                  color: TimesheetModuleColors.surface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                taskName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TimesheetModuleTypography.caption().copyWith(
                  color: TimesheetModuleColors.surface.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dateLabel,
                textAlign: TextAlign.center,
                style: TimesheetModuleTypography.caption().copyWith(
                  color: TimesheetModuleColors.surface.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptureCameraRail extends StatelessWidget {
  const _CaptureCameraRail({
    required this.chrome,
    required this.onFlip,
    required this.onFlash,
    required this.onCapture,
  });

  final TimesheetCaptureChromeSnapshot? chrome;
  final Future<void> Function()? onFlip;
  final Future<void> Function()? onFlash;
  final Future<void> Function()? onCapture;

  @override
  Widget build(BuildContext context) {
    final c = chrome;
    final canCapture = c?.canCapture == true && c?.permissionsReady == true;
    final isCapturing = c?.isCapturing == true;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RailIconButton(
          icon: PhosphorIcons.cameraRotate(),
          tooltip: 'Switch camera',
          onPressed: onFlip,
        ),
        _RailIconButton(
          icon: PhosphorIcons.lightning(),
          tooltip: 'Flash',
          onPressed: onFlash,
        ),
        const SizedBox(height: 12),
        Material(
          elevation: 4,
          color: canCapture && !isCapturing
              ? TimesheetModuleColors.primary
              : TimesheetModuleColors.primary.withValues(alpha: 0.45),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: canCapture && !isCapturing ? onCapture : null,
            child: SizedBox(
              width: 56,
              height: 56,
              child: isCapturing
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(PhosphorIcons.camera(), color: Colors.white, size: 28),
            ),
          ),
        ),
      ],
    );
  }
}

class _RailIconButton extends StatelessWidget {
  const _RailIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed == null ? null : () => onPressed!(),
        icon: Icon(icon, color: TimesheetModuleColors.surface, size: 22),
      ),
    );
  }
}

class _CaptureSubmitBar extends StatelessWidget {
  const _CaptureSubmitBar({
    required this.captureCount,
    required this.isSubmitting,
    required this.bottomInset,
    required this.onSubmit,
  });

  final int captureCount;
  final bool isSubmitting;
  final double bottomInset;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final label = captureCount == 0
        ? 'Submit timesheet'
        : 'Submit timesheet ($captureCount)';

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.55),
            Colors.black.withValues(alpha: 0.78),
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 10, 14, 10 + bottomInset),
        child: TmPrimaryButton(
          label: isSubmitting ? 'Submitting…' : label,
          icon: PhosphorIcons.paperPlaneTilt(),
          onPressed: isSubmitting ? null : onSubmit,
        ),
      ),
    );
  }
}
