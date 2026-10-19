import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_models.dart';
import 'package:el_race/core/timesheet/models/timesheet_submit_request.dart';
import 'package:el_race/core/timesheet/models/timesheet_team_member.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';
import 'package:el_race/core/timesheet/providers/timesheet_acting_session_provider.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/core/timesheet/services/tm_project_location_notify_service.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_submit_geofence_dialog.dart';
import 'package:el_race/core/timesheet/providers/timesheet_hr_scope_provider.dart';
import 'package:el_race/core/timesheet/providers/timesheet_role_provider.dart';
import 'package:el_race/core/timesheet/services/capture_queue_service.dart';
import 'package:el_race/core/timesheet/services/timesheet_acting_guard.dart';
import 'package:el_race/core/timesheet/services/timesheet_capture_session_store.dart';
import 'package:el_race/core/site_management/face_recognition/data/repositories/face_db_repository.dart';
import 'package:el_race/core/site_management/face_recognition/domain/face_verifier.dart';
import 'package:el_race/core/site_management/face_recognition/domain/face_walkup.dart';
import 'package:el_race/ui/presentation/task_sheet/EmployeeShiftRequestPage.dart';
import 'package:el_race/core/site_management/face_recognition/face_match_session.dart';
import 'package:el_race/core/site_management/face_recognition/face_min_device_check.dart';
import 'package:el_race/core/site_management/face_recognition/face_pilot_log_store.dart';
import 'package:el_race/core/site_management/face_recognition/profile_photo_face_db.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_fast_network_image.dart';
import 'package:el_race/core/timesheet/services/timesheet_roster_face_matcher.dart';
import 'package:el_race/core/utils/app_orientations.dart';
import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/core/widgets/timesheet/tm_marquee_text.dart';
import 'package:el_race/ui/presentation/timesheet/foreman/attendance/timesheet_capture_camera_panel.dart';
import 'package:el_race/ui/presentation/timesheet/models/timesheet_capture_session_entry.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_route_args.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/face_recognition/tm_face_capture_status_icon_row.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/face_recognition/tm_face_capture_notice_tile.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/timesheet_liveness_gate.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/face_recognition/tm_liveness_overlay.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/face_recognition/tm_timesheet_capture_confirm_sheet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Full-screen camera with overlays (Add timesheet).
class FmTimesheetCaptureSubmitScreen extends ConsumerStatefulWidget {
  const FmTimesheetCaptureSubmitScreen({
    super.key,
    required this.args,
    this.returnCaptures = false,
    this.expectedEmployeeId,
    this.expectedEmployeeName,
    this.alreadyCapturedEmployeeIds = const {},
    this.walkUpMode = false,
    this.onSessionCapturesChanged,
    this.teamEmployeeIds = const {},
  });

  static bool _opening = false;

  /// Pushes this screen unless one is already open. Repeated taps while the
  /// camera route is opening otherwise stack several cameras, each loading
  /// labor_list, permissions and the face DB again.
  static Future<T?> pushOnce<T>(
    BuildContext context,
    FmTimesheetCaptureSubmitScreen screen,
  ) async {
    if (_opening) {
      debugPrint('FmCapture: duplicate open ignored');
      return null;
    }
    _opening = true;
    try {
      return await Navigator.of(context).push<T>(
        MaterialPageRoute(builder: (_) => screen),
      );
    } finally {
      _opening = false;
    }
  }

  final TimesheetProjectDayArgs args;

  /// Your Team sheet: the labor this camera verifies (1:1). Null = no labor
  /// selected; nothing is verified or captured.
  final int? expectedEmployeeId;
  final String? expectedEmployeeName;

  /// Labors already captured by the caller (pending in the Your Team sheet),
  /// so they show as "already added" instead of a fresh green match.
  final Set<int> alreadyCapturedEmployeeIds;

  /// When true, the screen does not submit itself. After the first successful
  /// face capture it pops, returning the captured entries so the caller (the
  /// Your Team sheet) can accumulate them and drive the confirm/submit flow.
  final bool returnCaptures;

  /// TASK 10 walk-up: auto-identify Your Team (no picker strip / target).
  /// Labor camera (expectedEmployeeId set) must keep this false.
  final bool walkUpMode;

  /// Walk-up: notify the Your Team sheet on each accept/undo so ticks update
  /// while this route is still open (same pending list as verify).
  final ValueChanged<List<TimesheetCaptureSessionEntry>>?
      onSessionCapturesChanged;

  /// Your Team [TimesheetTeamMember.employeeId]s — for tick-key logging.
  final Set<int> teamEmployeeIds;

  @override
  ConsumerState<FmTimesheetCaptureSubmitScreen> createState() =>
      _FmTimesheetCaptureSubmitScreenState();
}

class _FmTimesheetCaptureSubmitScreenState
    extends ConsumerState<FmTimesheetCaptureSubmitScreen>
    with CapturePortraitLock<FmTimesheetCaptureSubmitScreen> {
  final GlobalKey<TimesheetCaptureCameraPanelState> _cameraKey =
      GlobalKey<TimesheetCaptureCameraPanelState>();

  List<TimesheetOdooEmployee> _employees = const [];
  final List<TimesheetCaptureSessionEntry> _captures = [];
  TimesheetFaceOverlayHint? _overlayHint;
  TimesheetCaptureNoticeToast? _noticeToast;
  int _noticeSeq = 0;
  TimesheetCaptureChromeSnapshot? _chrome;
  late DateTime _startDateTime;
  late DateTime _endDateTime;
  int _breakHours = 1;
  bool _isSubmitting = false;
  bool _phaseBActive = false;
  bool _faceDbReady = false;
  int _faceDbTemplateCount = 0;
  bool _faceDbRefreshing = false;
  Timer? _overlayClearTimer;
  Timer? _returnTimer;
  bool _returning = false;

  /// Project camera: Your Team labors on this project, labor list order.
  List<TimesheetOdooEmployee> _pickerLabour = const [];
  bool _pickerLoaded = false;
  int _walkUpTeamCount = 0;
  int? _pickedEmployeeId;
  Timer? _advanceTimer;
  final ScrollController _pickerScroll = ScrollController();

  /// Matches [TmFaceCaptureNoticeTile]'s green card display time.
  static const Duration _autoAdvanceDelay = Duration(seconds: 3);

  /// Opened without a labor (day hub / project dates): picker strip.
  /// Walk-up uses no strip (Addendum B / TASK 10 §5).
  bool get _projectMode =>
      widget.expectedEmployeeId == null && !widget.walkUpMode;

  bool get _walkUpMode => widget.walkUpMode;

  bool get _allPickerCaptured =>
      _pickerLoaded &&
      _pickerLabour.isNotEmpty &&
      _pickerLabour.every((e) => _capturedEmployeeIds.contains(e.employeeId));

  Set<int> get _capturedEmployeeIds => {
        ...widget.alreadyCapturedEmployeeIds,
        ..._captures.map((e) => e.employeeId),
      };

  Set<int> get _projectLaborEmployeeIds =>
      _employees.map((e) => e.employeeId).toSet();

  /// The labor this camera verifies (1:1): walk-up pick target, project strip
  /// pick, or the caller's expected labor.
  TimesheetOdooEmployee? get _targetEmployee {
    if (_walkUpMode) return _walkUpPickVerifyTarget;
    if (_projectMode) {
      final picked = _pickedEmployeeId;
      if (picked == null) return null;
      for (final e in _pickerLabour) {
        if (e.employeeId == picked) return e;
      }
      return null;
    }
    final id = widget.expectedEmployeeId;
    if (id == null) return null;
    for (final e in _employees) {
      if (e.employeeId == id) return e;
    }
    final name = widget.expectedEmployeeName?.trim();
    return TimesheetOdooEmployee(
      id: id,
      employeeId: id,
      name: name == null || name.isEmpty ? 'Selected labor' : name,
    );
  }

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
    _startDateTime =
        DateTime(day.year, day.month, day.day, now.hour, now.minute)
            .subtract(const Duration(hours: 9));
    _endDateTime = DateTime(day.year, day.month, day.day, now.hour, now.minute);
    debugPrint('FmCapture: boot screen=${identityHashCode(this)}');
    unawaited(_bootCapture());
  }

  @override
  void dispose() {
    _overlayClearTimer?.cancel();
    _returnTimer?.cancel();
    _advanceTimer?.cancel();
    _pickerScroll.dispose();
    super.dispose();
  }

  Future<void> _bootCapture() async {
    // Block before the camera opens (verify + walk-up).
    if (!mounted) return;
    final deviceOk = await FaceMinDeviceCheck.ensureSupported(context);
    if (!deviceOk) {
      if (mounted) Navigator.of(context).maybePop();
      return;
    }
    // In return-captures mode the caller owns the accumulated session, so we
    // don't restore/merge the shared persisted session here.
    if (!widget.returnCaptures) {
      final restored =
          await TimesheetCaptureSessionStore.loadMatching(widget.args);
      if (restored != null && mounted && restored.captures.isNotEmpty) {
        setState(() => _captures.addAll(restored.captures));
      }
    }
    // Re-check the face DB version on every open: labors enrolled earlier in
    // this session must be matchable, or their faces fall to whoever is cached.
    final result = await ref.refresh(faceDbSyncProvider.future);
    if (!mounted) return;
    final expected = widget.expectedEmployeeId;
    if (expected != null) {
      // Version check can miss a just-enrolled labor; pull templates if absent.
      await ref
          .read(faceRecognitionServiceProvider)
          .ensureTemplatesFor(expected);
      if (!mounted) return;
    }
    _applySyncResult(result);
    await _loadEmployees();
  }

  Future<void> _persistSession() async {
    await TimesheetCaptureSessionStore.save(
      args: widget.args,
      captures: List.unmodifiable(_captures),
    );
  }

  Future<bool> _confirmLeaveIfNeeded() async {
    if (_captures.isEmpty) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved attendance'),
        content: Text(
          'You have ${_captures.length} captured face(s) that are not submitted yet. '
          'Leave without submitting? You will need to capture again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave == true) {
      await TimesheetCaptureSessionStore.clear();
      return true;
    }
    return false;
  }

  Future<void> _refreshFaceDb() async {
    if (_faceDbRefreshing) return;
    setState(() => _faceDbRefreshing = true);
    try {
      final result = await ref
          .read(faceRecognitionServiceProvider)
          .syncFaceDbForceRefresh();
      if (!mounted) return;
      _applySyncResult(result, manualRefresh: true);
    } finally {
      if (mounted) setState(() => _faceDbRefreshing = false);
    }
  }

  void _applySyncResult(FaceSyncResult result, {bool manualRefresh = false}) {
    final service = ref.read(faceRecognitionServiceProvider);
    final countSuffix = result.count > 0 ? ' · ${result.count} templates' : '';
    final prefix = switch (result.status) {
      FaceSyncStatus.synced => manualRefresh
          ? 'Face DB reloaded$countSuffix'
          : 'Face DB updated$countSuffix',
      FaceSyncStatus.upToDate => manualRefresh
          ? 'Face DB checked$countSuffix'
          : 'Face DB ready$countSuffix',
      FaceSyncStatus.failed
          when result.message?.startsWith('offline_cache') == true =>
        'Face DB offline$countSuffix',
      FaceSyncStatus.failed => 'Face DB sync failed',
      FaceSyncStatus.empty => 'No enrolled faces on server',
    };
    final phaseB = service.isReady ? 'Phase B on' : 'Phase B off';
    var snackText = '$prefix ($phaseB)';
    // Surface the real engine failure so release/TestFlight builds are
    // diagnosable (otherwise only a generic "Face engine unavailable" shows).
    if (service.availability == FaceRecognitionAvailability.engineFailed &&
        service.engineError != null) {
      snackText = '$snackText · engine: ${service.engineError}';
    }
    if (kDebugMode && FacePilotLogStore.lastExportPath != null) {
      snackText = '$snackText · pilot log: ${FacePilotLogStore.lastExportPath}';
    }
    // Opening the camera is silent; only a manual ↻ reload confirms itself.
    debugPrint('FmCapture: $snackText');
    if (manualRefresh) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(snackText),
          duration: const Duration(seconds: 5),
        ),
      );
    }
    setState(() {
      _phaseBActive = service.isReady;
      _faceDbReady = service.isReady ||
          result.status == FaceSyncStatus.synced ||
          result.status == FaceSyncStatus.upToDate;
      _faceDbTemplateCount = result.count;
    });
  }

  Future<void> _loadEmployees() async {
    final client = ref.read(timesheetApiClientProvider);
    // Every camera open: refresh HR scope + Your Team from network.
    ref.invalidate(timesheetHrScopeProvider);
    ref.invalidate(timesheetForemanLaborsProvider);
    var fromNetwork = true;
    List<TimesheetOdooEmployee> labors;
    try {
      labors = await client.fetchLaborEmployeesForReport(
        projectId: widget.args.projectId,
        includeDrivers: true,
        useHrScopeWhenNoProject: false,
      );
    } catch (e) {
      fromNetwork = false;
      debugPrint('FmTimesheetCaptureSubmit: labor_list failed: $e');
      try {
        final scope = await ref.read(timesheetHrScopeProvider.future);
        final roster = await client.fetchEmployeeRoster();
        labors = scope.hasLaborScope
            ? roster
                .where((e) => scope.laborEmployeeIds.contains(e.employeeId))
                .toList()
            : roster;
      } catch (e2) {
        debugPrint('FmTimesheetCaptureSubmit: roster fallback failed: $e2');
        labors = _employees;
      }
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
    await _applyYourTeam(deduped, fromNetwork: fromNetwork);
    if (!mounted) return;
    setState(() {
      _employees = deduped;
    });
    debugPrint(
      'FmTimesheetCaptureSubmit: project labor_list loaded ${deduped.length} employees',
    );
  }

  /// Loads Your Team for the profile-photo roster and the picker strip.
  /// Forces a network refresh on every camera open (cache only if offline).
  Future<void> _applyYourTeam(
    List<TimesheetOdooEmployee> projectLabour, {
    required bool fromNetwork,
  }) async {
    List<TimesheetTeamMember> team;
    try {
      team = await ref.refresh(timesheetForemanLaborsProvider.future);
    } catch (e) {
      fromNetwork = false;
      debugPrint('ProfilePhotoMatch: Your Team load failed: $e');
      team = const [];
    }
    if (!mounted) return;
    final teamOnly = ProfilePhotoFaceDb.yourTeamOnly(projectLabour, team);
    if (ProfilePhotoMatchTest.enabled) {
      // Whole project labour: Your Team are the targets, the rest is the
      // verification cohort. No team (PM login) = everyone is a target.
      final teamCount =
          team.isEmpty ? projectLabour.length : team.length;
      await ProfilePhotoFaceDb.instance.refreshRosterForCameraOpen(
        labour: projectLabour,
        targetIds:
            team.isEmpty ? null : {for (final m in team) m.employeeId},
        teamCount: teamCount,
        fromNetwork: fromNetwork,
      );
    }
    // Picker strip (verify) + Pick labor panel (verify + walk-up): Your Team.
    if (_projectMode || _walkUpMode) {
      setState(() {
        _pickerLabour = teamOnly;
        _pickerLoaded = true;
        if (_walkUpMode) _walkUpTeamCount = teamOnly.length;
      });
      if (_projectMode) _selectTarget(_initialPick(), scroll: true);
    }
  }

  bool _templateReady(int employeeId) =>
      !ProfilePhotoMatchTest.enabled ||
      ProfilePhotoFaceDb.instance.stateOf(employeeId) ==
          ProfileTemplateState.ready;

  /// First uncaptured labor with a ready template, else the first uncaptured.
  int? _initialPick() {
    final open = [
      for (final e in _pickerLabour)
        if (!_capturedEmployeeIds.contains(e.employeeId)) e.employeeId,
    ];
    if (open.isEmpty) return null;
    return open.firstWhere(_templateReady, orElse: () => open.first);
  }

  /// Next uncaptured labor after [afterId] in labor list order, wrapping once.
  int? _nextUncaptured(int? afterId) {
    final list = _pickerLabour;
    if (list.isEmpty) return null;
    final start = list.indexWhere((e) => e.employeeId == afterId);
    for (var i = 1; i <= list.length; i++) {
      final id = list[(start + i) % list.length].employeeId;
      if (id != afterId && !_capturedEmployeeIds.contains(id)) return id;
    }
    return null;
  }

  /// Picker strip / Pick labor order: captured first, remaining below.
  List<TimesheetOdooEmployee> get _pickerOrder => [
        for (final e in _pickerLabour)
          if (_capturedEmployeeIds.contains(e.employeeId)) e,
        for (final e in _pickerLabour)
          if (!_capturedEmployeeIds.contains(e.employeeId)) e,
      ];

  /// Project camera target switch. The panel resets its live state for the
  /// new target without restarting the camera. Captured labors can't be
  /// picked; null clears the target.
  void _selectTarget(int? employeeId, {bool scroll = false}) {
    if (!_projectMode) return;
    if (employeeId != null && _capturedEmployeeIds.contains(employeeId)) {
      return;
    }
    _advanceTimer?.cancel();
    if (employeeId != _pickedEmployeeId) {
      setState(() {
        _pickedEmployeeId = employeeId;
        // A held card belongs to the old target; the panel drops its hold.
        if (_noticeToast?.held == true) _noticeToast = null;
      });
    }
    if (employeeId != null &&
        ProfilePhotoMatchTest.enabled &&
        ProfilePhotoFaceDb.instance.stateOf(employeeId) ==
            ProfileTemplateState.pending) {
      ProfilePhotoFaceDb.instance.prioritize(employeeId);
    }
    if (scroll) _scrollPickerToTarget();
  }

  void _advanceAfterCapture() {
    _advanceTimer?.cancel();
    _advanceTimer = Timer(_autoAdvanceDelay, () {
      if (!mounted) return;
      _selectTarget(_nextUncaptured(_pickedEmployeeId), scroll: true);
    });
  }

  void _scrollPickerToTarget() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pickerScroll.hasClients) return;
      final index =
          _pickerOrder.indexWhere((e) => e.employeeId == _pickedEmployeeId);
      if (index < 0) return;
      final tablet = ResponsiveBreakpoints.useTabletLayout(context);
      final extent = _LaborPickerStrip.itemExtent(tablet);
      final position = _pickerScroll.position;
      final offset =
          (index * extent - (position.viewportDimension - extent) / 2)
              .clamp(0.0, position.maxScrollExtent);
      _pickerScroll.animateTo(
        offset,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  /// "Pick another labor" on the doesn't-match card: dismiss and show the
  /// current target in the strip; the target only changes on a tap.
  void _onPickAnotherLabor() {
    if (!mounted) return;
    setState(() => _noticeToast = null);
    _cameraKey.currentState?.resumeAfterNotice(armAuto: false);
    _scrollPickerToTarget();
  }

  /// "Next labor" on the photo-unavailable card (project camera): the labor
  /// stays uncaptured in the strip.
  void _onSkipToNextLabor() {
    final next = _nextUncaptured(_pickedEmployeeId);
    if (next == null) {
      _clearNoticeToast();
      return;
    }
    _selectTarget(next, scroll: true);
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
    bool held = false,
    bool sticky = false,
  }) {
    final current = _noticeToast;
    if (current != null &&
        current.held &&
        !held &&
        !sticky &&
        kind != TmFaceCaptureNoticeKind.captured) {
      return;
    }
    if ((held || sticky) &&
        current != null &&
        (current.held || current.sticky) &&
        current.kind == kind &&
        current.employee.employeeId == employee.employeeId) {
      return;
    }
    // Verify held cards freeze the camera. Walk-up sticky keeps identify
    // running (stranger clear) but skips PAD-reject on the held person.
    if (held) _cameraKey.currentState?.holdForNotice();
    setState(() {
      _noticeSeq++;
      _noticeToast = TimesheetCaptureNoticeToast(
        employee: employee,
        kind: kind,
        matchScore: matchScore,
        seq: _noticeSeq,
        held: held,
        sticky: sticky,
      );
    });
  }

  void _onWalkUpAlreadySticky(TimesheetOdooEmployee employee) {
    final resolved = _resolveWalkUpEmployee(employee);
    _showCaptureNotice(
      resolved,
      TmFaceCaptureNoticeKind.alreadyAttended,
      sticky: true,
    );
  }

  void _onWalkUpCardCleared() {
    if (!mounted) return;
    final toast = _noticeToast;
    if (toast == null || !toast.sticky) return;
    setState(() => _noticeToast = null);
  }

  /// Still did not verify the target. Cards name the target only.
  void _onTargetVerifyFailed(
    TimesheetOdooEmployee target,
    FaceVerifyResult result,
  ) {
    ref.read(faceMatchSessionProvider.notifier).record(
        FaceMatchSessionRecord.fromVerify(result, targetName: target.name));
    final resolved = _laborEmployeeOrNull(target) ?? target;
    switch (result.outcome) {
      case FaceVerifyOutcome.lowScore:
      case FaceVerifyOutcome.notDistinct:
        _showCaptureNotice(
          resolved,
          TmFaceCaptureNoticeKind.mismatch,
          held: true,
        );
      case FaceVerifyOutcome.noTemplate:
        _showCaptureNotice(
          resolved,
          TmFaceCaptureNoticeKind.photoUnavailable,
          held: true,
        );
      case FaceVerifyOutcome.verified:
      case FaceVerifyOutcome.faceTooSmall:
      case FaceVerifyOutcome.error:
        break;
    }
  }

  /// Photo-unavailable card: the separate manual request flow. Never adds
  /// the labor to this capture list. The camera stays mounted underneath.
  Future<void> _openShiftRequest() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EmployeeShiftRequestPage(
          loginResponseModel: SharedPref.getLoginData(),
          taskId: int.tryParse(widget.args.taskId) ?? 0,
          project_id: int.tryParse(widget.args.projectId) ?? 0,
          selectedDate: widget.args.date,
        ),
      ),
    );
  }

  void _clearNoticeToast() {
    if (!mounted) return;
    final wasHeld = _noticeToast?.held == true;
    setState(() => _noticeToast = null);
    if (wasHeld) _cameraKey.currentState?.resumeAfterNotice();
  }

  /// "Try again" / "Next labor" on a held card: ready the camera for one new
  /// auto capture (full anti-spoof burst runs as usual). On the
  /// photo-unavailable card it first re-runs the template refresh (attempt
  /// limit and cooldown apply).
  Future<void> _onNoticeAction() async {
    if (_noticeToast?.kind == TmFaceCaptureNoticeKind.photoUnavailable) {
      await _cameraKey.currentState?.retryTargetTemplates();
    }
    _clearNoticeToast();
  }

  Future<void> _onManualCapture() async {
    final camera = _cameraKey.currentState;
    if (camera == null) return;
    if (_noticeToast?.held == true) {
      setState(() => _noticeToast = null);
      camera.resumeAfterNotice(armAuto: false);
    }
    await camera.capturePhoto();
  }

  /// Labor row with HR photo — only when employee is on project labor_list.
  TimesheetOdooEmployee? _laborEmployeeOrNull(TimesheetOdooEmployee employee) =>
      timesheetEmployeeForDropdown(employee, _employees);

  /// The still verified the target (the panel already queued the draft).
  void _onTargetVerified(
    TimesheetOdooEmployee target,
    AttendanceCaptureDraft draft,
    FaceVerifyResult result,
  ) {
    final resolved = _laborEmployeeOrNull(target) ?? target;
    if (_capturedEmployeeIds.contains(resolved.employeeId)) {
      _onAlreadyAttended(resolved);
      return;
    }
    final matchScore = result.targetScore ?? 0;
    final fromWalkUpPick = _walkUpPickVerifyTarget != null &&
        _walkUpPickVerifyTarget!.employeeId == resolved.employeeId;

    ref.read(faceMatchSessionProvider.notifier).record(
        FaceMatchSessionRecord.fromVerify(result, targetName: resolved.name));
    ref.read(faceMatchSessionProvider.notifier).markConfirmed();
    _setOverlayHint(
      TimesheetFaceOverlayHint.inTeam(
        name: resolved.name,
        fileId: resolved.displayFileId,
      ),
      hold: const Duration(seconds: 3),
    );
    setState(() {
      _captures.add(
        TimesheetCaptureSessionEntry(
          employee: resolved,
          matchScore: matchScore,
          draft: draft,
          capturedAt: DateTime.now(),
          verifyLead: result.lead,
          verifyCohortSize: result.cohortSize,
          verifyUsedNoCohortBar: result.usedNoCohortBar,
        ),
      );
      if (fromWalkUpPick) {
        _walkUpPickVerifyTarget = null;
      }
    });
    if (fromWalkUpPick) {
      debugPrint(
        'WalkUp: pick_labor emp=${resolved.employeeId} result=success',
      );
      _notifyWalkUpSessionCaptures();
    }
    if (!widget.returnCaptures) {
      unawaited(_persistSession());
    }
    _showCaptureNotice(
      resolved,
      TmFaceCaptureNoticeKind.captured,
      matchScore: matchScore,
    );
    // Per-labor returnCaptures pops after one accept. Walk-up stays open so
    // several team members can walk in; back returns all captures.
    if (widget.returnCaptures && !_walkUpMode) {
      _scheduleReturnWithCaptures();
    }
    if (_projectMode) _advanceAfterCapture();
  }

  /// Prefer labor_list row; else match by employeeId or Odoo id so the sheet
  /// tick key ([TimesheetTeamMember.employeeId]) matches.
  TimesheetOdooEmployee _resolveWalkUpEmployee(TimesheetOdooEmployee raw) {
    final fromLabor = _laborEmployeeOrNull(raw);
    if (fromLabor != null) return fromLabor;
    for (final e in _employees) {
      if (e.employeeId == raw.employeeId ||
          e.id == raw.employeeId ||
          e.employeeId == raw.id ||
          e.id == raw.id) {
        return e;
      }
    }
    return raw;
  }

  void _notifyWalkUpSessionCaptures() {
    widget.onSessionCapturesChanged
        ?.call(List<TimesheetCaptureSessionEntry>.from(_captures));
  }

  /// Walk-up accept (TASK 10): same card/haptic path as verify; method logged
  /// as profile_walkup on the draft.
  void _onWalkUpAccepted(
    TimesheetOdooEmployee employee,
    AttendanceCaptureDraft draft,
    FaceWalkUpResult result,
  ) {
    final resolved = _resolveWalkUpEmployee(employee);
    final key = resolved.employeeId;
    if (_capturedEmployeeIds.contains(key)) {
      _onAlreadyAttended(resolved);
      return;
    }
    final matchScore = result.score ?? 0;
    final listKeys = widget.teamEmployeeIds.isNotEmpty
        ? widget.teamEmployeeIds.take(12).toList()
        : _employees.map((e) => e.employeeId).take(12).toList();
    debugPrint(
      'WalkUp: mark captured emp=${employee.employeeId} '
      'key=$key id=${resolved.id} listKeys=$listKeys',
    );
    setState(() {
      _captures.add(
        TimesheetCaptureSessionEntry(
          employee: resolved,
          matchScore: matchScore,
          draft: draft,
          capturedAt: DateTime.now(),
          verifyLead: result.lead,
          verifyCohortSize: null,
          verifyUsedNoCohortBar: false,
        ),
      );
      _walkUpUndoUntil = DateTime.now().add(const Duration(seconds: 3));
      _walkUpUndoEmployeeId = key;
    });
    _notifyWalkUpSessionCaptures();
    _showCaptureNotice(
      resolved,
      TmFaceCaptureNoticeKind.captured,
      matchScore: matchScore,
      sticky: true,
    );
    _armWalkUpUndoClear();
  }

  DateTime? _walkUpUndoUntil;
  int? _walkUpUndoEmployeeId;
  Timer? _walkUpUndoTimer;

  /// Walk-up: labor chosen from Pick labor → temporary 1:1 verify on this
  /// camera (no nested route). Cleared after success → back to walk-up.
  TimesheetOdooEmployee? _walkUpPickVerifyTarget;

  bool get _inWalkUpPickVerify => _walkUpPickVerifyTarget != null;

  /// Effective walk-up identify (false while pick-labor 1:1 is active).
  bool get _effectiveWalkUp => _walkUpMode && !_inWalkUpPickVerify;

  bool get _showPickLaborButton =>
      (_walkUpMode || _projectMode) && _pickerLabour.isNotEmpty;

  void _armWalkUpUndoClear() {
    _walkUpUndoTimer?.cancel();
    _walkUpUndoTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _walkUpUndoUntil = null;
        _walkUpUndoEmployeeId = null;
      });
    });
  }

  void _undoWalkUpCapture() {
    final id = _walkUpUndoEmployeeId;
    if (id == null) return;
    TimesheetCaptureSessionEntry? removed;
    setState(() {
      final idx = _captures.lastIndexWhere((e) => e.employee.employeeId == id);
      if (idx >= 0) {
        removed = _captures.removeAt(idx);
      }
      _walkUpUndoUntil = null;
      _walkUpUndoEmployeeId = null;
      _noticeToast = null;
    });
    _walkUpUndoTimer?.cancel();
    debugPrint('WalkUp: undo emp=$id');
    // Camera syncs via capturedEmployeeIds didUpdateWidget (session + card).
    _notifyWalkUpSessionCaptures();
    final draft = removed?.draft;
    if (draft != null) {
      unawaited(TimesheetCaptureQueueService().delete(draft.id));
      final path = draft.cropLocalPath;
      if (path.isNotEmpty) {
        unawaited(File(path).delete().catchError((_) => File(path)));
      }
    }
  }

  /// Pick labor panel (walk-up + project verify): pause pipeline → drawer →
  /// walk-up: in-place 1:1 for that labor; verify: same as strip tap.
  Future<void> _onPickLabor() async {
    if (_pickerLabour.isEmpty) return;
    final camera = _cameraKey.currentState;
    await camera?.pausePipelineForPanel();
    if (!mounted) return;
    final chosen = await _showPickLaborDrawer(
      labour: _pickerOrder,
      capturedIds: _capturedEmployeeIds,
    );
    if (!mounted) return;
    if (chosen == null) {
      if (_walkUpMode) {
        debugPrint('WalkUp: pick_labor emp=- result=cancel');
      }
      await camera?.resumePipelineAfterPanel();
      return;
    }
    if (_capturedEmployeeIds.contains(chosen.employeeId)) {
      await camera?.resumePipelineAfterPanel();
      return;
    }
    if (_walkUpMode) {
      setState(() => _walkUpPickVerifyTarget = chosen);
      await camera?.resumePipelineAfterPanel();
      return;
    }
    // Project verify: same as tapping the picker strip.
    _selectTarget(chosen.employeeId, scroll: true);
    await camera?.resumePipelineAfterPanel();
  }

  Future<TimesheetOdooEmployee?> _showPickLaborDrawer({
    required List<TimesheetOdooEmployee> labour,
    required Set<int> capturedIds,
  }) {
    final screenW = MediaQuery.sizeOf(context).width;
    final width = math.min(420.0, screenW * 0.85);
    final messenger = ScaffoldMessenger.of(context);
    return showGeneralDialog<TimesheetOdooEmployee>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Pick labor',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: TimesheetModuleColors.surface,
            elevation: 8,
            child: SizedBox(
              width: width,
              height: double.infinity,
              child: _PickLaborDrawer(
                labour: labour,
                capturedIds: capturedIds,
                onSelect: (e) => Navigator.of(ctx).pop(e),
                onClose: () => Navigator.of(ctx).pop(),
                onAlreadyCaptured: () {
                  messenger
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text('Already captured'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                },
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        final offset = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );
        return SlideTransition(position: offset, child: child);
      },
    );
  }

  /// Suppress the "already attended" prompt for a short, realistic window right
  /// after a labor is captured so it does not fire the instant the same face is
  /// still in frame following the first submit.
  static const Duration _alreadyAttendedCooldown = Duration(seconds: 4);

  void _onAlreadyAttended(TimesheetOdooEmployee employee) {
    final resolved = _laborEmployeeOrNull(employee) ?? employee;
    final recent = _captures
        .where((c) => c.employee.employeeId == resolved.employeeId)
        .toList();
    if (recent.isNotEmpty) {
      final lastCapturedAt = recent.last.capturedAt;
      if (DateTime.now().difference(lastCapturedAt) <
          _alreadyAttendedCooldown) {
        // Too soon after capture — skip the nag so it feels realistic.
        return;
      }
    }
    _showCaptureNotice(
      resolved,
      TmFaceCaptureNoticeKind.alreadyAttended,
      held: true,
    );
    debugPrint(
        'FaceCaptureSession: already attended emp=${resolved.employeeId}');
  }

  /// After a successful capture (and its name announcement) return to the
  /// caller with the captured entries so the Your Team sheet can accumulate.
  void _scheduleReturnWithCaptures() {
    if (_returning) return;
    _returning = true;
    _returnTimer?.cancel();
    // Hold ~3s so the enlarged detected card stays visible and the spoken
    // name announcement finishes before returning to the Your Team sheet.
    _returnTimer = Timer(const Duration(milliseconds: 3000), () async {
      // Return only saved captures: a failed background write removes its
      // entry and cancels the return (see [_onCaptureWriteFailed]).
      await PendingCaptureWrites.flush();
      if (!mounted || !_returning) return;
      Navigator.of(context).pop<List<TimesheetCaptureSessionEntry>>(
        List<TimesheetCaptureSessionEntry>.from(_captures),
      );
    });
  }

  /// A capture already shown as added could not be saved: drop it so it is
  /// never submitted, and ask for a new capture.
  void _onCaptureWriteFailed(
    TimesheetOdooEmployee target,
    AttendanceCaptureDraft draft,
  ) {
    if (!mounted) return;
    final resolved = _laborEmployeeOrNull(target) ?? target;
    setState(() {
      _captures.removeWhere(
        (e) => e.draft.cropLocalPath == draft.cropLocalPath,
      );
      _noticeToast = null;
    });
    if (widget.returnCaptures) {
      _returnTimer?.cancel();
      _returning = false;
    } else {
      unawaited(_persistSession());
    }
    if (_projectMode) {
      _advanceTimer?.cancel();
      _selectTarget(resolved.employeeId, scroll: true);
    }
    _cameraKey.currentState?.resumeAfterNotice(armAuto: false);
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            "Couldn't save ${resolved.name}'s capture — please capture again",
          ),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  void _onChromeChanged(TimesheetCaptureChromeSnapshot chrome) {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _chrome = chrome);
      });
      return;
    }
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

    // Camera + confirm sheet stay open while acting; only the final submit
    // (after the confirm sheet) is refused.
    if (TimesheetActingGuard.blockWrite(
      context,
      ref,
      action: 'Submitting attendance',
    )) {
      return;
    }

    final buckets = await ref.read(timesheetProjectBucketsProvider.future);
    if (!mounted) return;
    final projects = buckets.inProgress;
    var submitProjectId = widget.args.projectId;
    var submitTaskId = widget.args.taskId;
    Project? selectedProject;
    for (final p in projects) {
      if (p.id == widget.args.projectId) {
        selectedProject = p;
        break;
      }
    }
    selectedProject ??= projects.isNotEmpty ? projects.first : null;

    final confirmed = await TmTimesheetCaptureConfirmSheet.show(
      context,
      captures: List.unmodifiable(_captures),
      startDateTime: _startDateTime,
      endDateTime: _endDateTime,
      breakHours: _breakHours,
      onStartChanged: (v) => _startDateTime = v,
      onEndChanged: (v) => _endDateTime = v,
      onBreakChanged: (v) => _breakHours = v,
      projects: projects,
      initialProject: selectedProject,
      onProjectChanged: (project) => selectedProject = project,
      onRemoveCapture: (entry) {
        setState(() => _captures.remove(entry));
        if (!widget.returnCaptures) {
          unawaited(_persistSession());
        }
        if (_projectMode && _pickedEmployeeId == null) {
          _selectTarget(_initialPick(), scroll: true);
        }
      },
      onReloadProjects: () =>
          TmProjectLocationNotifyService.reloadInProgressProjects(ref),
      onNotifyMissingLocation: (project) =>
          TmProjectLocationNotifyService.notifyStaff(
        client: ref.read(timesheetApiClientProvider),
        project: project,
      ),
    );
    if (!confirmed || !mounted) return;
    if (_captures.isEmpty) return;
    // Fast-accept photos/queue entries may still be writing; failed ones
    // remove themselves from [_captures].
    await PendingCaptureWrites.flush();
    if (!mounted || _captures.isEmpty) return;

    if (selectedProject != null) {
      submitProjectId = selectedProject!.id;
      try {
        final task = await ref.read(
          timesheetMaintenanceTaskProvider(selectedProject!.id).future,
        );
        submitTaskId = task.id;
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not resolve task for selected project'),
          ),
        );
        return;
      }
    }

    final client = ref.read(timesheetApiClientProvider);
    Future<TimesheetSubmitResult> doSubmit() {
      final ids = _captures.map((e) => e.employeeId).toList(growable: false);
      final names = _captures.map((e) => e.employee.name).join(', ');
      final coords = _captures
          .map(
            (e) => TimesheetSubmitCoord(
              employeeId: e.employeeId,
              lat: e.draft.lat,
              lon: e.draft.lon,
            ),
          )
          .toList(growable: false);
      return client.submitTimesheet(
        TimesheetSubmitRequest(
          projectId: submitProjectId,
          taskId: submitTaskId,
          employeeIds: ids,
          employeeName: names,
          date: widget.args.date,
          dateTime: _startDateTime,
          dateTimeEnd: _endDateTime,
          breakTimeHours: _breakHours,
          coords: coords,
          faceAudits: [
            for (final e in _captures)
              if (TimesheetSubmitFaceAudit.fromDraft(e.employeeId, e.draft)
                  case final audit?)
                audit,
          ],
        ),
      );
    }

    if (!mounted) return;
    setState(() => _isSubmitting = true);
    try {
      // Location already enforced at camera open; submit shows result only.
      final created = await TmTimesheetSubmitDialog.run(
        context,
        projectName: selectedProject?.name ?? widget.args.projectName,
        submit: doSubmit,
      );
      if (!mounted || !created) return;
      await TimesheetCaptureSessionStore.clear();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Acting PMs may use the camera; the Submit timesheet button calls
    // TimesheetActingGuard. Only block the whole screen for non-acting PMs.
    final resolution = ref.watch(tmEffectiveResolutionProvider);
    if (!resolution.canSubmitTimesheet &&
        ref.watch(tmActingSessionProvider) == null) {
      return TmScaffold(
        glassTitle: 'Add timesheet',
        body: Center(
          child: Text(
            'Only foremen can submit timesheets for their labors.',
            textAlign: TextAlign.center,
            style: TimesheetModuleTypography.body().copyWith(
              color: TimesheetModuleColors.warmMuted,
            ),
          ),
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
    // Tablet: keep floating chrome at a readable width, centered over the
    // full-bleed camera. Phone keeps the original edge insets.
    final tablet = ResponsiveBreakpoints.useTabletLayout(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final chromeInset = tablet
        ? math.max(16.0, (screenWidth - _tabletChromeMaxWidth) / 2)
        : 10.0;
    final showPicker = _projectMode && _pickerLoaded;
    final pickerBlock =
        showPicker ? _LaborPickerStrip.blockHeight(tablet) + 8 : 0.0;

    return PopScope(
      // Walk-up: never auto-pop without the capture list (iOS swipe otherwise
      // returns null and the Your Team tick never appears). Verify unchanged.
      canPop: _walkUpMode
          ? false
          : (widget.returnCaptures || _captures.isEmpty),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_walkUpMode && widget.returnCaptures) {
          Navigator.of(this.context)
              .pop<List<TimesheetCaptureSessionEntry>>(
            List<TimesheetCaptureSessionEntry>.from(_captures),
          );
          return;
        }
        final leave = await _confirmLeaveIfNeeded();
        if (!mounted) return;
        if (leave) Navigator.of(this.context).pop();
      },
      child: Scaffold(
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
              autoCaptureEnabled: false,
              // Manual capture only for now (bottom Capture button).
              instantAutoCapture: false,
              verifyTarget: !_effectiveWalkUp,
              walkUpMode: _effectiveWalkUp,
              targetEmployee: _effectiveWalkUp ? null : _targetEmployee,
              noTargetHint: _allPickerCaptured ? 'All labors captured' : null,
              overlayHint: _overlayHint,
              capturedEmployeeIds: _capturedEmployeeIds,
              projectLaborEmployeeIds: _projectLaborEmployeeIds,
              rosterEmployees: _employees,
              faceRecognition: ref.read(faceRecognitionServiceProvider),
              onTargetVerified: _onTargetVerified,
              onTargetVerifyFailed: _onTargetVerifyFailed,
              onWalkUpAccepted: _effectiveWalkUp ? _onWalkUpAccepted : null,
              onWalkUpAlreadySticky:
                  _effectiveWalkUp ? _onWalkUpAlreadySticky : null,
              onWalkUpCardCleared:
                  _effectiveWalkUp ? _onWalkUpCardCleared : null,
              onCaptureWriteFailed: _onCaptureWriteFailed,
              onAlreadyAttended: _onAlreadyAttended,
              onChromeChanged: _onChromeChanged,
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _NavyTitleBar(
                onBack: () async {
                  if (widget.returnCaptures) {
                    _returnTimer?.cancel();
                    Navigator.of(this.context)
                        .pop<List<TimesheetCaptureSessionEntry>>(
                      List<TimesheetCaptureSessionEntry>.from(_captures),
                    );
                    return;
                  }
                  final leave = await _confirmLeaveIfNeeded();
                  if (!mounted) return;
                  if (leave) Navigator.of(this.context).pop();
                },
              ),
            ),
            Positioned(
              top: headerTop,
              left: chromeInset,
              right: chromeInset,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CaptureProjectHeader(
                    projectName: widget.args.projectName,
                    taskName: widget.args.taskName,
                    dateLabel: dateLabel,
                  ),
                  if (_walkUpMode) ...[
                    const SizedBox(height: 8),
                    Material(
                      color: TimesheetModuleColors.accent
                          .withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(999),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Text(
                          'Captured ${_captures.length} / '
                          '${_walkUpTeamCount > 0 ? _walkUpTeamCount : '—'}',
                          style: TimesheetModuleTypography.caption().copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_walkUpMode &&
                      _walkUpUndoUntil != null &&
                      DateTime.now().isBefore(_walkUpUndoUntil!)) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _undoWalkUpCapture,
                      icon: const Icon(
                        Icons.undo,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: Text(
                        'Undo',
                        style: TimesheetModuleTypography.caption().copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.black54,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              top: headerTop + 88,
              right: tablet ? 16 : 10,
              child: _CaptureCameraRail(
                large: tablet,
                chrome: chrome,
                onFlip: camera?.switchCameraExternal,
                onFlash: camera?.toggleFlashExternal,
                onPickLabor: _showPickLaborButton ? _onPickLabor : null,
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
                  _TabletChromeWidth(
                    enabled: tablet,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (chrome?.livenessShowSpoofWarning == true)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            child: TmLivenessBlockedBanner(
                              message:
                                  chrome?.livenessMessage?.trim().isNotEmpty ==
                                          true
                                      ? chrome!.livenessMessage!.trim()
                                      : 'Live face verification failed.',
                              onRetry: camera?.retryLivenessSpoofExternal,
                            ),
                          ),
                        if (showPicker)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _LaborPickerStrip(
                              labour: _pickerOrder,
                              capturedIds: _capturedEmployeeIds,
                              selectedId: _pickedEmployeeId,
                              allCaptured: _allPickerCaptured,
                              large: tablet,
                              controller: _pickerScroll,
                              onSelect: (id) => _selectTarget(id),
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
                            livenessPhase:
                                chrome?.livenessPhase ?? LivenessGatePhase.idle,
                            livenessMessage: chrome?.livenessMessage,
                            onRetryLiveness:
                                chrome?.livenessShowSpoofWarning == true
                                    ? camera?.retryLivenessSpoofExternal
                                    : null,
                            showVerifyingSpinner: chrome?.isCapturing != true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _CaptureActionBar(
                    maxContentWidth: tablet ? _tabletChromeMaxWidth : null,
                    chrome: chrome,
                    onCapture: camera == null ? null : _onManualCapture,
                    captureCount: captureCount,
                    isSubmitting: _isSubmitting,
                    bottomInset: bottomInset,
                    // Your Team returns on its own after a capture; only the
                    // project camera submits from here.
                    onSubmit: widget.returnCaptures ? null : _submit,
                  ),
                ],
              ),
            ),
            if (notice != null)
              Positioned(
                left: tablet ? chromeInset : 12,
                right: tablet ? chromeInset : 12,
                bottom: bottomInset + 132 + pickerBlock,
                child: TmFaceCaptureNoticeTile(
                  key: ValueKey(
                    '${notice.employee.employeeId}_${notice.kind.name}_${notice.seq}',
                  ),
                  employee: notice.employee,
                  kind: notice.kind,
                  matchScore: notice.matchScore,
                  // Walk-up sticky: stay until camera replaces (autoDismiss 0).
                  autoDismissSeconds: notice.sticky ? 0 : 3,
                  onDismissed: notice.sticky ? null : _clearNoticeToast,
                  actionLabel: notice.sticky
                      ? null
                      : !notice.held
                          ? null
                          : notice.kind ==
                                  TmFaceCaptureNoticeKind.alreadyAttended
                              ? 'Next labor'
                              : 'Try again',
                  onAction: notice.sticky || !notice.held
                      ? null
                      : _onNoticeAction,
                  secondaryActions: [
                    if (notice.held &&
                        notice.kind == TmFaceCaptureNoticeKind.mismatch &&
                        _projectMode)
                      TmFaceNoticeAction(
                        label: 'Pick another labor',
                        onPressed: _onPickAnotherLabor,
                      ),
                    if (notice.held &&
                        notice.kind ==
                            TmFaceCaptureNoticeKind.photoUnavailable) ...[
                      TmFaceNoticeAction(
                        label: 'Add a new request',
                        onPressed: _openShiftRequest,
                      ),
                      if (_projectMode)
                        TmFaceNoticeAction(
                          label: 'Next labor',
                          onPressed: _onSkipToNextLabor,
                        ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Max width of floating capture chrome (header, status, submit) on tablets.
const double _tabletChromeMaxWidth = 620;

/// Centers [child] at [maxWidth] when [enabled] (tablet); passthrough on phone.
class _TabletChromeWidth extends StatelessWidget {
  const _TabletChromeWidth({
    required this.enabled,
    required this.child,
    this.maxWidth = _tabletChromeMaxWidth,
  });

  final bool enabled;
  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

class TimesheetCaptureNoticeToast {
  const TimesheetCaptureNoticeToast({
    required this.employee,
    required this.kind,
    this.matchScore,
    this.seq = 0,
    this.held = false,
    this.sticky = false,
  });

  final TimesheetOdooEmployee employee;
  final TmFaceCaptureNoticeKind kind;
  final double? matchScore;

  /// Bumped per show so a repeat alert for the same person replays the card.
  final int seq;

  /// Stays on screen with a button; camera auto capture paused meanwhile.
  final bool held;

  /// Walk-up: no auto-dismiss until the camera clears the card.
  final bool sticky;
}

/// Only the title row gets navy gradient; everything else floats on camera.
class _NavyTitleBar extends StatelessWidget {
  const _NavyTitleBar({required this.onBack});

  final VoidCallback onBack;

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
                onPressed: onBack,
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
    this.onPickLabor,
    this.large = false,
  });

  final bool large;
  final TimesheetCaptureChromeSnapshot? chrome;
  final Future<void> Function()? onFlip;
  final Future<void> Function()? onFlash;

  /// Walk-up only: pick labor (always shown when non-null).
  final Future<void> Function()? onPickLabor;

  @override
  Widget build(BuildContext context) {
    final isCapturing = chrome?.isCapturing == true;
    final iconSize = large ? 26.0 : 22.0;
    final gap = large ? 10.0 : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RailIconButton(
          icon: PhosphorIcons.cameraRotate(),
          tooltip: 'Switch camera',
          onPressed: isCapturing ? null : onFlip,
          iconSize: iconSize,
        ),
        SizedBox(height: gap),
        _RailIconButton(
          icon: PhosphorIcons.lightning(),
          tooltip: 'Flash',
          onPressed: onFlash,
          iconSize: iconSize,
        ),
        if (onPickLabor != null) ...[
          SizedBox(height: gap),
          _RailIconButton(
            icon: PhosphorIcons.userList(PhosphorIconsStyle.fill),
            tooltip: 'Pick labor',
            onPressed: isCapturing ? null : onPickLabor,
            iconSize: iconSize,
            backgroundColor:
                TimesheetModuleColors.accent.withValues(alpha: 0.85),
          ),
        ],
      ],
    );
  }
}

class _RailIconButton extends StatelessWidget {
  const _RailIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconSize = 22,
    this.backgroundColor,
  });

  final IconData icon;
  final String tooltip;
  final Future<void> Function()? onPressed;
  final double iconSize;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.black.withValues(alpha: 0.35),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed == null ? null : () => onPressed!(),
        icon: Icon(icon, color: TimesheetModuleColors.surface, size: iconSize),
      ),
    );
  }
}

/// Side panel (walk-up + verify): search + remaining then captured labors.
class _PickLaborDrawer extends StatefulWidget {
  const _PickLaborDrawer({
    required this.labour,
    required this.capturedIds,
    required this.onSelect,
    required this.onClose,
    required this.onAlreadyCaptured,
  });

  /// Already ordered: captured first, then remaining.
  final List<TimesheetOdooEmployee> labour;
  final Set<int> capturedIds;
  final ValueChanged<TimesheetOdooEmployee> onSelect;
  final VoidCallback onClose;
  final VoidCallback onAlreadyCaptured;

  @override
  State<_PickLaborDrawer> createState() => _PickLaborDrawerState();
}

class _PickLaborDrawerState extends State<_PickLaborDrawer> {
  final _query = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<TimesheetOdooEmployee> get _filtered {
    final q = _filter.trim().toLowerCase();
    if (q.isEmpty) return widget.labour;
    return [
      for (final e in widget.labour)
        if (e.matchesSearchQuery(q)) e,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    final remaining = [
      for (final e in items)
        if (!widget.capturedIds.contains(e.employeeId)) e,
    ];
    final captured = [
      for (final e in items)
        if (widget.capturedIds.contains(e.employeeId)) e,
    ];
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Pick labor',
                    style: TimesheetModuleTypography.h2().copyWith(
                      color: TimesheetModuleColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: widget.onClose,
                  icon: Icon(
                    PhosphorIcons.x(),
                    color: TimesheetModuleColors.ink,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: TextField(
              controller: _query,
              onChanged: (v) => setState(() => _filter = v),
              style: TimesheetModuleTypography.body().copyWith(
                color: TimesheetModuleColors.ink,
              ),
              decoration: InputDecoration(
                hintText: 'Search name or file id',
                hintStyle: TimesheetModuleTypography.caption().copyWith(
                  color: TimesheetModuleColors.warmMuted,
                ),
                prefixIcon: Icon(
                  PhosphorIcons.magnifyingGlass(),
                  color: TimesheetModuleColors.warmMuted,
                  size: 20,
                ),
                filled: true,
                fillColor: TimesheetModuleColors.glassSurface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    TimesheetModuleLayout.cardRadiusMd,
                  ),
                  borderSide: const BorderSide(
                    color: TimesheetModuleColors.glassBorder,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    TimesheetModuleLayout.cardRadiusMd,
                  ),
                  borderSide: const BorderSide(
                    color: TimesheetModuleColors.glassBorder,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    TimesheetModuleLayout.cardRadiusMd,
                  ),
                  borderSide: const BorderSide(
                    color: TimesheetModuleColors.accent,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      _filter.trim().isEmpty
                          ? 'All labors captured'
                          : 'No matches',
                      style: TimesheetModuleTypography.body().copyWith(
                        color: TimesheetModuleColors.warmMuted,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    children: [
                      if (captured.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                          child: Text(
                            'Captured (${captured.length})',
                            style:
                                TimesheetModuleTypography.caption().copyWith(
                              color: TimesheetModuleColors.warmMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        for (var i = 0; i < captured.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          _PickLaborTile(
                            employee: captured[i],
                            captured: true,
                            onTap: widget.onAlreadyCaptured,
                          ),
                        ],
                      ],
                      if (remaining.isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            4,
                            captured.isEmpty ? 0 : 16,
                            4,
                            8,
                          ),
                          child: Text(
                            'Remaining (${remaining.length})',
                            style:
                                TimesheetModuleTypography.caption().copyWith(
                              color: TimesheetModuleColors.warmMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        for (var i = 0; i < remaining.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          _PickLaborTile(
                            employee: remaining[i],
                            captured: false,
                            onTap: () => widget.onSelect(remaining[i]),
                          ),
                        ],
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _PickLaborCapturedTick extends StatelessWidget {
  const _PickLaborCapturedTick();

  static const Color _tick = Color(0xFF1E8E3E);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _tick.withValues(alpha: 0.15),
        ),
        child: const Icon(
          Icons.check_circle_rounded,
          size: 30,
          color: _tick,
        ),
      ),
    );
  }
}

class _PickLaborTile extends StatelessWidget {
  const _PickLaborTile({
    required this.employee,
    required this.captured,
    required this.onTap,
  });

  final TimesheetOdooEmployee employee;
  final bool captured;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final url = employee.faceMatchImageUrl?.trim() ?? '';
    final name = employee.name.trim();
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return Material(
      color: TimesheetModuleColors.glassSurface,
      borderRadius: BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: TimesheetModuleColors.accentTint,
                  border: Border.all(color: TimesheetModuleColors.iconSurface),
                ),
                clipBehavior: Clip.antiAlias,
                child: url.isNotEmpty
                    ? TmFastNetworkImage(url: url, fit: BoxFit.cover)
                    : Center(
                        child: Text(
                          initial,
                          style: TimesheetModuleTypography.h2().copyWith(
                            color: TimesheetModuleColors.accent,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TimesheetModuleTypography.cardTitle().copyWith(
                        color: TimesheetModuleColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      employee.displayFileId,
                      style: TimesheetModuleTypography.caption().copyWith(
                        color: TimesheetModuleColors.warmMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (captured)
                const _PickLaborCapturedTick()
              else
                Icon(
                  PhosphorIcons.caretRight(),
                  color: TimesheetModuleColors.warmMuted,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Project camera labor picker: one chip per Your Team labor (photo, short
/// name, file id, template state). Captured chips are done and disabled.
class _LaborPickerStrip extends StatelessWidget {
  const _LaborPickerStrip({
    required this.labour,
    required this.capturedIds,
    required this.selectedId,
    required this.allCaptured,
    required this.large,
    required this.controller,
    required this.onSelect,
  });

  final List<TimesheetOdooEmployee> labour;
  final Set<int> capturedIds;
  final int? selectedId;
  final bool allCaptured;
  final bool large;
  final ScrollController controller;
  final ValueChanged<int> onSelect;

  static const double _labelHeight = 20;
  static double _chipHeight(bool large) => large ? 68 : 58;
  static double _chipWidth(bool large) => large ? 176 : 148;
  static double _gap(bool large) => large ? 10 : 8;

  /// Width of one chip slot, gap included (for scroll-to-target).
  static double itemExtent(bool large) => _chipWidth(large) + _gap(large);

  /// Total height, so floating cards can sit above the strip.
  static double blockHeight(bool large) =>
      _labelHeight + 4 + _chipHeight(large);

  @override
  Widget build(BuildContext context) {
    final label = allCaptured
        ? 'All labors captured — submit when ready'
        : labour.isEmpty
            ? 'No Your Team labors on this project'
            : 'Labor to verify';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _labelHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TimesheetModuleTypography.caption().copyWith(
                color: TimesheetModuleColors.surface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: _chipHeight(large),
          child: ValueListenableBuilder<Map<int, ProfileTemplateState>>(
            valueListenable: ProfilePhotoFaceDb.instance.states,
            builder: (context, states, _) => ListView.builder(
              controller: controller,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemExtent: itemExtent(large),
              itemCount: labour.length,
              itemBuilder: (context, i) {
                final e = labour[i];
                return Padding(
                  padding: EdgeInsets.only(right: _gap(large)),
                  child: _LaborChip(
                    employee: e,
                    done: capturedIds.contains(e.employeeId),
                    selected: e.employeeId == selectedId,
                    templateState: ProfilePhotoMatchTest.enabled
                        ? states[e.employeeId] ?? ProfileTemplateState.pending
                        : null,
                    large: large,
                    onTap: () => onSelect(e.employeeId),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _LaborChip extends StatelessWidget {
  const _LaborChip({
    required this.employee,
    required this.done,
    required this.selected,
    required this.templateState,
    required this.large,
    required this.onTap,
  });

  final TimesheetOdooEmployee employee;
  final bool done;
  final bool selected;

  /// Null when profile-photo templates are off (no state to show).
  final ProfileTemplateState? templateState;
  final bool large;
  final VoidCallback onTap;

  String get _shortName {
    final parts = employee.name.trim().split(RegExp(r'\s+'));
    return parts.take(2).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final avatar = large ? 44.0 : 38.0;
    final url = employee.faceMatchImageUrl?.trim() ?? employee.imageUrl?.trim();
    final badge = done
        ? (Icons.check, const Color(0xFF3DDC84))
        : switch (templateState) {
            ProfileTemplateState.ready => (Icons.face, const Color(0xFF26A69A)),
            ProfileTemplateState.pending => (
                Icons.hourglass_top,
                const Color(0xFFFFB300)
              ),
            ProfileTemplateState.failed => (
                Icons.priority_high,
                const Color(0xFFE53935)
              ),
            null => null,
          };
    final initial = employee.name.isNotEmpty ? employee.name[0] : '?';

    return Material(
      color: selected
          ? TimesheetModuleColors.primary.withValues(alpha: 0.3)
          : Colors.black.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected
              ? TimesheetModuleColors.primary
              : Colors.white.withValues(alpha: 0.25),
          width: selected ? 2.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: done ? null : onTap,
        child: Opacity(
          opacity: done ? 0.55 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                SizedBox(
                  width: avatar + 4,
                  height: avatar + 4,
                  child: Stack(
                    children: [
                      ClipOval(
                        child: SizedBox(
                          width: avatar,
                          height: avatar,
                          child: url != null && url.isNotEmpty
                              ? TmFastNetworkImage(
                                  url: url,
                                  width: avatar,
                                  height: avatar,
                                  memCacheWidth: 120,
                                )
                              : ColoredBox(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  child: Center(
                                    child: Text(
                                      initial,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      if (badge != null)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: badge.$2,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.black54),
                            ),
                            child:
                                Icon(badge.$1, size: 12, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _shortName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TimesheetModuleTypography.caption().copyWith(
                          color: TimesheetModuleColors.surface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        employee.displayFileId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TimesheetModuleTypography.caption().copyWith(
                          color: TimesheetModuleColors.surface
                              .withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom bar: the Capture button, plus Submit on the project camera.
class _CaptureActionBar extends StatelessWidget {
  const _CaptureActionBar({
    required this.chrome,
    required this.onCapture,
    required this.captureCount,
    required this.isSubmitting,
    required this.bottomInset,
    required this.onSubmit,
    this.maxContentWidth,
  });

  final TimesheetCaptureChromeSnapshot? chrome;
  final Future<void> Function()? onCapture;
  final double? maxContentWidth;
  final int captureCount;
  final bool isSubmitting;
  final double bottomInset;

  /// Null on the Your Team camera (it returns on its own after a capture).
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final submit = onSubmit;
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
        child: _TabletChromeWidth(
          enabled: maxContentWidth != null,
          maxWidth: maxContentWidth ?? _tabletChromeMaxWidth,
          child: Row(
            children: [
              Expanded(
                child: _CaptureButton(chrome: chrome, onCapture: onCapture),
              ),
              if (submit != null) ...[
                const SizedBox(width: 10),
                _SubmitPill(
                  count: captureCount,
                  isSubmitting: isSubmitting,
                  onPressed: isSubmitting ? null : submit,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Capture: themed gradient when enabled, green once the target is verified,
/// muted glass when disabled, spinner while capturing.
class _CaptureButton extends StatelessWidget {
  const _CaptureButton({required this.chrome, required this.onCapture});

  final TimesheetCaptureChromeSnapshot? chrome;
  final Future<void> Function()? onCapture;

  static const LinearGradient _verifiedGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4FE394), Color(0xFF22A862), Color(0xFF136B3F)],
  );

  static const LinearGradient _readyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      TimesheetModuleColors.primaryGradientStart,
      TimesheetModuleColors.primary,
      TimesheetModuleColors.primaryGradientEnd,
    ],
  );

  @override
  Widget build(BuildContext context) {
    final c = chrome;
    final busy = c?.isCapturing == true;
    final enabled = !busy &&
        onCapture != null &&
        c?.canCapture == true &&
        c?.permissionsReady == true;
    final verified = c?.targetVerified == true;
    final active = enabled || busy;
    final fg = active ? Colors.white : Colors.white.withValues(alpha: 0.55);

    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Capture',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 56,
        decoration: BoxDecoration(
          gradient:
              active ? (verified ? _verifiedGradient : _readyGradient) : null,
          color: active ? null : Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withValues(alpha: active ? 0.35 : 0.22),
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: (verified
                            ? const Color(0xFF22A862)
                            : TimesheetModuleColors.primary)
                        .withValues(alpha: 0.45),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: enabled ? onCapture : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.4,
                    ),
                  )
                else
                  Icon(PhosphorIcons.camera(PhosphorIconsStyle.fill),
                      color: fg, size: 24),
                const SizedBox(width: 10),
                Text(
                  busy ? 'Capturing…' : 'Capture',
                  style: TimesheetModuleTypography.body().copyWith(
                    color: fg,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact submit next to Capture (project camera only).
class _SubmitPill extends StatelessWidget {
  const _SubmitPill({
    required this.count,
    required this.isSubmitting,
    required this.onPressed,
  });

  final int count;
  final bool isSubmitting;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = isSubmitting
        ? 'Submitting…'
        : (count == 0 ? 'Submit' : 'Submit ($count)');
    return SizedBox(
      height: 56,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.black.withValues(alpha: 0.45),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white.withValues(alpha: 0.5),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: TimesheetModuleTypography.body().copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        icon: Icon(PhosphorIcons.paperPlaneTilt(), size: 20),
        label: Text(label),
      ),
    );
  }
}
