import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/network/timesheet_functions_client.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';
import 'package:el_race/core/services/app_config_service.dart';
import 'package:el_race/core/site_management/face_recognition/android_face_capture_perf.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/antispoof_layer1.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/burst_verification_pipeline.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/antispoof_config.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/minifasnet_fusion_engine.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/timesheet_liveness_gate.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/timesheet_face_classification_snapshot.dart';
import 'package:el_race/core/site_management/face_recognition/domain/face_embedder.dart';
import 'package:el_race/core/site_management/face_recognition/domain/face_verifier.dart';
import 'package:el_race/core/site_management/face_recognition/domain/face_walkup.dart';
import 'package:el_race/core/site_management/face_recognition/domain/frame_evidence.dart';
import 'package:el_race/core/site_management/face_recognition/face_min_device_check.dart';
import 'package:el_race/core/site_management/face_recognition/face_recognition_config.dart';
import 'package:el_race/core/site_management/face_recognition/face_recognition_service.dart';
import 'package:el_race/core/site_management/face_recognition/profile_photo_face_db.dart';
import 'package:el_race/core/timesheet/services/timesheet_roster_face_matcher.dart';
import 'package:el_race/core/timesheet/services/capture_queue_service.dart';
import 'package:el_race/core/timesheet/services/face_capture_service.dart';
import 'package:el_race/core/timesheet/services/geofence_service.dart';
import 'package:el_race/core/timesheet/services/tm_face_alarm_service.dart';
import 'package:el_race/core/timesheet/services/tm_face_detection_speech_service.dart';
import 'package:el_race/core/timesheet/services/timesheet_capture_flow_service.dart';
import 'package:el_race/core/utils/app_orientations.dart';
import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_route_args.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/face_recognition/tm_distance_ghost_silhouette.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/face_recognition/tm_face_mesh_painter.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/face_recognition/tm_face_preview_map.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/face_recognition/tm_aws_face_liveness_screen.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show compute, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

List<int> _encodeCaptureJpeg(img.Image frame) =>
    img.encodeJpg(frame, quality: 90);

typedef _FastFrames = ({
  List<BurstFrameSample>? frames,
  List<TimesheetFaceLandmarkSnapshot?> faces,
  List<FaceVerifyResult?> verifies,
  String reason,
});

/// Latest stream frame queued for identity+PAD (marker updates separately).
class _BestFramePending {
  const _BestFramePending({
    required this.modelRgb,
    required this.modelFaceBox,
    required this.markerFaceBox,
    required this.uprightFrameSize,
    required this.result,
  });

  final img.Image modelRgb;
  final Rect modelFaceBox;
  final Rect markerFaceBox;
  final Size uprightFrameSize;
  final TimesheetFaceDetectionResult result;
}

/// Live chrome state for parent-built overlays (Add timesheet full screen).
class TimesheetCaptureChromeSnapshot {
  const TimesheetCaptureChromeSnapshot({
    required this.faceStatus,
    required this.geofenceLabel,
    required this.canCapture,
    this.targetVerified = false,
    required this.isCapturing,
    required this.permissionsReady,
    this.geofenceOk = false,
    this.faceDbReady = false,
    this.embeddingOn = false,
    this.livenessMessage,
    this.livenessReady = false,
    this.livenessShowSpoofWarning = false,
    this.livenessNeedsAwsStep = false,
    this.livenessVerifying = false,
    this.livenessPhase = LivenessGatePhase.idle,
    this.livenessStepNumber = 1,
    this.showWalkUpPickLabor = false,
  });

  final String faceStatus;
  final String geofenceLabel;
  final bool canCapture;

  /// 1:1: the live preview has verified the target (green shutter).
  final bool targetVerified;
  final bool isCapturing;
  final bool permissionsReady;
  final bool geofenceOk;
  final bool faceDbReady;
  final bool embeddingOn;
  final String? livenessMessage;
  final bool livenessReady;
  final bool livenessShowSpoofWarning;
  final bool livenessNeedsAwsStep;
  final bool livenessVerifying;
  final LivenessGatePhase livenessPhase;
  final int livenessStepNumber;

  /// Walk-up: face present but not identified long enough → show Pick labor.
  final bool showWalkUpPickLabor;
}

enum TimesheetFaceFrameKind {
  quality,
  inTeam,
  outOfTeam,
  duplicate,
}

/// Parent-driven face frame color + labels (name / file id on frame).
class TimesheetFaceOverlayHint {
  const TimesheetFaceOverlayHint({
    required this.kind,
    this.employeeName,
    this.fileId,
  });

  final TimesheetFaceFrameKind kind;
  final String? employeeName;
  final String? fileId;

  factory TimesheetFaceOverlayHint.inTeam({
    required String name,
    required String fileId,
  }) =>
      TimesheetFaceOverlayHint(
        kind: TimesheetFaceFrameKind.inTeam,
        employeeName: name,
        fileId: fileId,
      );

  factory TimesheetFaceOverlayHint.outOfTeam({
    required String name,
    required String fileId,
  }) =>
      TimesheetFaceOverlayHint(
        kind: TimesheetFaceFrameKind.outOfTeam,
        employeeName: name,
        fileId: fileId,
      );

  factory TimesheetFaceOverlayHint.duplicate({
    required String name,
    required String fileId,
  }) =>
      TimesheetFaceOverlayHint(
        kind: TimesheetFaceFrameKind.duplicate,
        employeeName: name,
        fileId: fileId,
      );

  /// Neutral badge text only (no file id), e.g. "Verifying Ahmed…".
  factory TimesheetFaceOverlayHint.neutral(String text) =>
      TimesheetFaceOverlayHint(
        kind: TimesheetFaceFrameKind.quality,
        employeeName: text,
      );
}

/// Shared camera + live ML Kit face markers (same as AT2 capture screen).
class TimesheetCaptureCameraPanel extends StatefulWidget {
  const TimesheetCaptureCameraPanel({
    super.key,
    required this.capture,
    this.showShutter = true,
    this.rosterEmployees,
    this.onCaptureMatched,
    this.onRosterEmployeeMatched,
    this.onOutOfTeamRecognized,
    this.onNoEmbeddingMatch,
    this.faceRecognition,
    this.onChromeChanged,
    this.fillHeight = false,
    this.externalChrome = false,
    this.autoCaptureEnabled = false,
    this.instantAutoCapture = false,
    this.overlayHint,
    this.capturedEmployeeIds = const {},
    this.projectLaborEmployeeIds = const {},
    this.onDuplicateRecognized,
    this.onAlreadyAttended,
    this.verifyTarget = false,
    this.walkUpMode = false,
    this.targetEmployee,
    this.noTargetHint,
    this.onTargetVerified,
    this.onTargetVerifyFailed,
    this.onWalkUpAccepted,
    this.onWalkUpAlreadySticky,
    this.onWalkUpCardCleared,
    this.onWalkUpPickLabor,
    this.onCaptureWriteFailed,
  });

  /// 1:1 mode: the face is only ever checked against [targetEmployee]; no
  /// other employee's name is shown or reported. False = AT2 1:N matching.
  final bool verifyTarget;

  /// TASK 10 walk-up: auto-identify Your Team (no fixed target).
  final bool walkUpMode;

  /// Walk-up accept → host shows card / undo / counter.
  final void Function(
    TimesheetOdooEmployee employee,
    AttendanceCaptureDraft draft,
    FaceWalkUpResult result,
  )? onWalkUpAccepted;

  /// Walk-up: already-captured W identified on 2 frames → sticky blue card.
  final void Function(TimesheetOdooEmployee employee)? onWalkUpAlreadySticky;

  /// Walk-up: sticky card replaced (other labor / stranger) → host clears it.
  final VoidCallback? onWalkUpCardCleared;

  /// Walk-up "Pick labor" → host opens verify for one labor.
  final Future<void> Function()? onWalkUpPickLabor;

  /// [verifyTarget] only. Null = no verification and no capture until the
  /// host picks a labor. May change while the camera stays open.
  final TimesheetOdooEmployee? targetEmployee;

  /// Badge / shutter message while [targetEmployee] is null; defaults to
  /// "Select a labor to verify".
  final String? noTargetHint;

  /// [verifyTarget]: the target verified. After a still the draft is already
  /// queued; after a fast accept its photo and queue entry are still being
  /// written ([PendingCaptureWrites]), see [onCaptureWriteFailed].
  final void Function(
    TimesheetOdooEmployee target,
    AttendanceCaptureDraft draft,
    FaceVerifyResult result,
  )? onTargetVerified;

  /// [verifyTarget]: the still did not verify the target (any outcome other
  /// than verified); nothing was queued and the photo is deleted.
  final void Function(
    TimesheetOdooEmployee target,
    FaceVerifyResult result,
  )? onTargetVerifyFailed;

  /// A fast-accept capture already shown as added could not be saved (photo
  /// or queue entry); the host must remove it. Nothing was queued.
  final void Function(
    TimesheetOdooEmployee target,
    AttendanceCaptureDraft draft,
  )? onCaptureWriteFailed;

  final TimesheetCaptureArgs capture;
  final bool showShutter;
  final bool fillHeight;
  final bool externalChrome;
  final bool autoCaptureEnabled;

  /// Press the shutter as soon as it becomes enabled. Runs the same
  /// [_capture] path as a manual press (full PAD burst on fresh frames).
  final bool instantAutoCapture;
  final TimesheetFaceOverlayHint? overlayHint;
  final Set<int> capturedEmployeeIds;

  /// Live `/timesheet/labor_list` for this project — source of truth for in-team UI.
  final Set<int> projectLaborEmployeeIds;
  final List<TimesheetOdooEmployee>? rosterEmployees;
  final ValueChanged<TimesheetCaptureChromeSnapshot>? onChromeChanged;

  /// When set (Add timesheet), returns match result instead of navigating away.
  final void Function(
    TimesheetMatchAttendanceResult match,
    AttendanceCaptureDraft draft,
  )? onCaptureMatched;

  /// In-team match (Phase B embeddings or Phase A HR photo).
  final void Function(
    TimesheetOdooEmployee employee,
    AttendanceCaptureDraft draft,
    double matchScore, {
    double secondBestScore,
    bool closeSecondCandidate,
  })? onRosterEmployeeMatched;

  /// Phase B: recognized but not in foreman team.
  final void Function(
    TimesheetOdooEmployee employee,
    AttendanceCaptureDraft draft,
    double matchScore,
  )? onOutOfTeamRecognized;

  /// Phase B: score below threshold — manual pick.
  final void Function(
    AttendanceCaptureDraft draft, {
    double? bestScore,
    String? closestName,
  })? onNoEmbeddingMatch;

  /// Already captured in this session — blue frame, skip add.
  final void Function(
    TimesheetOdooEmployee employee,
    AttendanceCaptureDraft draft,
    double matchScore,
  )? onDuplicateRecognized;

  /// Already in session — blue frame + ALREADY ATTENDED card, no capture.
  final void Function(TimesheetOdooEmployee employee)? onAlreadyAttended;

  final FaceRecognitionService? faceRecognition;

  @override
  State<TimesheetCaptureCameraPanel> createState() =>
      TimesheetCaptureCameraPanelState();
}

class TimesheetCaptureCameraPanelState
    extends State<TimesheetCaptureCameraPanel> {
  // Min device gate lives in [FaceMinDeviceCheck] (Odoo-configurable).
  static const Duration _streamDetectInterval = Duration(milliseconds: 280);
  static const Duration _streamDetectIntervalFast = Duration(milliseconds: 180);
  static const Duration _previewMatchInterval = Duration(milliseconds: 550);
  static const Duration _previewMatchIntervalLocked =
      Duration(milliseconds: 900);
  static const Duration _autoCaptureHold = Duration(milliseconds: 420);
  static const Duration _autoCaptureHoldLocked = Duration(milliseconds: 220);
  static const Duration _previewSuppressAfterMiss = Duration(milliseconds: 900);
  static const Duration _shutterSettleDelay = Duration(milliseconds: 120);
  static const List<Duration> _shutterBusyRetries = [
    Duration(milliseconds: 250),
    Duration(milliseconds: 600),
  ];

  /// Clear badge if no qualifying embed for this long (Task 6).
  static const Duration _badgeStaleTimeout = Duration(milliseconds: 400);

  final TimesheetFaceCaptureService _faceService =
      TimesheetFaceCaptureService();
  final TimesheetCaptureQueueService _queueService =
      TimesheetCaptureQueueService();
  final TimesheetCaptureFlowService _flowService =
      TimesheetCaptureFlowService();
  final TimesheetGeofenceService _geofenceService =
      const TimesheetGeofenceService();
  final TimesheetRosterFaceMatcher _rosterMatcher =
      TimesheetRosterFaceMatcher();
  final TimesheetLivenessGate _livenessGate = TimesheetLivenessGate();
  final BurstVerificationPipeline _burstPipeline = BurstVerificationPipeline();
  final AntispoofLayer1 _padLayer1 = AntispoofLayer1();
  final TmFaceDetectionSpeechService _speech = TmFaceDetectionSpeechService();

  /// TASK 08 best-frame evidence window (1:1 + switch on only).
  final List<FrameEvidence> _bestFrameWindow = [];
  BestFrameMarkerState _bestFrameMarker = BestFrameMarkerState.none;
  DateTime? _bestFrameFirstFaceAt;
  DateTime? _bestFrameFirstVerifiedAt;
  DateTime? _bestFrameFirstLiveAt;
  DateTime? _noUsableFrameSince;
  FrameUsableDominant _dominantUsableReason = FrameUsableDominant.none;
  DateTime _lastBestFrameProcessAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastBestFrameWaitingLogAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _bestFrameCooldownUntil;
  bool _bestFrameEvidenceBusy = false;
  bool _bestFrameManualWaiting = false;
  _BestFramePending? _bestFramePending;

  /// Adaptive window (A4): rolling average of processed-frame intervals.
  final List<int> _bestFrameIntervalMs = [];
  DateTime? _lastBestFrameProcessedAt;
  Duration _bestFrameWindowDuration = BestFrameRules.windowDuration;
  DateTime _lastBestFramePerfLogAt = DateTime.fromMillisecondsSinceEpoch(0);
  int _bestFramePerfEmbMs = 0;
  int _bestFramePerfPadMs = 0;

  /// ML Kit detection rate (camera-rate loop, independent of evidence).
  int _detectFrameCount = 0;
  int _detectSkippedWhileBusy = 0;
  int _streamCallbackCount = 0;
  int _streamProcessedCount = 0;
  int _streamDropIndex = 0;
  int _uiJankFrames = 0;
  int _uiStallMs = 0;
  DateTime _lastPerfUiLogAt = DateTime.fromMillisecondsSinceEpoch(0);
  void Function(List<FrameTiming>)? _frameTimingsCallback;
  int _detectConversionMsSum = 0;
  int _detectMsSum = 0;
  DateTime _detectFpsWindowStart = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastDetectFpsLogAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Per camera-open session: PAD frame counter + max live on non-accept frames.
  int _padScoreFrameSeq = 0;
  double _maxLiveOnUnverifiedOrRejected = 0;

  /// Upright ML Kit image size for marker mapping (sensor rotated).
  Size? _markerImageSize;

  /// Lerped face box (upright image space) for smooth marker motion (~100 ms).
  Rect? _markerLerpFrom;
  Rect? _markerLerpTo;
  DateTime? _markerLerpStarted;
  Rect? _markerSmoothBox;
  int? _markerEmployeeId;
  Timer? _markerLerpTimer;
  Timer? _delayedHintTimer;
  bool _delayedHintVisible = false;

  /// Distance ghost silhouette — ValueNotifier only (no panel setState).
  final ValueNotifier<DistanceSilhouetteHintState> _distanceSilhouette =
      ValueNotifier(DistanceSilhouetteHintState.hidden);
  DateTime? _silhouetteShownAt;
  Timer? _silhouetteMinHoldTimer;
  /// Timer fired but image size not ready yet — show when size arrives.
  bool _silhouettePendingShow = false;

  List<CameraDescription> _availableCameras = const [];
  CameraController? _cameraController;
  CameraDescription? _camera;
  TimesheetFaceDetectionResult? _faceResult;
  TimesheetGeofencePreview? _geofencePreview;
  Position? _position;
  bool _flashEnabled = false;
  bool _permissionsReady = false;
  TimesheetFaceCapturePermissions? _permissions;
  final TmFaceAlarmService _alarm = TmFaceAlarmService();
  AppLifecycleListener? _lifecycleListener;
  bool _preparingCapture = false;
  bool _isCapturing = false;
  Future<XFile>? _pictureInFlight;
  bool _isInitializingCamera = false;
  bool _isDetectingFrame = false;
  bool _isStreaming = false;

  /// Pick-labor side panel open: no stream processing / ML / PAD until resume.
  bool _pipelinePausedForPanel = false;
  bool _lowEndDeviceMode = false;
  String? _lowEndDeviceModel;
  int? _lowEndDeviceCores;
  double? _lowEndDeviceRamGb;
  bool _iosPollingDetection = false;
  bool _cameraInitInFlight = false;
  String? _cameraError;
  DateTime _lastFrameDetection = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _iosPollingTimer;
  Timer? _autoCaptureTimer;
  Timer? _instantCaptureTimer;
  DateTime _lastInstantCaptureAt = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _previewDebounceTimer;
  Timer? _livenessRetryTimer;
  DateTime? _faceReadySince;
  DateTime? _autoCaptureCooldownUntil;
  TimesheetFaceOverlayHint? _liveOverlayHint;
  int? _livePreviewEmployeeId;
  double _livePreviewScore = 0;
  bool _livePreviewBlockCapture = false;
  bool _livePreviewAllowAutoCapture = false;
  int? _previewCandidateEmployeeId;
  int _previewCandidateHits = 0;
  DateTime _previewCandidateSeenAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastRingSampleAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _previewMatchInFlight = false;
  DateTime _lastPreviewMatchAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _suppressEmbeddingPreviewUntil;

  /// Last time a display-threshold match refreshed the badge (Task 6).
  DateTime? _lastBadgeQualifyingAt;
  int _consecutiveReadyFrames = 0;
  bool _awsLivenessLaunched = false;
  bool _verificationInFlight = false;
  final List<BurstFrameSample> _streamSampleRing = [];

  /// When each [_streamSampleRing] frame was taken (same order).
  final List<DateTime> _streamSampleTimes = [];

  /// ML Kit landmarks of each ring frame's face (same order), so the fast
  /// path's 1:1 check uses the same 5-point aligned crop as the preview.
  final List<TimesheetFaceLandmarkSnapshot?> _streamSampleFaces = [];

  /// 1:1 result the live preview computed on each ring frame (same order);
  /// null when the preview did not run on that frame.
  final List<FaceVerifyResult?> _streamSampleVerify = [];

  /// Last stable, live preview verification of the target (1:1).
  FaceVerifyResult? _previewVerify;
  int? _previewVerifiedEmployeeId;
  LivenessGateSnapshot _livenessSnapshot = const LivenessGateSnapshot(
    phase: LivenessGatePhase.idle,
    statusMessage: 'Center your face in the frame',
  );

  Duration get _detectInterval => _consecutiveReadyFrames >= 2
      ? (_lowEndDeviceMode
          ? const Duration(milliseconds: 260)
          : _streamDetectIntervalFast)
      : (_lowEndDeviceMode
          ? const Duration(milliseconds: 380)
          : _streamDetectInterval);

  Duration get _previewMatchCooldown {
    if (_livePreviewAllowAutoCapture && _livePreviewEmployeeId != null) {
      return _lowEndDeviceMode
          ? const Duration(milliseconds: 1100)
          : _previewMatchIntervalLocked;
    }
    return _lowEndDeviceMode
        ? const Duration(milliseconds: 800)
        : _previewMatchInterval;
  }

  Duration get _autoCaptureWait {
    // Lower scores → wait a bit longer so the still is cleaner before shutter.
    final score = _livePreviewScore;
    if (!_livePreviewAllowAutoCapture) {
      return _lowEndDeviceMode
          ? const Duration(milliseconds: 520)
          : _autoCaptureHold;
    }
    if (score > 0 && score < 0.22) {
      return _lowEndDeviceMode
          ? const Duration(milliseconds: 700)
          : const Duration(milliseconds: 580);
    }
    if (score > 0 && score < 0.28) {
      return _lowEndDeviceMode
          ? const Duration(milliseconds: 520)
          : const Duration(milliseconds: 450);
    }
    return _lowEndDeviceMode
        ? const Duration(milliseconds: 320)
        : _autoCaptureHoldLocked;
  }

  bool _isEmployeeAlreadyCaptured(int employeeId) {
    if (widget.capturedEmployeeIds.contains(employeeId)) return true;
    // Walk-up: include ids accepted this session before the host rebuilds.
    if (widget.walkUpMode && _walkUpSessionCaptured.contains(employeeId)) {
      return true;
    }
    return false;
  }

  /// Immediate accept set (host [capturedEmployeeIds] can lag one frame).
  final Set<int> _walkUpSessionCaptured = {};

  /// Sticky success/already card for this employee (ignore W while held).
  int? _walkUpHeldCardEmpId;
  bool _walkUpHeldCardIsSuccess = false;
  DateTime? _walkUpStrangerSince;
  int? _walkUpAlreadyCandidateId;
  int _walkUpAlreadyIdFrames = 0;
  static const _walkUpAlreadyNeedFrames = 2;
  static const _walkUpStrangerClearDelay = Duration(seconds: 2);

  TimesheetOdooEmployee _walkUpResolveEmp(int employeeId) {
    for (final e in widget.rosterEmployees ?? const <TimesheetOdooEmployee>[]) {
      if (e.employeeId == employeeId || e.id == employeeId) return e;
    }
    return TimesheetOdooEmployee(
      id: employeeId,
      employeeId: employeeId,
      name: 'Employee $employeeId',
    );
  }

  void _clearWalkUpCardHold({required String reason}) {
    final was = _walkUpHeldCardEmpId;
    if (was == null) return;
    debugPrint('WalkUp: card replaced by $reason');
    _walkUpHeldCardEmpId = null;
    _walkUpHeldCardIsSuccess = false;
    _walkUpStrangerSince = null;
    widget.onWalkUpCardCleared?.call();
  }

  void _holdWalkUpCard(int empId, {required bool success}) {
    _walkUpHeldCardEmpId = empId;
    _walkUpHeldCardIsSuccess = success;
    _walkUpStrangerSince = null;
    _walkUpAlreadyCandidateId = null;
    _walkUpAlreadyIdFrames = 0;
    debugPrint('WalkUp: card hold emp=$empId');
    _maybeSuppressDistanceSilhouette();
  }

  void _stripIdentifiedEmpFromWindow(int empId) {
    _bestFrameWindow.removeWhere(
      (e) =>
          e.walkUp?.identified == true && e.walkUp?.winnerEmployeeId == empId,
    );
  }

  /// Sticky card + already-attended (2 identified frames). Returns true when
  /// the normal accept path must be skipped for this frame.
  bool _handleWalkUpStickyAndAlready({
    required DateTime now,
    required FrameEvidence evidence,
  }) {
    final wu = evidence.walkUp;
    final identified =
        (wu != null && wu.identified) ? wu.winnerEmployeeId : null;

    final held = _walkUpHeldCardEmpId;
    if (held != null) {
      if (identified == held) {
        // Same W still in front — keep success/already; ignore for evidence.
        _walkUpStrangerSince = null;
        _stripIdentifiedEmpFromWindow(held);
        return true;
      }
      if (identified != null && identified != held) {
        _clearWalkUpCardHold(reason: 'emp=$identified');
        _clearBestFrameWindow();
        _bestFrameWindow.add(evidence);
        // Fall through so the new labor can collect evidence / already / accept.
      } else {
        // Face present but not the held labor → stranger clock.
        _walkUpStrangerSince ??= now;
        if (now.difference(_walkUpStrangerSince!) >=
            _walkUpStrangerClearDelay) {
          _clearWalkUpCardHold(reason: 'stranger');
          _clearBestFrameWindow();
          _bestFrameWindow.add(evidence);
          // Fall through after clear.
        } else {
          // Ignore frames while the sticky card is up.
          _bestFrameWindow.removeWhere((e) => identical(e, evidence));
          _stripIdentifiedEmpFromWindow(held);
          return true;
        }
      }
    }

    // Already-attended: only PAD-live + identified frames count (same as
    // capture). Uncertain / notEligible / pad_ms=0 must not show the blue card.
    // Spoof is handled before this method (attack message, no card).
    if (identified != null && _isEmployeeAlreadyCaptured(identified)) {
      // After a fresh success for W, keep the green card — do not flip to blue.
      if (_walkUpHeldCardEmpId == identified && _walkUpHeldCardIsSuccess) {
        _stripIdentifiedEmpFromWindow(identified);
        return true;
      }
      if (!evidence.isLiveIdentified) {
        // Identified on a non-live PAD frame — do not advance already counter.
        return true;
      }
      if (_walkUpAlreadyCandidateId != identified) {
        _walkUpAlreadyCandidateId = identified;
        _walkUpAlreadyIdFrames = 1;
      } else {
        _walkUpAlreadyIdFrames++;
      }
      if (_walkUpAlreadyIdFrames >= _walkUpAlreadyNeedFrames) {
        debugPrint(
          'WalkUp: already emp=$identified frames=$_walkUpAlreadyIdFrames '
          'pad=live',
        );
        _holdWalkUpCard(identified, success: false);
        _clearBestFrameWindow();
        widget.onWalkUpAlreadySticky?.call(_walkUpResolveEmp(identified));
      }
      _stripIdentifiedEmpFromWindow(identified);
      return true;
    }

    _walkUpAlreadyCandidateId = null;
    _walkUpAlreadyIdFrames = 0;
    return false;
  }

  bool _isOnProjectLaborList(int employeeId) =>
      widget.projectLaborEmployeeIds.contains(employeeId);

  /// [TimesheetCaptureCameraPanel.verifyTarget] with no labor picked yet.
  bool get _awaitingTarget =>
      widget.verifyTarget && widget.targetEmployee == null;

  String get _selectLaborText =>
      widget.noTargetHint ?? 'Select a labor to verify';

  /// Guard for the AT2-only 1:N paths below.
  void _assertLegacy1toN(String path) {
    assert(
      !widget.verifyTarget,
      'verifyTarget mode must never enter the 1:N path "$path"',
    );
  }

  bool _targetRefreshInFlight = false;
  int _targetRefreshAttempts = 0;
  DateTime _lastTargetRefreshAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Just-enrolled labor: templates may reach Odoo after this screen synced.
  Future<void> _ensureTargetTemplates() async {
    final target = widget.targetEmployee?.employeeId;
    final phaseB = widget.faceRecognition;
    if (target == null || phaseB == null || _targetRefreshInFlight) return;
    if (_targetRefreshAttempts >=
        FaceExpectedLaborMatch.maxTemplateRefreshAttempts) {
      return;
    }
    if (DateTime.now().difference(_lastTargetRefreshAt) <
        FaceExpectedLaborMatch.templateRefreshCooldown) {
      return;
    }
    _targetRefreshInFlight = true;
    _targetRefreshAttempts++;
    try {
      await phaseB.ensureTemplatesFor(target);
    } catch (e) {
      debugPrint('FaceCapture: target template refresh failed: $e');
    } finally {
      _lastTargetRefreshAt = DateTime.now();
      _targetRefreshInFlight = false;
    }
  }

  /// "Try again" on the photo-unavailable card.
  Future<void> retryTargetTemplates() => _ensureTargetTemplates();

  void _showCaptureBlockedMessage(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  bool get _shouldHoldDuplicateFrame =>
      _livePreviewBlockCapture ||
      (_livePreviewEmployeeId != null &&
          _isEmployeeAlreadyCaptured(_livePreviewEmployeeId!));

  bool get _holdLiveMatching => _shouldHoldDuplicateFrame;

  bool get isGroup => widget.capture.mode == 'group';
  // The live badge describes the face in frame *now*; the host's post-capture
  // hint is only a fallback, or it paints the last person on the next face.
  TimesheetFaceOverlayHint? get _effectiveOverlayHint =>
      _liveOverlayHint ??
      (_awaitingTarget
          ? TimesheetFaceOverlayHint.neutral(_selectLaborText)
          : widget.overlayHint);
  bool get _qualityReady => _faceResult?.quality.canCapture == true;

  /// 1:1 + Odoo/code switch: continuous evidence pipeline (TASK 08).
  bool get _bestFrameModeActive =>
      AppConfigService.instance.faceBestFrameEnabled &&
      (widget.verifyTarget || widget.walkUpMode);

  /// Task 09: last time no identity/PAD-usable frame appeared, plus reason.
  DateTime? get noUsableFrameSince => _noUsableFrameSince;
  FrameUsableDominant get dominantUsableReason => _dominantUsableReason;
  BestFrameMarkerState get markerState => _bestFrameMarker;

  bool get _livenessReady {
    if (_livenessGate.expireIfNeeded()) {
      _syncLivenessSnapshot();
      _clearLiveOverlay();
    }
    return _livenessGate.recognitionAllowed;
  }

  /// Quality gate only — PAD runs at capture (Task 5a), not on the live stream.
  /// Best-frame mode: quality failures do not block (TASK 08 §6).
  bool get canCapture {
    if (_bestFrameModeActive) {
      final cooled = _bestFrameCooldownUntil;
      if (cooled != null && DateTime.now().isBefore(cooled)) return false;
      return !_isCapturing &&
          !_verificationInFlight &&
          !_bestFrameManualWaiting;
    }
    return _qualityReady && !_isCapturing && !_verificationInFlight;
  }

  /// What the shutter button shows: also off while the face in frame is
  /// already added or isn't the expected labor ([canCapture] stays
  /// quality-only because it also drives overlay resets).
  bool get _shutterEnabled =>
      canCapture && !_shouldHoldDuplicateFrame && !_awaitingTarget;

  void _syncLivenessSnapshot() {
    _livenessSnapshot = _livenessGate.snapshot;
  }

  void _emitChrome() {
    widget.onChromeChanged?.call(
      TimesheetCaptureChromeSnapshot(
        faceStatus: _statusLabel(_faceResult),
        geofenceLabel: _geofencePreview?.label ?? 'Waiting for GPS lock',
        canCapture: _shutterEnabled,
        targetVerified: _previewTargetVerified,
        isCapturing: _isCapturing,
        permissionsReady: _permissionsReady,
        geofenceOk: _geofencePreview?.isInside == true,
        faceDbReady: widget.faceRecognition?.isReady == true,
        embeddingOn: widget.faceRecognition?.isReady == true,
        livenessMessage: _livenessSnapshot.statusMessage,
        livenessReady: _livenessReady,
        livenessShowSpoofWarning: _livenessSnapshot.showSpoofWarning,
        livenessNeedsAwsStep: _livenessSnapshot.needsAwsStep,
        livenessVerifying: _livenessSnapshot.isVerifying,
        livenessPhase: _livenessSnapshot.phase,
        livenessStepNumber: _livenessSnapshot.stepNumber,
        showWalkUpPickLabor:
            widget.walkUpMode && _walkUpPickLaborHint != null,
      ),
    );
    _maybeInstantCapture();
  }

  static const Duration _instantCaptureGap = Duration(seconds: 2);

  bool get _instantCaptureReady =>
      mounted &&
      widget.instantAutoCapture &&
      !_noticeHold &&
      _permissionsReady &&
      _shutterEnabled &&
      // 1:1: auto only once the target is verified; manual tap is unchanged.
      (!widget.verifyTarget || _previewTargetVerified) &&
      !_livenessSnapshot.showSpoofWarning &&
      _cameraController?.value.isInitialized == true;

  /// One auto press per face presentation: re-armed only once the face is
  /// lost or drops below capture quality, so a rejected face doesn't loop.
  bool _instantCaptureArmed = true;

  /// Set while the host shows a wrong-person / already-attended card; no auto
  /// capture until the user taps the card button ([resumeAfterNotice]).
  bool _noticeHold = false;

  void holdForNotice() {
    if (_noticeHold) return;
    _noticeHold = true;
    _instantCaptureTimer?.cancel();
    _instantCaptureTimer = null;
    _autoCaptureTimer?.cancel();
    _faceReadySince = null;
    // Drop pending evidence so post-accept frames cannot PAD-reject.
    _bestFramePending = null;
    _clearBestFrameWindow();
    _maybeSuppressDistanceSilhouette();
  }

  /// [armAuto] false when the user pressed the shutter themselves.
  void resumeAfterNotice({bool armAuto = true}) {
    if (!_noticeHold) return;
    _noticeHold = false;
    _instantCaptureArmed = armAuto;
    _lastInstantCaptureAt = DateTime.fromMillisecondsSinceEpoch(0);
    _autoCaptureCooldownUntil = null;
    _clearBestFrameWindow();
    _clearBadgeNow(reason: 'notice_ack');
    _emitChrome();
  }

  void _clearBestFrameWindow() {
    for (final e in _bestFrameWindow) {
      e.releasePixels();
    }
    _bestFrameWindow.clear();
    _bestFrameMarker = BestFrameMarkerState.none;
    _clearWalkUpUnrecognized();
    _bestFrameFirstFaceAt = null;
    _bestFrameFirstVerifiedAt = null;
    _bestFrameFirstLiveAt = null;
    _noUsableFrameSince = null;
    _dominantUsableReason = FrameUsableDominant.none;
    _bestFrameIntervalMs.clear();
    _lastBestFrameProcessedAt = null;
    _bestFrameWindowDuration = BestFrameRules.windowDuration;
    _bestFramePending = null;
    _clearBestFrameMarkerVisual();
  }

  void _logPadSessionMax({required String reason}) {
    if (!kDebugMode) return;
    debugPrint(
      'PadScore: session max_live_score_on_unverified_or_rejected_frames='
      '${_maxLiveOnUnverifiedOrRejected.toStringAsFixed(3)} reason=$reason',
    );
  }

  void _notePadScore({
    required Layer1Result layer1,
    required FrameIdentityStatus identityStatus,
    required int frameSeq,
  }) {
    final fused = layer1.fused;
    final live = fused == null ||
            fused.probabilities.length <= AntispoofConfig.liveClassIndex
        ? 0.0
        : fused.probabilities[AntispoofConfig.liveClassIndex];
    final spoof = fused == null || fused.probabilities.length < 3
        ? 0.0
        : fused.probabilities[AntispoofConfig.printAttackClassIndex] +
            fused.probabilities[AntispoofConfig.replayAttackClassIndex];
    if (kDebugMode) {
      final target = widget.targetEmployee?.employeeId ?? 0;
      final attackTest = AppConfigService.instance.isTestMode;
      final reason = layer1.reason ?? '-';
      debugPrint(
        'PadScore: live=${live.toStringAsFixed(3)} '
        'spoof=${spoof.toStringAsFixed(3)} frame=#$frameSeq '
        'target=$target attack_test=${attackTest ? 1 : 0} '
        'verdict=${layer1.verdict.name} reason=$reason '
        'id=${identityStatus.name}',
      );
    }

    final unverified = identityStatus != FrameIdentityStatus.verified;
    final rejectedPad = layer1.verdict != Layer1Verdict.live;
    if (unverified || rejectedPad) {
      if (live > _maxLiveOnUnverifiedOrRejected) {
        _maxLiveOnUnverifiedOrRejected = live;
      }
    }
  }

  /// JPEG face crop for the saved attendance photo (keeps memory small).
  List<int>? _photoJpegFromModelCrop(img.Image modelRgb, Rect modelFaceBox) {
    try {
      final pad = modelFaceBox.inflate(modelFaceBox.shortestSide * 0.25);
      final left = pad.left.round().clamp(0, modelRgb.width - 1);
      final top = pad.top.round().clamp(0, modelRgb.height - 1);
      final right = pad.right.round().clamp(left + 1, modelRgb.width);
      final bottom = pad.bottom.round().clamp(top + 1, modelRgb.height);
      final w = right - left;
      final h = bottom - top;
      if (w < 8 || h < 8) return null;
      var crop = img.copyCrop(modelRgb, x: left, y: top, width: w, height: h);
      final side = math.max(crop.width, crop.height).clamp(64, 320);
      crop = img.copyResize(crop, width: side, height: side);
      return img.encodeJpg(crop, quality: 85);
    } catch (e) {
      debugPrint('BestFrame: photoJpeg crop failed: $e');
      return null;
    }
  }

  void _clearBestFrameMarkerVisual() {
    _markerLerpTimer?.cancel();
    _markerLerpTimer = null;
    _delayedHintTimer?.cancel();
    _delayedHintTimer = null;
    _markerLerpFrom = null;
    _markerLerpTo = null;
    _markerLerpStarted = null;
    _markerSmoothBox = null;
    _markerEmployeeId = null;
    _delayedHintVisible = false;
    _hideDistanceSilhouette(force: true);
  }

  /// Smooth the marker box toward [target] over ~100 ms (TASK 09).
  /// Cap repaint at 30 fps to cut overlay jank on mid-range Android.
  /// [employeeId] null/0 → neutral brackets; >0 → green + emp-id pill.
  void _animateMarkerBox(Rect target, {int? employeeId}) {
    if (employeeId != null) {
      _markerEmployeeId = employeeId > 0 ? employeeId : null;
    }
    final from = _markerSmoothBox ?? target;
    // Skip restarting lerp when the box barely moved.
    final prevTo = _markerLerpTo;
    if (prevTo != null &&
        (prevTo.left - target.left).abs() < 2 &&
        (prevTo.top - target.top).abs() < 2 &&
        (prevTo.width - target.width).abs() < 2 &&
        (prevTo.height - target.height).abs() < 2) {
      _markerLerpTo = target;
      return;
    }
    _markerLerpFrom = from;
    _markerLerpTo = target;
    _markerLerpStarted = DateTime.now();
    _markerSmoothBox = from;
    if (mounted) setState(() {});
    _markerLerpTimer?.cancel();
    _markerLerpTimer = Timer.periodic(const Duration(milliseconds: 33), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final started = _markerLerpStarted;
      final a = _markerLerpFrom;
      final b = _markerLerpTo;
      if (started == null || a == null || b == null) {
        t.cancel();
        return;
      }
      final p = (DateTime.now().difference(started).inMilliseconds / 100.0)
          .clamp(0.0, 1.0);
      setState(() {
        _markerSmoothBox = Rect.lerp(a, b, Curves.easeOut.transform(p));
      });
      if (p >= 1.0) {
        t.cancel();
        _markerLerpTimer = null;
        _markerSmoothBox = b;
      }
    });
  }

  /// Marker position tracks the latest ML Kit box only (never evidence boxes).
  void _updateMarkerPositionFromDetection(Rect faceBox) {
    final verifiedId = _bestFrameMarker is BestFrameMarkerVerified
        ? (_bestFrameMarker as BestFrameMarkerVerified).employeeId
        : null;
    _animateMarkerBox(faceBox, employeeId: verifiedId);
  }

  void _noteDetectionFps({
    required DateTime now,
    required int conversionMs,
    required int detectMs,
  }) {
    if (_detectFpsWindowStart.millisecondsSinceEpoch == 0) {
      _detectFpsWindowStart = now;
      _detectFrameCount = 0;
      _detectSkippedWhileBusy = 0;
      _detectConversionMsSum = 0;
      _detectMsSum = 0;
    }
    _detectFrameCount += 1;
    _detectConversionMsSum += conversionMs;
    _detectMsSum += detectMs;
    if (now.difference(_lastDetectFpsLogAt) <
        BestFrameRules.waitingLogInterval) {
      return;
    }
    final elapsedMs =
        now.difference(_detectFpsWindowStart).inMilliseconds.clamp(1, 60000);
    final n = _detectFrameCount.clamp(1, 100000);
    final fps = _detectFrameCount * 1000.0 / elapsedMs;
    final avgConv = _detectConversionMsSum / n;
    final avgDetect = _detectMsSum / n;
    _lastDetectFpsLogAt = now;
    debugPrint(
      'BestFrame: detection_fps=${fps.toStringAsFixed(1)} '
      'detect_ms=${avgDetect.toStringAsFixed(0)} '
      'input_conversion_ms=${avgConv.toStringAsFixed(0)} '
      'frames_skipped=$_detectSkippedWhileBusy '
      'frames=$_detectFrameCount window_ms=$elapsedMs '
      'lowEnd=${AndroidFaceCapturePerf.isLowEnd} '
      'downscale=${AndroidFaceCapturePerf.downscaleMlKit}',
    );
    _detectFpsWindowStart = now;
    _detectFrameCount = 0;
    _detectSkippedWhileBusy = 0;
    _detectConversionMsSum = 0;
    _detectMsSum = 0;
  }

  void _noteDetectMsForLowEnd(int detectMs) {
    if (!Platform.isAndroid) return;
    if (AndroidFaceCapturePerf.noteDetectMs(
          detectMs,
          model: _lowEndDeviceModel,
          cores: _lowEndDeviceCores,
          ramGb: _lowEndDeviceRamGb,
        ) &&
        mounted &&
        !_lowEndDeviceMode) {
      _lowEndDeviceMode = true;
    }
  }

  bool get _markerMirrorX =>
      _camera?.lensDirection == CameraLensDirection.front;

  /// Upright size matching ML Kit boxes (same space as the distance guide).
  /// Prefer sensor rotation; if orientation is 0 but the buffer is still
  /// landscape (common on some iOS paths), swap so boxes and guide agree.
  Size _uprightImageSize(CameraImage image, CameraDescription camera) {
    final angle = camera.sensorOrientation % 360;
    if (angle == 90 || angle == 270) {
      return Size(image.height.toDouble(), image.width.toDouble());
    }
    if (image.width > image.height) {
      return Size(image.height.toDouble(), image.width.toDouble());
    }
    return Size(image.width.toDouble(), image.height.toDouble());
  }

  bool get _isTooCloseHintReason =>
      _dominantUsableReason == FrameUsableDominant.tooClose;

  /// Card / green marker / spoof — never show the distance ghost.
  bool get _suppressDistanceSilhouette =>
      _noticeHold ||
      _walkUpHeldCardEmpId != null ||
      _bestFrameMarker is BestFrameMarkerVerified ||
      (_markerEmployeeId != null &&
          _markerEmployeeId! > 0 &&
          !widget.walkUpMode) ||
      _livenessSnapshot.showSpoofWarning;

  void _noteNoUsableFrame(DateTime now) {
    if (_noUsableFrameSince == null) {
      _noUsableFrameSince = now;
      _delayedHintTimer?.cancel();
      // tooClose: silhouette after 1 s. tooFar and other reasons: text at 2 s.
      final delay = _isTooCloseHintReason
          ? const Duration(seconds: 1)
          : const Duration(seconds: 2);
      _delayedHintTimer = Timer(delay, () {
        if (!mounted || !_bestFrameModeActive) return;
        if (_noUsableFrameSince == null) return;
        if (_isTooCloseHintReason) {
          if (_suppressDistanceSilhouette) return;
          debugPrint(
            'Hint: show reason=${_dominantUsableReason.name}',
          );
          _silhouettePendingShow = true;
          _showDistanceSilhouette();
          return;
        }
        if (_bestFrameMarker is BestFrameMarkerVerified) return;
        if (_noticeHold) return;
        if (!_delayedHintVisible) {
          debugPrint(
            'Hint: show reason=${_dominantUsableReason.name}',
          );
        }
        setState(() => _delayedHintVisible = true);
      });
    }
  }

  /// Preview insets so the SVG head clears header / bottom chrome.
  ({double top, double bottom}) _distanceGuideSafeInsets() {
    final pad = MediaQuery.paddingOf(context);
    final external = widget.fillHeight && widget.externalChrome;
    // External chrome: host header + capture bar overlay the preview.
    // In-panel chrome: status row top + geofence / shutter bottom.
    final top = pad.top + (external ? 72.0 : 56.0);
    final bottom = pad.bottom + (external ? 120.0 : 88.0);
    return (top: top, bottom: bottom);
  }

  void _showDistanceSilhouette() {
    if (_suppressDistanceSilhouette) {
      _silhouettePendingShow = false;
      return;
    }
    final imageSize = _markerImageSize;
    if (imageSize == null ||
        imageSize.width <= 0 ||
        imageSize.height <= 0) {
      return;
    }
    _silhouettePendingShow = false;
    _silhouetteMinHoldTimer?.cancel();
    _silhouetteMinHoldTimer = null;
    _silhouetteShownAt = DateTime.now();
    final safe = _distanceGuideSafeInsets();
    final next = DistanceSilhouetteHintState(
      show: true,
      imageSize: imageSize,
      fit: _previewFit,
      mirrorX: _markerMirrorX,
      safeTop: safe.top,
      safeBottom: safe.bottom,
    );
    if (_distanceSilhouette.value != next) {
      _distanceSilhouette.value = next;
    }
  }

  /// Hide silhouette; once shown, keep ≥600 ms to avoid flicker.
  void _hideDistanceSilhouette({bool force = false}) {
    _silhouettePendingShow = false;
    if (!_distanceSilhouette.value.show) {
      _silhouetteMinHoldTimer?.cancel();
      _silhouetteMinHoldTimer = null;
      _silhouetteShownAt = null;
      return;
    }
    if (!force && _silhouetteShownAt != null) {
      final elapsed = DateTime.now().difference(_silhouetteShownAt!);
      const minHold = Duration(milliseconds: 600);
      if (elapsed < minHold) {
        _silhouetteMinHoldTimer?.cancel();
        _silhouetteMinHoldTimer = Timer(minHold - elapsed, () {
          _hideDistanceSilhouette(force: true);
        });
        return;
      }
    }
    _silhouetteMinHoldTimer?.cancel();
    _silhouetteMinHoldTimer = null;
    _silhouetteShownAt = null;
    if (_distanceSilhouette.value.show) {
      debugPrint('Hint: hide');
      _distanceSilhouette.value = _distanceSilhouette.value.copyWith(show: false);
    }
  }

  void _syncDistanceSilhouetteMeta() {
    final cur = _distanceSilhouette.value;
    if (!cur.show) return;
    final imageSize = _markerImageSize;
    if (imageSize == null) return;
    final safe = _distanceGuideSafeInsets();
    final next = cur.copyWith(
      imageSize: imageSize,
      fit: _previewFit,
      mirrorX: _markerMirrorX,
      safeTop: safe.top,
      safeBottom: safe.bottom,
    );
    if (next != cur) _distanceSilhouette.value = next;
  }

  void _maybeSuppressDistanceSilhouette() {
    if (_suppressDistanceSilhouette) {
      _hideDistanceSilhouette(force: true);
    }
  }

  void _clearNoUsableFrame() {
    _noUsableFrameSince = null;
    _delayedHintTimer?.cancel();
    _delayedHintTimer = null;
    _hideDistanceSilhouette();
    if (_delayedHintVisible) {
      debugPrint('Hint: hide');
      if (mounted) {
        setState(() => _delayedHintVisible = false);
      } else {
        _delayedHintVisible = false;
      }
    } else {
      _delayedHintVisible = false;
    }
  }

  /// Delayed text hint — tooFar / angle / blur / dark (tooClose uses silhouette).
  /// Walk-up "Pick labor" is a host pill (not overlay text).
  String? get _bestFrameDelayedHintText {
    if (!_bestFrameModeActive) return null;
    if (_noticeHold) return null;
    if (_bestFrameMarker is BestFrameMarkerVerified) return null;
    // Pick labor is chrome (`showWalkUpPickLabor`), not floating camera text.
    if (!_delayedHintVisible) return null;
    if (_noUsableFrameSince == null) return null;
    return switch (_dominantUsableReason) {
      FrameUsableDominant.tooClose => null,
      FrameUsableDominant.tooFar => 'Come closer',
      FrameUsableDominant.angle => 'Look at the camera',
      FrameUsableDominant.blur => 'Hold still',
      FrameUsableDominant.dark => 'More light needed',
      FrameUsableDominant.none => 'Hold still',
    };
  }

  void _armBestFrameCooldown([Duration? d]) {
    _bestFrameCooldownUntil =
        DateTime.now().add(d ?? BestFrameRules.spoofCooldown);
  }

  Duration get _bestFrameProcessInterval {
    if (Platform.isAndroid) {
      return AndroidFaceCapturePerf.evidenceProcessInterval;
    }
    return _lowEndDeviceMode
        ? BestFrameRules.processIntervalLowEnd
        : BestFrameRules.processInterval;
  }

  void _noteBestFrameInterval(DateTime now) {
    final prev = _lastBestFrameProcessedAt;
    _lastBestFrameProcessedAt = now;
    if (prev == null) return;
    final ms = now.difference(prev).inMilliseconds;
    if (ms <= 0 || ms > 5000) return;
    _bestFrameIntervalMs.add(ms);
    if (_bestFrameIntervalMs.length > 12) {
      _bestFrameIntervalMs.removeAt(0);
    }
    final avg =
        _bestFrameIntervalMs.reduce((a, b) => a + b) / _bestFrameIntervalMs.length;
    _bestFrameWindowDuration = BestFrameRules.adaptiveWindowDuration(
      Duration(milliseconds: avg.round()),
    );
  }

  void _maybeLogBestFramePerf(DateTime now) {
    if (now.difference(_lastBestFramePerfLogAt) <
        BestFrameRules.waitingLogInterval) {
      return;
    }
    _lastBestFramePerfLogAt = now;
    final avgMs = _bestFrameIntervalMs.isEmpty
        ? 0
        : _bestFrameIntervalMs.reduce((a, b) => a + b) /
            _bestFrameIntervalMs.length;
    final fps = avgMs > 0 ? (1000.0 / avgMs) : 0.0;
    debugPrint(
      'BestFrame: perf fps=${fps.toStringAsFixed(1)} '
      'emb_ms=$_bestFramePerfEmbMs pad_ms=$_bestFramePerfPadMs '
      'window_ms=${_bestFrameWindowDuration.inMilliseconds}',
    );
  }

  /// Queue latest detection for identity+PAD (marker already updated separately).
  void _enqueueBestFrameEvidence(_BestFramePending pending) {
    if (!_bestFrameModeActive ||
        _noticeHold ||
        _isCapturing ||
        _awaitingTarget) {
      return;
    }
    final cooled = _bestFrameCooldownUntil;
    if (cooled != null && DateTime.now().isBefore(cooled)) return;
    _bestFramePending = pending;
    _kickBestFrameEvidenceIfIdle();
  }

  void _kickBestFrameEvidenceIfIdle() {
    if (_bestFrameEvidenceBusy) return;
    final pending = _bestFramePending;
    if (pending == null) return;
    final now = DateTime.now();
    final since = now.difference(_lastBestFrameProcessAt);
    if (since < _bestFrameProcessInterval) {
      final wait = _bestFrameProcessInterval - since;
      Future<void>.delayed(wait, () {
        if (!mounted) return;
        if (!_bestFrameEvidenceBusy && _bestFramePending != null) {
          _kickBestFrameEvidenceIfIdle();
        }
      });
      return;
    }
    _bestFramePending = null;
    _bestFrameEvidenceBusy = true;
    _lastBestFrameProcessAt = now;
    unawaited(_runBestFrameEvidence(pending).whenComplete(() {
      _bestFrameEvidenceBusy = false;
      if (_bestFramePending != null) {
        _kickBestFrameEvidenceIfIdle();
      }
    }));
  }

  /// [modelRgb] / [modelFaceBox] are what PAD+identity run on (full upright
  /// frame; same path on iOS and Android). Landmarks come from [result].
  /// [markerFaceBox] stays in full upright frame space for the overlay.
  Future<void> _runBestFrameEvidence(_BestFramePending pending) async {
    if (!_bestFrameModeActive || _noticeHold || _isCapturing || _awaitingTarget) {
      return;
    }
    final now = DateTime.now();
    _noteBestFrameInterval(now);
    final modelRgb = pending.modelRgb;
    final modelFaceBox = pending.modelFaceBox;
    final markerFaceBox = pending.markerFaceBox;
    final uprightFrameSize = pending.uprightFrameSize;
    final result = pending.result;
    try {
      await Future.wait([
        MinifasnetFusionEngine.instance.ensureLoaded(),
        FaceEmbedder.instance.ensureLoaded(),
      ]);
      final landmarks = result.primaryFace;
      final classification = result.classification;
      final sharpness =
          BestFrameRules.faceSharpness(modelRgb, modelFaceBox);
      final brightness =
          BestFrameRules.faceBrightness(modelRgb, modelFaceBox);

      final idOk = BestFrameRules.identityEligible(
        faceBox: markerFaceBox,
        frameSize: uprightFrameSize,
        landmarks: result.primaryFace,
        classification: classification,
      );
      final padReasons = BestFrameRules.padIneligibleReasons(
        faceBox: markerFaceBox,
        frameSize: uprightFrameSize,
        classification: classification,
        sharpness: sharpness,
      );
      final padOk = padReasons.isEmpty;

      // Hint tracks PAD-eligible frames (what can count toward accept), not
      // identity-only eligibility. idOk=true + padOk=false was clearing the
      // hint while pad_ineligible=too_close (dominant stayed none).
      if (!padOk) {
        _dominantUsableReason = BestFrameRules.dominantIneligibleReason(
          faceBox: markerFaceBox,
          frameSize: uprightFrameSize,
          landmarks: result.primaryFace,
          classification: classification,
          sharpness: sharpness,
          brightness: brightness,
          padReasons: padReasons,
        );
        _noteNoUsableFrame(now);
      } else {
        _dominantUsableReason = FrameUsableDominant.none;
        _clearNoUsableFrame();
      }

      _bestFrameFirstFaceAt ??= now;

      FaceVerifyResult? identity;
      FaceWalkUpResult? walkUp;
      var identityStatus = FrameIdentityStatus.notEligible;
      var pad = FramePadVerdict.notEligible;
      Layer1Result? layer1Result;

      // Fast Android / iOS: identity + PAD in parallel. Low-end Android: run
      // them sequentially so emb (2 threads) and PAD (2 threads) do not fight.
      Future<void> runIdentity() async {
        final phaseB = widget.faceRecognition;
        if (phaseB == null || !phaseB.isReady) return;
        if (widget.walkUpMode) {
          walkUp = await phaseB.identifyWalkUpImage(
            source: modelRgb,
            faceBox: modelFaceBox,
            landmarks: landmarks,
          );
          _bestFramePerfEmbMs = FaceEmbedder.instance.lastInferenceMs;
          identityStatus = walkUp!.identified
              ? FrameIdentityStatus.verified
              : FrameIdentityStatus.notVerified;
          return;
        }
        final target = widget.targetEmployee;
        if (target == null) return;
        identity = await phaseB.verifyImage(
          source: modelRgb,
          faceBox: modelFaceBox,
          targetEmployeeId: target.employeeId,
          landmarks: landmarks,
        );
        _bestFramePerfEmbMs = FaceEmbedder.instance.lastInferenceMs;
        identityStatus = identity!.isVerified
            ? FrameIdentityStatus.verified
            : FrameIdentityStatus.notVerified;
      }

      Future<void> runPad() async {
        final layer1 = await _padLayer1.evaluateImage(
          source: modelRgb,
          faceBox: modelFaceBox,
          yawDeg: classification?.headEulerAngleY,
        );
        layer1Result = layer1;
        _bestFramePerfPadMs = MinifasnetFusionEngine.instance.lastInferenceMs;
        pad = switch (layer1.verdict) {
          Layer1Verdict.live => FramePadVerdict.live,
          Layer1Verdict.spoof => FramePadVerdict.spoof,
          Layer1Verdict.uncertain => FramePadVerdict.uncertain,
          Layer1Verdict.error => FramePadVerdict.error,
        };
      }

      // Success/already card held: identify may continue (walk-up stranger
      // clear) but PAD must not run — no spoof alarm / window reset.
      final skipPadWhileCardHeld =
          _noticeHold || _walkUpHeldCardEmpId != null;
      final serialEvidence =
          Platform.isAndroid && AndroidFaceCapturePerf.isLowEnd;
      if (serialEvidence) {
        if (idOk) await runIdentity();
        if (padOk && !skipPadWhileCardHeld) await runPad();
      } else {
        final jobs = <Future<void>>[];
        if (idOk) jobs.add(runIdentity());
        if (padOk && !skipPadWhileCardHeld) jobs.add(runPad());
        if (jobs.isNotEmpty) await Future.wait(jobs);
      }
      if (!mounted) return;

      if (layer1Result != null) {
        _padScoreFrameSeq += 1;
        _notePadScore(
          layer1: layer1Result!,
          identityStatus: identityStatus,
          frameSeq: _padScoreFrameSeq,
        );
      }

      final quality = BestFrameRules.qualityScore(
        faceBox: markerFaceBox,
        frameSize: uprightFrameSize,
        classification: classification,
        sharpness: sharpness,
        brightness: brightness,
      );

      if (identityStatus == FrameIdentityStatus.verified) {
        _bestFrameFirstVerifiedAt ??= now;
      }
      if (pad == FramePadVerdict.live) {
        _bestFrameFirstLiveAt ??= now;
      }

      // Keep pixels for EVERY window frame (small model crop + JPEG face crop).
      final evidence = FrameEvidence(
        timestamp: now,
        faceBox: markerFaceBox,
        frameSize: uprightFrameSize,
        rgbFrame: modelRgb,
        modelFaceBox: modelFaceBox,
        photoJpeg: _photoJpegFromModelCrop(modelRgb, modelFaceBox),
        qualityScore: quality,
        identityStatus: identityStatus,
        identity: identity,
        walkUp: walkUp,
        pad: pad,
        classification: classification,
        landmarks: result.primaryFace,
        ineligibleReason: _dominantUsableReason,
        sharpness: sharpness,
        brightness: brightness,
      );

      _bestFrameWindow.add(evidence);
      final pruned = BestFrameRules.pruneWindow(
        _bestFrameWindow,
        now,
        duration: _bestFrameWindowDuration,
      );
      _bestFrameWindow
        ..clear()
        ..addAll(pruned);
      _maybeLogBestFramePerf(now);

      if (widget.walkUpMode) {
        if (pad == FramePadVerdict.spoof && !skipPadWhileCardHeld) {
          debugPrint('BestFrame: reject reason=spoof');
          _logPadSessionMax(reason: 'spoof_reject');
          _bestFrameMarker = BestFrameMarkerState.none;
          _markerEmployeeId = null;
          _livePreviewEmployeeId = null;
          _clearBestFrameWindow();
          _armBestFrameCooldown();
          _blockReplayAttempt(
            'Presentation attack detected — use live face',
          );
          _emitChrome();
          return;
        }

        final skipAccept = _handleWalkUpStickyAndAlready(
          now: now,
          evidence: evidence,
        );
        _updateWalkUpMarker(now: now, latest: evidence);
        if (skipAccept) {
          _emitChrome();
          return;
        }

        final decision = BestFrameRules.evaluateAcceptWalkUp(
          _bestFrameWindow,
          minLiveIdentifiedFrames:
              AppConfigService.instance.faceBestFrameMinLiveFrames,
        );
        if (decision.rejectReason == 'temporal_fail') {
          debugPrint('BestFrame: reject reason=temporal_fail');
          _logPadSessionMax(reason: 'temporal_fail');
          _clearBestFrameWindow();
          _armBestFrameCooldown();
          _emitChrome();
          return;
        }
        if (decision.rejectReason == 'identity_mix') {
          debugPrint('WalkUp: identity_mix — reset window');
          _clearBestFrameWindow();
          _emitChrome();
          return;
        }
        if (decision.rejectReason == 'spoof' && !skipPadWhileCardHeld) {
          // Window-level spoof (should be rare after per-frame check).
          debugPrint('BestFrame: reject reason=spoof');
          _logPadSessionMax(reason: 'spoof_reject');
          _clearBestFrameWindow();
          _armBestFrameCooldown();
          _blockReplayAttempt(
            'Presentation attack detected — use live face',
          );
          _emitChrome();
          return;
        }

        if (decision.accepted &&
            decision.best != null &&
            !_bestFrameManualWaiting &&
            !_isCapturing) {
          final w = decision.best!.walkUp?.winnerEmployeeId;
          if (w != null && _isEmployeeAlreadyCaptured(w)) {
            // Never create a duplicate entry.
            _clearBestFrameWindow();
            _patchState(() => _isCapturing = false);
            return;
          }
          _isCapturing = true;
          await _acceptBestFrameWalkUp(decision);
          return;
        }

        _maybeLogBestFrameWhy(
          now: now,
          decision: decision,
          latestPadReasons: padReasons,
        );
      } else {
        final targetId = widget.targetEmployee?.employeeId;
        if (targetId != null) {
          _bestFrameMarker = BestFrameRules.markerState(
            window: _bestFrameWindow,
            targetEmployeeId: targetId,
          );
        } else {
          _bestFrameMarker = BestFrameMarkerState.none;
        }

        // Green/label from evidence only — never move marker to evidence boxes.
        if (_bestFrameMarker is BestFrameMarkerVerified && targetId != null) {
          _livePreviewEmployeeId = targetId;
          _lastBadgeQualifyingAt = now;
          _liveOverlayHint = null;
          _markerEmployeeId = targetId;
          _maybeSuppressDistanceSilhouette();
          if (mounted) setState(() {});
          if (!_isEmployeeAlreadyCaptured(targetId)) {
            _livePreviewBlockCapture = false;
            _livePreviewAllowAutoCapture = true;
          }
        } else {
          final last = _lastBadgeQualifyingAt;
          if (_markerEmployeeId != null &&
              (last == null ||
                  now.difference(last) > BestFrameRules.markerSafetyStale)) {
            _markerEmployeeId = null;
            _livePreviewEmployeeId = null;
            _livePreviewAllowAutoCapture = false;
            _liveOverlayHint = null;
            if (mounted) setState(() {});
          }
        }

        final decision = BestFrameRules.evaluateAccept(
          _bestFrameWindow,
          minLiveVerifiedFrames:
              AppConfigService.instance.faceBestFrameMinLiveFrames,
        );
        if (decision.rejectReason == 'spoof' && !_noticeHold) {
          debugPrint('BestFrame: reject reason=spoof');
          _logPadSessionMax(reason: 'spoof_reject');
          _bestFrameMarker = BestFrameMarkerState.none;
          _markerEmployeeId = null;
          _livePreviewEmployeeId = null;
          _clearBestFrameWindow();
          _armBestFrameCooldown();
          _blockReplayAttempt(
            'Presentation attack detected — use live face',
          );
          _emitChrome();
          return;
        }
        if (decision.rejectReason == 'temporal_fail') {
          debugPrint('BestFrame: reject reason=temporal_fail');
          _logPadSessionMax(reason: 'temporal_fail');
          _clearBestFrameWindow();
          _armBestFrameCooldown();
          _emitChrome();
          return;
        }

        if (decision.accepted &&
            decision.best != null &&
            !_bestFrameManualWaiting &&
            !_isCapturing) {
          _isCapturing = true;
          await _acceptBestFrame(decision);
          return;
        }

        _maybeLogBestFrameWhy(
          now: now,
          decision: decision,
          latestPadReasons: padReasons,
        );
      }
      _emitChrome();
    } catch (e, st) {
      debugPrint('BestFrame: process failed: $e\n$st');
    }
  }

  /// Every 2 s while not accepted: why the accept rule has not fired.
  void _maybeLogBestFrameWhy({
    required DateTime now,
    required BestFrameAcceptDecision decision,
    required List<String> latestPadReasons,
  }) {
    if (now.difference(_lastBestFrameWaitingLogAt) <
        BestFrameRules.waitingLogInterval) {
      return;
    }
    _lastBestFrameWaitingLogAt = now;

    final liveVerified =
        _bestFrameWindow.where((e) => e.isLiveVerified).toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final spanMs = liveVerified.length >= 2
        ? liveVerified.last.timestamp
            .difference(liveVerified.first.timestamp)
            .inMilliseconds
        : 0;
    final eligibleId = _bestFrameWindow
        .where((e) => e.identityStatus != FrameIdentityStatus.notEligible)
        .length;
    final eligiblePad = _bestFrameWindow
        .where((e) => e.pad != FramePadVerdict.notEligible)
        .length;
    final bestStatus = decision.accepted
        ? 'accepted'
        : (decision.rejectReason ?? decision.waitReason ?? 'waiting');
    final temporal = decision.waitReason == 'temporal'
        ? 'not_ready'
        : (decision.rejectReason == 'temporal_fail'
            ? 'fail:${decision.waitReason ?? ""}'
            : (liveVerified.length >= 3 ? 'ok_or_n/a' : 'n/a'));
    final padWhy = latestPadReasons.isEmpty
        ? 'eligible'
        : latestPadReasons.join('+');
    // Never log dominant=none when pad_ineligible has a concrete reason.
    final dominant = latestPadReasons.isNotEmpty
        ? BestFrameRules.dominantFromPadReasons(latestPadReasons)
        : _dominantUsableReason;
    debugPrint(
      'BestFrame: WHY live_verified=${liveVerified.length} '
      'eligible_id=$eligibleId eligible_pad=$eligiblePad '
      'span_ms=$spanMs temporal=$temporal best=$bestStatus '
      'pad_ineligible=$padWhy dominant=${dominant.name} '
      'window=${_bestFrameWindow.length}',
    );
  }

  Future<void> _captureBestFrameManual() async {
    final minLive = AppConfigService.instance.faceBestFrameMinLiveFrames;
    final immediate = BestFrameRules.evaluateAccept(
      _bestFrameWindow,
      minLiveVerifiedFrames: minLive,
    );
    if (immediate.accepted && immediate.best != null) {
      _patchState(() => _isCapturing = true);
      await _acceptBestFrame(immediate);
      return;
    }
    _bestFrameManualWaiting = true;
    _emitChrome();
    final deadline = DateTime.now().add(BestFrameRules.manualWait);
    try {
      while (mounted && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        if (!mounted) return;
        final d = BestFrameRules.evaluateAccept(
          _bestFrameWindow,
          minLiveVerifiedFrames: minLive,
        );
        if (d.rejectReason == 'spoof') {
          debugPrint('BestFrame: reject reason=spoof');
          _logPadSessionMax(reason: 'spoof_reject');
          _clearBestFrameWindow();
          _armBestFrameCooldown();
          _blockReplayAttempt(
            'Presentation attack detected — use live face',
          );
          return;
        }
        if (d.accepted && d.best != null) {
          _patchState(() => _isCapturing = true);
          await _acceptBestFrame(d);
          return;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Hold still'),
              duration: Duration(seconds: 2),
            ),
          );
      }
    } finally {
      _bestFrameManualWaiting = false;
      if (mounted) _emitChrome();
    }
  }

  /// Walk-up-only bottom hint (not identified ~3 s → Pick labor).
  String? _walkUpPickLaborHint;
  DateTime? _walkUpUnrecognizedSince;
  DateTime? _walkUpUnrecognizedLastSeen;
  static const _walkUpUnrecognizedDelay = Duration(seconds: 3);

  void _clearWalkUpUnrecognized() {
    final hadHint = _walkUpPickLaborHint != null;
    _walkUpUnrecognizedSince = null;
    _walkUpUnrecognizedLastSeen = null;
    _walkUpPickLaborHint = null;
    if (hadHint) _emitChrome();
  }

  /// Face present but not identified: show Pick labor after ~3 s continuous.
  void _noteWalkUpUnrecognized(DateTime now) {
    final last = _walkUpUnrecognizedLastSeen;
    if (last != null &&
        now.difference(last) > const Duration(milliseconds: 800)) {
      // Face left the stream — restart the clock.
      final hadHint = _walkUpPickLaborHint != null;
      _walkUpUnrecognizedSince = now;
      _walkUpPickLaborHint = null;
      if (hadHint) _emitChrome();
    } else {
      _walkUpUnrecognizedSince ??= now;
    }
    _walkUpUnrecognizedLastSeen = now;
    if (now.difference(_walkUpUnrecognizedSince!) < _walkUpUnrecognizedDelay) {
      return;
    }
    if (_walkUpPickLaborHint == null) {
      _walkUpPickLaborHint = 'Not recognized — Pick labor';
      _emitChrome();
    }
  }

  void _updateWalkUpMarker({
    required DateTime now,
    required FrameEvidence latest,
  }) {
    final wu = latest.walkUp;
    // Spoof: progress → 0, hide marker (attack UI is raised by caller).
    if (latest.pad == FramePadVerdict.spoof) {
      _bestFrameMarker = BestFrameMarkerState.none;
      _markerEmployeeId = null;
      _livePreviewEmployeeId = null;
      if (mounted) setState(() {});
      return;
    }
    if (wu != null && wu.outOfTeam) {
      _bestFrameMarker = BestFrameMarkerOutOfTeam(faceBox: latest.faceBox);
      _markerEmployeeId = null;
      _clearWalkUpUnrecognized();
      if (mounted) setState(() {});
      return;
    }
    // Progress / green only from identified AND PAD-live frames.
    // Identified + PAD pending/ineligible must not advance or invent 1/3.
    if (latest.isLiveIdentified && wu?.winnerEmployeeId != null) {
      _clearWalkUpUnrecognized();
      final winner = wu!.winnerEmployeeId!;
      final count = _bestFrameWindow
          .where(
            (e) =>
                e.isLiveIdentified && e.walkUp?.winnerEmployeeId == winner,
          )
          .length;
      if (count <= 0) {
        _bestFrameMarker = BestFrameMarkerState.none;
        _markerEmployeeId = null;
      } else if (count >= 3) {
        _bestFrameMarker = BestFrameMarkerVerified(
          employeeId: winner,
          faceBox: latest.faceBox,
        );
        _markerEmployeeId = winner;
        _livePreviewEmployeeId = winner;
        _lastBadgeQualifyingAt = now;
        _maybeSuppressDistanceSilhouette();
      } else {
        _bestFrameMarker = BestFrameMarkerProgress(
          employeeId: winner,
          faceBox: latest.faceBox,
          progress: count,
        );
        _markerEmployeeId = winner;
        _livePreviewEmployeeId = winner;
        _lastBadgeQualifyingAt = now;
      }
      if (mounted) setState(() {});
      return;
    }
    // Identified but not PAD-live: keep marker only if prior live hits exist.
    if (wu != null && wu.identified && wu.winnerEmployeeId != null) {
      final winner = wu.winnerEmployeeId!;
      final count = _bestFrameWindow
          .where(
            (e) =>
                e.isLiveIdentified && e.walkUp?.winnerEmployeeId == winner,
          )
          .length;
      if (count <= 0) {
        _bestFrameMarker = BestFrameMarkerState.none;
        _markerEmployeeId = null;
      } else if (count >= 3) {
        _bestFrameMarker = BestFrameMarkerVerified(
          employeeId: winner,
          faceBox: latest.faceBox,
        );
        _markerEmployeeId = winner;
        _maybeSuppressDistanceSilhouette();
      } else {
        _bestFrameMarker = BestFrameMarkerProgress(
          employeeId: winner,
          faceBox: latest.faceBox,
          progress: count,
        );
        _markerEmployeeId = winner;
      }
      _clearWalkUpUnrecognized();
      if (mounted) setState(() {});
      return;
    }
    // Face in frame, not identified (unknown / look-alike / below bars).
    _bestFrameMarker = BestFrameMarkerState.none;
    _markerEmployeeId = null;
    _noteWalkUpUnrecognized(now);
    if (mounted) setState(() {});
  }

  Future<void> _acceptBestFrameWalkUp(BestFrameAcceptDecision decision) async {
    var best = decision.best;
    if (best == null || !best.isLiveIdentified) {
      _patchState(() => _isCapturing = false);
      return;
    }
    final winnerId = best.walkUp!.winnerEmployeeId!;
    if (!best.hasPixels) {
      final alt = _bestFrameWindow
          .where((e) => e.isLiveIdentified && e.hasPixels)
          .fold<FrameEvidence?>(null, (bestSoFar, e) {
        if (bestSoFar == null || e.qualityScore > bestSoFar.qualityScore) {
          return e;
        }
        return bestSoFar;
      });
      if (alt == null) {
        _patchState(() => _isCapturing = false);
        return;
      }
      best = alt;
    }
    final employee = TimesheetOdooEmployee(
      id: winnerId,
      employeeId: winnerId,
      name: 'Employee $winnerId',
    );
    // Resolve name from face DB / project labor when possible.
    TimesheetOdooEmployee resolved = employee;
    for (final e in widget.rosterEmployees ?? const <TimesheetOdooEmployee>[]) {
      if (e.employeeId == winnerId) {
        resolved = e;
        break;
      }
    }

    var rgb = best.rgbFrame;
    if (rgb == null && best.photoJpeg != null) {
      rgb = img.decodeImage(Uint8List.fromList(best.photoJpeg!));
    }
    if (rgb == null) {
      _patchState(() => _isCapturing = false);
      return;
    }

    // Duplicate guard (session + host set). Never create a second entry.
    if (_isEmployeeAlreadyCaptured(winnerId)) {
      _patchState(() => _isCapturing = false);
      _clearBestFrameWindow();
      return;
    }

    final acceptAt = DateTime.now();
    final firstFace = _bestFrameFirstFaceAt ?? best.timestamp;
    final msFromFirst = acceptAt.difference(firstFace).inMilliseconds;
    final path =
        '${await _tempDir()}/ts_walkup_${DateTime.now().microsecondsSinceEpoch}.jpg';
    if (!mounted) return;

    // Mark captured immediately so the next frames cannot re-accept W.
    _walkUpSessionCaptured.add(winnerId);
    _holdWalkUpCard(winnerId, success: true);

    final facePx = ProfilePhotoFaceDb.instance.faceSourcePxOf(winnerId);
    final lowRes = facePx > 0 && facePx < 90;
    final audited = _buildCaptureDraft(path).withFaceAudit(
      verified: true,
      score: best.walkUp?.score,
      lead: best.walkUp?.lead,
      cohortSize: null,
      liveness: 'pass',
      method: 'profile_walkup',
    );
    final drafted = AttendanceCaptureDraft(
      id: audited.id,
      projectId: audited.projectId,
      taskId: audited.taskId,
      event: audited.event,
      createdAt: audited.createdAt,
      cropLocalPath: audited.cropLocalPath,
      lat: audited.lat,
      lon: audited.lon,
      workerId: winnerId.toString(),
      syncState: audited.syncState,
      faceVerified: audited.faceVerified,
      faceScore: audited.faceScore,
      faceLead: audited.faceLead,
      faceCohortSize: audited.faceCohortSize,
      faceLiveness: audited.faceLiveness,
      faceMethod: audited.faceMethod,
      livenessFlagged: audited.livenessFlagged,
      livenessLogJson: audited.livenessLogJson,
      awsLivenessSessionId: audited.awsLivenessSessionId,
      awsLivenessConfidence: audited.awsLivenessConfidence,
    );
    // No audit notes field — low_res / face_px logged only.
    debugPrint(
      'WalkUp: accept emp=$winnerId frames=${decision.liveVerifiedCount} '
      'min_score=${FaceWalkUpTuning.minScore} '
      'min_lead=${FaceWalkUpTuning.minLead} '
      'ms_from_first_face=$msFromFirst '
      'low_res=$lowRes face_px=$facePx',
    );
    _logPadSessionMax(reason: 'walkup_accept');

    final saveFrame = rgb;
    final saveJpeg = best.photoJpeg;
    _clearBestFrameWindow();
    _patchState(() => _isCapturing = false);
    _armAutoCaptureCooldown();
    _markJustCaptured(winnerId);
    widget.onWalkUpAccepted?.call(resolved, drafted, best.walkUp!);
    unawaited(
      _speech.speakEmployeeDetected(resolved.name, employeeId: winnerId),
    );
    PendingCaptureWrites.track(
      saveJpeg != null
          ? _persistFastCaptureJpeg(
              jpegBytes: saveJpeg,
              draft: drafted,
              target: resolved,
            )
          : _persistFastCapture(
              frame: saveFrame,
              draft: drafted,
              target: resolved,
            ),
    );
    _livenessGate.resetSession();
    _syncLivenessSnapshot();
    _clearLiveOverlay();
  }

  Future<void> _acceptBestFrame(BestFrameAcceptDecision decision) async {
    final target = widget.targetEmployee;
    var best = decision.best;
    if (target == null || best == null) {
      _patchState(() => _isCapturing = false);
      return;
    }

    // Never reject a passing window for missing pixels — pick another LV frame.
    if (!best.hasPixels || best.identity == null || !best.identity!.isVerified) {
      final alt = BestFrameRules.bestLiveVerifiedWithPixels(_bestFrameWindow);
      if (alt != null &&
          alt.identity != null &&
          alt.identity!.isVerified &&
          alt.hasPixels) {
        debugPrint(
          'BestFrame: accept using alternate frame with pixels '
          'q=${alt.qualityScore.toStringAsFixed(2)} '
          '(decision best lacked pixels/verify)',
        );
        best = alt;
      } else {
        debugPrint(
          'BestFrame: accept deferred — no live+verified frame still has pixels',
        );
        _patchState(() => _isCapturing = false);
        return;
      }
    }

    final verify = best.identity!;
    var rgb = best.rgbFrame;
    if (rgb == null && best.photoJpeg != null) {
      rgb = img.decodeImage(Uint8List.fromList(best.photoJpeg!));
    }
    if (rgb == null) {
      debugPrint(
        'BestFrame: accept deferred — could not decode pixels for best frame',
      );
      _patchState(() => _isCapturing = false);
      return;
    }

    if (_isEmployeeAlreadyCaptured(target.employeeId)) {
      final replay = !(await _burstPipeline.verifySingleFrame(
        BurstFrameSample(
          rgbFrame: rgb,
          faceBox: best.rgbFaceBox,
          classification: best.classification,
        ),
      ))
          .passed;
      if (!mounted) return;
      _patchState(() => _isCapturing = false);
      _clearBestFrameWindow();
      _armAutoCaptureCooldown();
      if (replay) {
        _blockReplayAttempt('Presentation attack detected — use live face');
      } else {
        _enterDuplicatePreview(target);
      }
      return;
    }
    if (!_isOnProjectLaborList(target.employeeId)) {
      _patchState(() => _isCapturing = false);
      _clearBestFrameWindow();
      _showCaptureBlockedMessage(
        "${target.name} is not on this project's labor list — cannot add",
      );
      return;
    }

    final acceptAt = DateTime.now();
    final firstFace = _bestFrameFirstFaceAt ?? best.timestamp;
    final msFromFirst = acceptAt.difference(firstFace).inMilliseconds;
    final firstVerifiedMs = _bestFrameFirstVerifiedAt == null
        ? -1
        : _bestFrameFirstVerifiedAt!.difference(firstFace).inMilliseconds;
    final firstLiveMs = _bestFrameFirstLiveAt == null
        ? -1
        : _bestFrameFirstLiveAt!.difference(firstFace).inMilliseconds;
    final path =
        '${await _tempDir()}/ts_best_${DateTime.now().microsecondsSinceEpoch}.jpg';
    if (!mounted) return;

    final audited = _buildCaptureDraft(path).withFaceAudit(
      verified: true,
      score: verify.targetScore,
      lead: verify.usedNoCohortBar ? null : verify.lead,
      cohortSize: verify.cohortSize,
      liveness: 'pass',
    );
    debugPrint(
      'BestFrame: timeline first_face_ms=0 '
      'first_verified_ms=$firstVerifiedMs '
      'first_live_ms=$firstLiveMs '
      'accept_ms=$msFromFirst',
    );
    debugPrint(
      'BestFrame: accept ms_from_first_face=$msFromFirst '
      'window=${decision.windowCount} frames '
      'live=${decision.liveVerifiedCount} '
      'verified=${decision.liveVerifiedCount} spoof=0 '
      'min_live_frames=${AppConfigService.instance.faceBestFrameMinLiveFrames} '
      'best_q=${best.qualityScore.toStringAsFixed(2)} '
      't=${verify.targetScore?.toStringAsFixed(2)} '
      'lead=${verify.usedNoCohortBar ? 'n/a' : verify.lead?.toStringAsFixed(2)}',
    );
    _logPadSessionMax(reason: 'accept');

    // Prefer JPEG face crop when present; else model RGB region.
    final saveFrame = rgb;
    final saveJpeg = best.photoJpeg;
    _clearBestFrameWindow();
    _patchState(() => _isCapturing = false);
    _armAutoCaptureCooldown();
    _markJustCaptured(target.employeeId);
    widget.onTargetVerified?.call(target, audited, verify);
    unawaited(
      _speech.speakEmployeeDetected(target.name, employeeId: target.employeeId),
    );
    PendingCaptureWrites.track(
      saveJpeg != null
          ? _persistFastCaptureJpeg(
              jpegBytes: saveJpeg,
              draft: audited,
              target: target,
            )
          : _persistFastCapture(
              frame: saveFrame,
              draft: audited,
              target: target,
            ),
    );
    _livenessGate.resetSession();
    _syncLivenessSnapshot();
    _clearLiveOverlay();
  }


  void _maybeInstantCapture() {
    if (!_qualityReady && !_isCapturing && !_verificationInFlight) {
      _instantCaptureArmed = true;
    }
    if (!_instantCaptureArmed || !_instantCaptureReady) {
      _instantCaptureTimer?.cancel();
      _instantCaptureTimer = null;
      return;
    }
    if (_instantCaptureTimer?.isActive == true) return;
    final sinceLast = DateTime.now().difference(_lastInstantCaptureAt);
    final wait = sinceLast >= _instantCaptureGap
        ? Duration.zero
        : _instantCaptureGap - sinceLast;
    _instantCaptureTimer = Timer(wait, () {
      _instantCaptureTimer = null;
      if (!_instantCaptureArmed || !_instantCaptureReady) return;
      _instantCaptureArmed = false;
      _lastInstantCaptureAt = DateTime.now();
      unawaited(_capture());
    });
  }

  /// External chrome (Add timesheet) — retry after spoof block.
  void retryLivenessSpoofExternal() => _onRetrySpoof();

  /// External chrome — open AWS Face Liveness (strict mode only).
  void launchAwsLivenessExternal() {
    if (AntispoofConfig.useAwsFaceLiveness) {
      unawaited(_launchAwsLiveness());
    }
  }

  /// Task 5a — run MiniFASNet burst once at shutter, using the in-memory ring.
  ///
  /// [streamFrames]: fast accept only (user-approved) — the full burst runs on
  /// the stream frames buffered just before the press instead of new ones.
  /// Every check and threshold is the same.
  Future<bool> _runCaptureTimePadBurst({
    List<BurstFrameSample>? streamFrames,
  }) async {
    _verificationInFlight = true;
    _livenessGate.markVerifying();
    _syncLivenessSnapshot();
    _emitChrome();
    try {
      // Ensure PAD interpreters are warm before first capture invoke.
      await MinifasnetFusionEngine.instance.ensureLoaded();
      // The spoof models are shared with the preview check; never run both.
      await _previewPadRun;
      final List<BurstFrameSample> samples;
      if (streamFrames != null) {
        samples = streamFrames;
      } else {
        // Frames from before this press may show a different face (or one a
        // previous attempt already judged); every attempt gets new frames.
        await _clearStreamSampleRing();
        _lastRingSampleAt = DateTime.fromMillisecondsSinceEpoch(0);
        samples = await _awaitFullPadBurst();
      }
      if (samples.length < AntispoofConfig.burstFrameCount) {
        debugPrint(
          'FaceCapture: PAD blocked — only ${samples.length}/'
          '${AntispoofConfig.burstFrameCount} frames',
        );
        _livenessGate.completeBurstVerification(
          passed: false,
          message: 'Hold still a moment, then capture again',
        );
        _syncLivenessSnapshot();
        _emitChrome();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hold still a moment, then capture again'),
            ),
          );
        }
        return false;
      }
      if (samples.any(_faceTooLargeForPad)) {
        debugPrint('FaceCapture: PAD blocked — face too close to the camera');
        _livenessGate.completeBurstVerification(
          passed: false,
          message: 'Move back a little, then capture again',
        );
        _syncLivenessSnapshot();
        _emitChrome();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Move back a little, then capture again'),
            ),
          );
        }
        return false;
      }
      if (kDebugMode && _padDiagDumps) {
        unawaited(_debugDumpPadFrames(samples));
      }
      final verifyResult = await _burstPipeline.verify(samples).timeout(
            AntispoofConfig.maxVerificationBudget,
            onTimeout: () => const BurstVerificationResult(
              passed: false,
              message: 'Verification timed out — retry',
            ),
          );
      _livenessGate.completeBurstVerification(
        passed: verifyResult.passed,
        message: verifyResult.message,
        layer1: verifyResult.lastLayer1,
      );
      _syncLivenessSnapshot();
      _emitChrome();
      if (!verifyResult.passed) {
        _blockReplayAttempt(verifyResult.message);
        return false;
      }
      debugPrint(
        'FaceCapture: capture-time PAD passed '
        '(${samples.length} frames)',
      );
      return true;
    } catch (e, st) {
      debugPrint('FaceCapture: capture-time PAD failed: $e\n$st');
      _livenessGate.completeBurstVerification(
        passed: false,
        message: 'Verification failed — retry',
      );
      _syncLivenessSnapshot();
      return false;
    } finally {
      _verificationInFlight = false;
    }
  }

  /// Every `takePicture` (shutter + iOS polling) goes through here. The camera
  /// plugin rejects overlapping calls ("Previous capture has not returned
  /// yet") on both platforms, so callers queue behind the in-flight one.
  Future<XFile> _takePictureExclusive(CameraController controller) async {
    while (_pictureInFlight != null) {
      try {
        await _pictureInFlight;
      } catch (_) {}
    }
    final pending = controller.takePicture();
    _pictureInFlight = pending;
    try {
      return await pending;
    } finally {
      if (identical(_pictureInFlight, pending)) _pictureInFlight = null;
    }
  }

  static bool _isCameraBusyError(CameraException error) {
    final text = '${error.code} ${error.description}'.toLowerCase();
    return text.contains('previous capture') ||
        text.contains('not returned') ||
        text.contains('busy') ||
        text.contains('in progress');
  }

  Future<XFile?> _takePictureWithRetry() async {
    for (var attempt = 0; attempt < _shutterBusyRetries.length + 1; attempt++) {
      final controller = _cameraController;
      if (controller == null || !controller.value.isInitialized) return null;
      try {
        return await _takePictureExclusive(controller);
      } on CameraException catch (error) {
        // Avoid re-initializing camera mid-session; it causes visible stalls.
        debugPrint(
            'FaceCapture takePicture failed (try ${attempt + 1}): $error');
        if (!_isCameraBusyError(error) ||
            attempt >= _shutterBusyRetries.length) {
          return null;
        }
        await Future<void>.delayed(_shutterBusyRetries[attempt]);
        if (!mounted) return null;
      }
    }
    return null;
  }

  Future<void> _clearStreamSampleRing() async {
    final stale = List<BurstFrameSample>.from(_streamSampleRing);
    _streamSampleRing.clear();
    _streamSampleTimes.clear();
    _streamSampleFaces.clear();
    _streamSampleVerify.clear();
    for (final sample in stale) {
      await _safeDeleteSampleTemp(sample);
    }
  }

  void _pushStreamSample(
    BurstFrameSample sample, {
    TimesheetFaceLandmarkSnapshot? landmarks,
  }) {
    if (_streamSampleRing.length >= 4) {
      final old = _streamSampleRing.removeAt(0);
      if (_streamSampleTimes.isNotEmpty) _streamSampleTimes.removeAt(0);
      if (_streamSampleFaces.isNotEmpty) _streamSampleFaces.removeAt(0);
      if (_streamSampleVerify.isNotEmpty) _streamSampleVerify.removeAt(0);
      unawaited(_safeDeleteSampleTemp(old));
    }
    _streamSampleRing.add(sample);
    _streamSampleTimes.add(DateTime.now());
    _streamSampleFaces.add(landmarks);
    _streamSampleVerify.add(null);
  }

  /// Keeps the preview's 1:1 result on the ring frame it was computed from
  /// (same decoded image), so capture can reuse it.
  void _storeRingVerify(img.Image source, FaceVerifyResult verify) {
    for (var i = 0; i < _streamSampleRing.length; i++) {
      if (identical(_streamSampleRing[i].rgbFrame, source) &&
          i < _streamSampleVerify.length) {
        _streamSampleVerify[i] = verify;
        return;
      }
    }
  }

  Future<void> _safeDeleteSampleTemp(BurstFrameSample sample) async {
    if (!sample.hasTempFile) return;
    final path = sample.imagePath;
    if (path == null || path.isEmpty) return;
    await _safeDeleteFile(path);
  }

  Future<void> _safeDeleteFile(String path) async {
    if (path.isEmpty) return;
    try {
      final file = File(path);
      if (!await file.exists()) return;
      await file.delete();
    } catch (_) {}
  }

  /// A 1–2 frame check can read a phone screen as live, so capture waits for
  /// the full burst (ring fills every 350 ms, 900 ms on low-end phones).
  Future<List<BurstFrameSample>> _awaitFullPadBurst() async {
    const need = AntispoofConfig.burstFrameCount;
    final intervalMs = _lowEndDeviceMode ? 900 : 350;
    final deadline =
        DateTime.now().add(Duration(milliseconds: intervalMs * need + 1000));
    while (mounted &&
        _isStreaming &&
        _streamSampleRing.length < need &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return _preShutterSamplesFromRing();
  }

  /// The spoof models must see the surroundings of the face; a frame without a
  /// decoded image can't be measured and counts as too close.
  bool _faceTooLargeForPad(BurstFrameSample sample) {
    final frame = sample.rgbFrame;
    if (frame == null) return true;
    final uprightWidth = math.min(frame.width, frame.height);
    return sample.faceBox.width >
        uprightWidth * AntispoofConfig.maxFaceWidthFraction;
  }

  /// PadDiag JPEG dumps block the UI; off unless built with
  /// `--dart-define=PAD_DIAG_DUMPS=true` (debug builds only).
  static const bool _padDiagDumps = bool.fromEnvironment('PAD_DIAG_DUMPS');

  /// Debug builds only, read-only: shows what the spoof models are given
  /// (frame orientation vs face box) without changing any decision.
  Future<void> _debugDumpPadFrames(List<BurstFrameSample> samples) async {
    try {
      final camera = _camera;
      final orientation = MediaQuery.maybeOrientationOf(context);
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      for (var i = 0; i < samples.length; i++) {
        final s = samples[i];
        final frame = s.rgbFrame;
        debugPrint(
          'PadDiag: frame ${i + 1}/${samples.length} '
          'lens=${camera?.lensDirection.name} '
          'sensorOrientation=${camera?.sensorOrientation} '
          'screen=${orientation?.name} '
          'frame=${frame?.width}x${frame?.height} box=${s.faceBox}',
        );
        if (frame == null) continue;
        final marked = img.Image.from(frame);
        final b = s.faceBox;
        img.drawRect(
          marked,
          x1: b.left.round(),
          y1: b.top.round(),
          x2: b.right.round(),
          y2: b.bottom.round(),
          color: img.ColorRgb8(255, 0, 0),
          thickness: 4,
        );
        final path = '${dir.path}/pad_diag_${stamp}_$i.jpg';
        await File(path).writeAsBytes(img.encodeJpg(marked, quality: 80));
        debugPrint('PadDiag: saved $path');
      }
    } catch (e) {
      debugPrint('PadDiag: dump failed: $e');
    }
  }

  List<BurstFrameSample> _preShutterSamplesFromRing() {
    const count = AntispoofConfig.burstFrameCount;
    if (_streamSampleRing.length < count) {
      return List<BurstFrameSample>.from(_streamSampleRing);
    }
    return _streamSampleRing.sublist(_streamSampleRing.length - count);
  }

  Future<bool> _isLikelyReplayFrame({
    required String imagePath,
    required Rect faceBox,
    TimesheetFaceClassificationSnapshot? classification,
  }) async {
    final result = await _burstPipeline.verifySingleFrame(
      BurstFrameSample(
        imagePath: imagePath,
        faceBox: faceBox,
        classification: classification,
      ),
    );
    return !result.passed;
  }

  void _blockReplayAttempt(String message) {
    _livenessGate.blockReplay(message);
    _syncLivenessSnapshot();
    _clearLiveOverlay();
    _autoCaptureTimer?.cancel();
    _maybeSuppressDistanceSilhouette();
    if (mounted) {
      setState(() {});
      _emitChrome();
    }
  }

  Future<void> _clearBurstSamples() async {
    // Legacy no-op kept for retry/reset call sites; stream PAD samples use ring.
  }

  void _resetLiveOverlayFields() {
    _liveOverlayHint = null;
    _livePreviewEmployeeId = null;
    _livePreviewScore = 0;
    _livePreviewBlockCapture = false;
    _livePreviewAllowAutoCapture = false;
    _previewCandidateEmployeeId = null;
    _previewCandidateHits = 0;
    _previewCandidateSeenAt = DateTime.fromMillisecondsSinceEpoch(0);
    _lastRingSampleAt = DateTime.fromMillisecondsSinceEpoch(0);
    _lastBadgeQualifyingAt = null;
    _forgetPreviewVerify();
  }

  void _forgetPreviewVerify() {
    _previewVerify = null;
    _previewVerifiedEmployeeId = null;
  }

  /// 1:1: the preview shows the green badge for the current target.
  /// Best-frame: green when [markerState] is verified (TASK 08 §7).
  bool get _previewTargetVerified {
    if (_bestFrameModeActive) {
      return _bestFrameMarker is BestFrameMarkerVerified;
    }
    final target = widget.targetEmployee;
    return widget.verifyTarget &&
        target != null &&
        _livePreviewEmployeeId == target.employeeId &&
        _liveOverlayHint?.kind == TimesheetFaceFrameKind.inTeam;
  }

  /// Task 6 — blank name immediately (does not wait for N=3).
  void _clearBadgeNow({String reason = 'clear'}) {
    if (_liveOverlayHint == null &&
        _livePreviewEmployeeId == null &&
        !_livePreviewBlockCapture &&
        !_livePreviewAllowAutoCapture) {
      return;
    }
    debugPrint('FaceCapture: badge cleared ($reason)');
    _autoCaptureTimer?.cancel();
    _previewDebounceTimer?.cancel();
    _faceReadySince = null;
    if (!mounted) {
      _resetLiveOverlayFields();
      return;
    }
    setState(_resetLiveOverlayFields);
    _emitChrome();
  }

  bool _acceptStablePreviewIdentity(
    int employeeId, {
    required bool force,
  }) {
    if (force) return true;
    final now = DateTime.now();
    final sameCandidate = _previewCandidateEmployeeId == employeeId;
    final fresh = now.difference(_previewCandidateSeenAt) <=
        const Duration(milliseconds: 1600);
    if (!sameCandidate || !fresh) {
      _previewCandidateEmployeeId = employeeId;
      _previewCandidateHits = 1;
      _previewCandidateSeenAt = now;
      return false;
    }
    _previewCandidateHits += 1;
    _previewCandidateSeenAt = now;
    return _previewCandidateHits >= 3;
  }

  /// Quiet period after a successful capture: the same face stays blocked,
  /// but the "already added" badge / voice / host card wait until it ends.
  /// Kept just above the host's 4 s "already attended" cooldown so the
  /// deferred notice is not swallowed by it.
  static const Duration _justCapturedQuiet = Duration(milliseconds: 4500);
  int? _justCapturedEmployeeId;
  DateTime _justCapturedAt = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _duplicateNoticeTimer;

  void _markJustCaptured(int employeeId) {
    _justCapturedEmployeeId = employeeId;
    _justCapturedAt = DateTime.now();
  }

  void _enterDuplicatePreview(TimesheetOdooEmployee emp) {
    final quietLeft =
        _justCapturedQuiet - DateTime.now().difference(_justCapturedAt);
    if (emp.employeeId == _justCapturedEmployeeId &&
        quietLeft > Duration.zero) {
      _autoCaptureTimer?.cancel();
      _previewDebounceTimer?.cancel();
      _faceReadySince = null;
      if (!mounted) return;
      setState(() {
        _liveOverlayHint = null;
        _livePreviewBlockCapture = true;
        _livePreviewAllowAutoCapture = false;
      });
      _emitChrome();
      _duplicateNoticeTimer?.cancel();
      _duplicateNoticeTimer = Timer(quietLeft, () {
        if (!mounted || !_livePreviewBlockCapture || _liveOverlayHint != null) {
          return;
        }
        _enterDuplicatePreview(emp);
      });
      return;
    }
    final alreadyShowing =
        _livePreviewBlockCapture && _livePreviewEmployeeId == emp.employeeId;
    _autoCaptureTimer?.cancel();
    _previewDebounceTimer?.cancel();
    _faceReadySince = null;
    _livePreviewEmployeeId = emp.employeeId;
    if (!mounted) return;
    setState(() {
      _liveOverlayHint = TimesheetFaceOverlayHint.duplicate(
        name: emp.name,
        fileId: emp.displayFileId,
      );
      _livePreviewBlockCapture = true;
      _livePreviewAllowAutoCapture = false;
    });
    _emitChrome();
    if (!alreadyShowing) {
      widget.onAlreadyAttended?.call(emp);
      unawaited(_speech.speakAlreadyAttended(employeeId: emp.employeeId));
    }
  }

  @override
  void didUpdateWidget(covariant TimesheetCaptureCameraPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.walkUpMode != widget.walkUpMode ||
        oldWidget.verifyTarget != widget.verifyTarget ||
        (widget.verifyTarget &&
            oldWidget.targetEmployee?.employeeId !=
                widget.targetEmployee?.employeeId)) {
      _resetForNewTarget();
      return;
    }
    if (oldWidget.capturedEmployeeIds != widget.capturedEmployeeIds) {
      // Undo / host list: drop session ids no longer in the host set.
      final removed = oldWidget.capturedEmployeeIds
          .difference(widget.capturedEmployeeIds);
      for (final id in removed) {
        _walkUpSessionCaptured.remove(id);
        if (_walkUpHeldCardEmpId == id) {
          _clearWalkUpCardHold(reason: 'undo');
        }
      }
      for (final id in widget.capturedEmployeeIds) {
        _walkUpSessionCaptured.add(id);
      }
      final previewId = _livePreviewEmployeeId;
      if (previewId != null && _isEmployeeAlreadyCaptured(previewId)) {
        _autoCaptureTimer?.cancel();
        _previewDebounceTimer?.cancel();
        _faceReadySince = null;
        _livePreviewBlockCapture = true;
        _livePreviewAllowAutoCapture = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _emitChrome();
        });
      }
    }
  }

  /// New target while the camera stays open: drop everything tied to the old
  /// one (badge, stable-identity lock, held card, timers, auto-capture
  /// arming). The stream keeps running, so detection resumes on its own.
  void _resetForNewTarget() {
    debugPrint(
      'FaceCapture: target changed -> ${widget.targetEmployee?.employeeId}',
    );
    _autoCaptureTimer?.cancel();
    _instantCaptureTimer?.cancel();
    _instantCaptureTimer = null;
    _previewDebounceTimer?.cancel();
    _duplicateNoticeTimer?.cancel();
    _faceReadySince = null;
    _noticeHold = false;
    _bestFrameManualWaiting = false;
    _clearBestFrameWindow();
    // Disarmed: the face still in frame (often the labor just captured) must
    // leave first; auto capture re-arms once quality drops / the face goes.
    _instantCaptureArmed = false;
    _lastInstantCaptureAt = DateTime.fromMillisecondsSinceEpoch(0);
    _autoCaptureCooldownUntil = null;
    _suppressEmbeddingPreviewUntil = null;
    _justCapturedEmployeeId = null;
    _targetRefreshAttempts = 0;
    _lastTargetRefreshAt = DateTime.fromMillisecondsSinceEpoch(0);
    // Already rebuilding; notify the host after the frame.
    _resetLiveOverlayFields();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _emitChrome();
    });
  }

  void _clearLiveOverlay() {
    _clearBadgeNow(reason: 'overlay');
  }

  /// Live embedding for badge hints — no PAD on stream (Task 5a).
  Future<void> _runStreamEmbeddingPreview(
    CameraImage image,
    TimesheetFaceDetectionResult result, {
    img.Image? decodedRgb,
  }) async {
    if (_previewMatchInFlight ||
        _holdLiveMatching ||
        _isCapturing ||
        _verificationInFlight ||
        widget.faceRecognition?.isReady != true) {
      return;
    }
    // 1:1 keeps re-verifying a green badge (locked interval) so each check is
    // stored on its ring frame and a failed one drops the badge.
    if (!widget.verifyTarget &&
        _livePreviewAllowAutoCapture &&
        _livePreviewEmployeeId != null) {
      return;
    }
    final now = DateTime.now();
    if (now.difference(_lastPreviewMatchAt) < _previewMatchCooldown) {
      return;
    }
    if (!result.quality.canCapture || result.faceBoxes.isEmpty) return;

    _previewMatchInFlight = true;
    try {
      final camera = _camera;
      final rgb = decodedRgb ??
          (camera == null
              ? null
              : _faceService.decodeCameraImageUpright(image, camera));
      if (rgb == null) return;
      if (widget.verifyTarget) {
        await _applyLiveVerify(result, source: rgb);
      } else {
        await _applyLivePreviewMatchFromImage(result, rgb);
      }
    } catch (e) {
      debugPrint('Timesheet stream embedding preview failed: $e');
    } finally {
      _previewMatchInFlight = false;
      _lastPreviewMatchAt = DateTime.now();
    }
  }

  static const Duration _previewPadInterval = Duration(seconds: 1);
  bool? _previewLive;
  DateTime _previewPadAt = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void>? _previewPadRun;

  /// No name is shown for a face that fails a one-frame spoof check (about
  /// once a second). Low-end phones can't afford PAD on the stream, so they
  /// show no name until capture passes the full check.
  Future<bool> _previewFaceIsLive({
    required Rect faceBox,
    img.Image? rgbFrame,
    String? imagePath,
  }) async {
    if (_lowEndDeviceMode) {
      _clearBadgeNow(reason: 'low_end_no_preview_name');
      return false;
    }
    final cached = _previewLive;
    if (cached != null &&
        DateTime.now().difference(_previewPadAt) < _previewPadInterval) {
      if (!cached) _clearBadgeNow(reason: 'preview_spoof');
      return cached;
    }
    if (_previewPadRun != null || _verificationInFlight || _isCapturing) {
      return false;
    }
    final done = Completer<void>();
    _previewPadRun = done.future;
    try {
      final result = await _burstPipeline.verifySingleFrame(
        BurstFrameSample(
          rgbFrame: rgbFrame,
          imagePath: imagePath,
          faceBox: faceBox,
        ),
      );
      _previewLive = result.passed;
      _previewPadAt = DateTime.now();
      if (!result.passed) {
        debugPrint('FaceCapture: preview spoof — name hidden');
        _clearBadgeNow(reason: 'preview_spoof');
      }
      return result.passed;
    } catch (e) {
      debugPrint('FaceCapture: preview PAD failed: $e');
      return false;
    } finally {
      _previewPadRun = null;
      done.complete();
    }
  }

  /// 1:1 live preview: green badge with the target's name after 3 stable
  /// verified frames, otherwise a neutral "Verifying {target}…". Never shows
  /// another employee's name, never red, no alarm on the stream.
  Future<void> _applyLiveVerify(
    TimesheetFaceDetectionResult result, {
    img.Image? source,
    String? imagePath,
  }) async {
    final target = widget.targetEmployee;
    if (target == null || (source == null && imagePath == null)) return;
    final suppressed = _suppressEmbeddingPreviewUntil;
    if (suppressed != null && DateTime.now().isBefore(suppressed)) {
      return;
    }
    final phaseB = widget.faceRecognition;
    final faceBox = _largestFaceBox(result.faceBoxes);
    if (phaseB == null || !phaseB.isReady || faceBox == null) return;

    final verify = source != null
        ? await phaseB.verifyImage(
            source: source,
            faceBox: faceBox,
            targetEmployeeId: target.employeeId,
            landmarks: result.primaryFace,
          )
        : await phaseB.verifyCapturePhoto(
            imagePath: imagePath!,
            faceBox: faceBox,
            targetEmployeeId: target.employeeId,
            landmarks: result.primaryFace,
          );
    if (!mounted || widget.targetEmployee?.employeeId != target.employeeId) {
      return;
    }
    if (source != null) _storeRingVerify(source, verify);

    if (!verify.isVerified) {
      _suppressEmbeddingPreviewUntil =
          DateTime.now().add(_previewSuppressAfterMiss);
      _showVerifyingHint(target);
      return;
    }
    _suppressEmbeddingPreviewUntil = null;
    _lastBadgeQualifyingAt = DateTime.now();

    if (!await _previewFaceIsLive(
      faceBox: faceBox,
      rgbFrame: source,
      imagePath: imagePath,
    )) {
      return;
    }
    if (!mounted || widget.targetEmployee?.employeeId != target.employeeId) {
      return;
    }

    if (!_acceptStablePreviewIdentity(target.employeeId, force: false)) {
      _showVerifyingHint(target, keepHits: true);
      return;
    }

    _livePreviewEmployeeId = target.employeeId;

    if (_isEmployeeAlreadyCaptured(target.employeeId)) {
      _enterDuplicatePreview(target);
      return;
    }

    _livePreviewScore = verify.targetScore ?? 0;
    _previewVerify = verify;
    _previewVerifiedEmployeeId = target.employeeId;
    setState(() {
      _liveOverlayHint = TimesheetFaceOverlayHint.inTeam(
        name: target.name,
        fileId: target.displayFileId,
      );
      _livePreviewBlockCapture = false;
      _livePreviewAllowAutoCapture = true;
    });
    // The name is spoken when the capture is accepted (green card), not here.
    _emitChrome();
    _scheduleAutoCapture();
  }

  /// Neutral badge while the target is not (yet) verified. Hidden entirely
  /// while the last preview spoof check failed.
  void _showVerifyingHint(
    TimesheetOdooEmployee target, {
    bool keepHits = false,
  }) {
    if (!keepHits) {
      _previewCandidateEmployeeId = null;
      _previewCandidateHits = 0;
    }
    if (_previewLive == false &&
        DateTime.now().difference(_previewPadAt) < _previewPadInterval) {
      _clearBadgeNow(reason: 'preview_spoof');
      return;
    }
    final wasLocked = _livePreviewEmployeeId != null ||
        _livePreviewBlockCapture ||
        _livePreviewAllowAutoCapture;
    if (wasLocked) {
      _autoCaptureTimer?.cancel();
      _faceReadySince = null;
    }
    // The neutral badge stays until the face leaves; no stale timeout.
    _lastBadgeQualifyingAt = null;
    _forgetPreviewVerify();
    setState(() {
      _liveOverlayHint =
          TimesheetFaceOverlayHint.neutral('Verifying ${target.name}…');
      _livePreviewEmployeeId = null;
      _livePreviewScore = 0;
      _livePreviewBlockCapture = false;
      _livePreviewAllowAutoCapture = false;
    });
    if (wasLocked) _emitChrome();
  }

  void _scheduleAutoCapture() {
    _autoCaptureTimer?.cancel();
    if (!widget.autoCaptureEnabled ||
        _noticeHold ||
        _awaitingTarget ||
        !_permissionsReady ||
        _isCapturing ||
        !canCapture ||
        !_livePreviewAllowAutoCapture ||
        _shouldHoldDuplicateFrame ||
        _cameraController?.value.isInitialized != true) {
      _faceReadySince = null;
      return;
    }
    final previewId = _livePreviewEmployeeId;
    if (previewId != null && _isEmployeeAlreadyCaptured(previewId)) {
      _faceReadySince = null;
      return;
    }
    final cooldown = _autoCaptureCooldownUntil;
    if (cooldown != null && DateTime.now().isBefore(cooldown)) {
      return;
    }
    _faceReadySince ??= DateTime.now();
    final elapsed = DateTime.now().difference(_faceReadySince!);
    final wait = _autoCaptureWait;
    if (elapsed >= wait) {
      _faceReadySince = null;
      unawaited(_capture());
      return;
    }
    _autoCaptureTimer = Timer(wait - elapsed, () {
      if (!mounted ||
          _noticeHold ||
          _isCapturing ||
          !canCapture ||
          _shouldHoldDuplicateFrame) {
        return;
      }
      final id = _livePreviewEmployeeId;
      if (id != null && _isEmployeeAlreadyCaptured(id)) return;
      _faceReadySince = null;
      unawaited(_capture());
    });
  }

  void _armAutoCaptureCooldown(
      [Duration duration = const Duration(seconds: 2)]) {
    _autoCaptureCooldownUntil = DateTime.now().add(duration);
    _faceReadySince = null;
    _autoCaptureTimer?.cancel();
  }

  Future<void> capturePhoto() => _capture();

  Future<void> switchCameraExternal() => _switchCamera();

  Future<void> toggleFlashExternal() => _toggleFlash();

  /// Host opened Pick labor panel: stop frame processing + pause preview.
  Future<void> pausePipelineForPanel() async {
    if (_pipelinePausedForPanel) return;
    _pipelinePausedForPanel = true;
    _instantCaptureTimer?.cancel();
    _instantCaptureTimer = null;
    _autoCaptureTimer?.cancel();
    _previewDebounceTimer?.cancel();
    _bestFramePending = null;
    _clearBestFrameWindow();
    await _stopLiveDetection();
    final controller = _cameraController;
    if (controller != null && controller.value.isInitialized) {
      try {
        await controller.pausePreview();
      } catch (e) {
        debugPrint('FaceCapture: pausePreview failed: $e');
      }
    }
    debugPrint('WalkUp: pipeline paused (panel)');
  }

  /// Host closed Pick labor panel: clear evidence, resume preview + stream.
  Future<void> resumePipelineAfterPanel() async {
    if (!_pipelinePausedForPanel) {
      _clearBestFrameWindow();
      return;
    }
    _pipelinePausedForPanel = false;
    _clearBestFrameWindow();
    final controller = _cameraController;
    if (controller != null && controller.value.isInitialized) {
      try {
        await controller.resumePreview();
      } catch (e) {
        debugPrint('FaceCapture: resumePreview failed: $e');
      }
    }
    if (!mounted || _pipelinePausedForPanel) return;
    // Restart processing only — do not reset PAD / liveness session.
    if (Platform.isIOS) {
      try {
        await _startImageStream();
      } catch (error) {
        debugPrint(
          'Timesheet iOS image stream unavailable, using polling: $error',
        );
        await _startIosPollingDetection();
      }
    } else {
      await _startImageStream();
    }
    debugPrint('WalkUp: pipeline resumed');
  }

  /// App backgrounded while panel open: keep pipeline stopped.
  Future<void> _reassertPanelPause() async {
    if (!_pipelinePausedForPanel) return;
    await _stopLiveDetection();
    final controller = _cameraController;
    if (controller != null && controller.value.isInitialized) {
      try {
        await controller.pausePreview();
      } catch (_) {}
    }
  }

  Map<String, String>? _faceMatchHttpHeaders() {
    final token = SharedPref.getLoginData().result?.token?.trim();
    if (token == null || token.isEmpty) return null;
    return {'Authorization': 'Bearer $token'};
  }

  void _patchState(void Function() fn) {
    if (!mounted) return;
    setState(() {
      fn();
      if (!canCapture) {
        _consecutiveReadyFrames = 0;
        _resetLiveOverlayFields();
      }
    });
    _emitChrome();
    if (canCapture) {
      _scheduleAutoCapture();
    } else {
      _autoCaptureTimer?.cancel();
      _previewDebounceTimer?.cancel();
      _faceReadySince = null;
    }
  }

  @override
  void initState() {
    super.initState();
    // Face detection derives frame rotation from the sensor only, so a
    // landscape tablet would feed sideways frames — keep capture portrait.
    if (ResponsiveBreakpoints.isTabletScreen) {
      unawaited(
        SystemChrome.setPreferredOrientations(AppOrientations.phone),
      );
    }
    // Defer TFLite anti-spoof load until after first frame so opening the
    // camera isn't paired with a cold "Initialized TensorFlow Lite runtime"
    // on the same tick as preview start / camera flip.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(MinifasnetFusionEngine.instance.ensureLoaded());
      unawaited(_tempDir());
    });
    _geofencePreview = _geofenceService.preview(
      point: const TimesheetGeoPoint(lat: 25.2051, lon: 55.271),
      center: const TimesheetGeoPoint(lat: 25.2048, lon: 55.2708),
      radiusM: 120,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareCapture().then((_) => _emitChrome());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _emitChrome());
    unawaited(_speech.ensureReady());
    // Returning from Settings after granting access should unlock the camera
    // without leaving and re-opening the screen.
    _lifecycleListener = AppLifecycleListener(
      onPause: () {
        if (_pipelinePausedForPanel) {
          unawaited(_reassertPanelPause());
        }
      },
      onResume: () {
        if (_pipelinePausedForPanel) {
          // Panel still open — do not restart ML / stream.
          unawaited(_reassertPanelPause());
          return;
        }
        if (mounted && !_permissionsReady) {
          unawaited(_prepareCapture().then((_) => _emitChrome()));
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    final timingsCb = _frameTimingsCallback;
    if (timingsCb != null) {
      SchedulerBinding.instance.removeTimingsCallback(timingsCb);
      _frameTimingsCallback = null;
    }
    unawaited(AppOrientations.allowTabletRotation());
    _iosPollingTimer?.cancel();
    _autoCaptureTimer?.cancel();
    _instantCaptureTimer?.cancel();
    _duplicateNoticeTimer?.cancel();
    _previewDebounceTimer?.cancel();
    _livenessRetryTimer?.cancel();
    _markerLerpTimer?.cancel();
    _delayedHintTimer?.cancel();
    _silhouetteMinHoldTimer?.cancel();
    _hideDistanceSilhouette(force: true);
    _distanceSilhouette.dispose();
    unawaited(_clearStreamSampleRing());
    unawaited(_stopLiveDetection());
    unawaited(_speech.dispose());
    unawaited(_alarm.dispose());
    _cameraController?.dispose();
    _faceService.dispose();
    super.dispose();
  }

  /// Android: FrameTiming jank + stream vs processed fps every 2 s.
  void _startAndroidPerfUiLog() {
    if (!Platform.isAndroid) return;
    if (_frameTimingsCallback != null) return;
    _uiJankFrames = 0;
    _uiStallMs = 0;
    _streamCallbackCount = 0;
    _streamProcessedCount = 0;
    _lastPerfUiLogAt = DateTime.now();
    void onTimings(List<FrameTiming> timings) {
      for (final t in timings) {
        final totalMs = t.totalSpan.inMilliseconds;
        if (totalMs > 17) {
          _uiJankFrames += 1;
          _uiStallMs += totalMs - 16;
        }
      }
      final now = DateTime.now();
      if (now.difference(_lastPerfUiLogAt) < const Duration(seconds: 2)) {
        return;
      }
      final elapsedMs =
          now.difference(_lastPerfUiLogAt).inMilliseconds.clamp(1, 60000);
      final streamFps = _streamCallbackCount * 1000.0 / elapsedMs;
      final processedFps = _streamProcessedCount * 1000.0 / elapsedMs;
      // stall_ms approximates GC/UI stalls from over-budget frames.
      debugPrint(
        'Perf: ui_jank_frames=$_uiJankFrames gc_ms=$_uiStallMs '
        'stream_fps=${streamFps.toStringAsFixed(1)} '
        'processed_fps=${processedFps.toStringAsFixed(1)}',
      );
      _lastPerfUiLogAt = now;
      _uiJankFrames = 0;
      _uiStallMs = 0;
      _streamCallbackCount = 0;
      _streamProcessedCount = 0;
    }
    _frameTimingsCallback = onTimings;
    SchedulerBinding.instance.addTimingsCallback(onTimings);
  }

  /// External shutter (AT2 Cancel + Shutter row).
  Future<void> triggerCapture() => _capture();

  @override
  Widget build(BuildContext context) {
    final faceResult = _faceResult;

    final useExternalChrome = widget.fillHeight && widget.externalChrome;

    final cameraBox = Container(
      decoration: BoxDecoration(
        color: TimesheetModuleColors.navy,
        borderRadius: widget.fillHeight && !useExternalChrome
            ? BorderRadius.zero
            : BorderRadius.circular(TimesheetModuleLayout.cardRadiusLg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraPreview(),
          // TASK 09: best-frame 1:1 → square + emp id (no oval / name badge).
          // Switch off → today's name-badge overlay unchanged.
          if (_bestFrameModeActive) ...[
            // Distance ghost — own RepaintBoundary; ValueListenable only.
            RepaintBoundary(
              child: TmDistanceGhostSilhouette(
                listenable: _distanceSilhouette,
              ),
            ),
            if (_markerSmoothBox != null &&
                (_markerImageSize ?? faceResult?.imageSize) != null)
              CustomPaint(
                painter: BestFrameMarkerOverlayPainter(
                  imageSize: _markerImageSize ?? faceResult!.imageSize!,
                  faceBox: _markerSmoothBox!,
                  employeeId: _markerEmployeeId != null &&
                          _markerEmployeeId! > 0
                      ? _markerEmployeeId
                      : null,
                  // Verify: green+id while `_markerEmployeeId` is set (same as
                  // before walk-up). Walk-up: driven by marker type.
                  neutralOnly: widget.walkUpMode
                      ? (_bestFrameMarker is! BestFrameMarkerVerified &&
                          _bestFrameMarker is! BestFrameMarkerProgress &&
                          _bestFrameMarker is! BestFrameMarkerOutOfTeam)
                      : (_markerEmployeeId == null || _markerEmployeeId == 0),
                  progressLabel: widget.walkUpMode &&
                          _bestFrameMarker is BestFrameMarkerProgress
                      ? '${(_bestFrameMarker as BestFrameMarkerProgress).progress}/'
                          '${(_bestFrameMarker as BestFrameMarkerProgress).need}'
                      : null,
                  outOfTeam: widget.walkUpMode &&
                      _bestFrameMarker is BestFrameMarkerOutOfTeam,
                  fit: _previewFit,
                  mirrorX: _markerMirrorX,
                ),
              ),
            if (_bestFrameDelayedHintText != null)
              Positioned(
                left: 20,
                right: 20,
                bottom: useExternalChrome ? 12 : 56,
                child: IgnorePointer(
                  child: Text(
                    _bestFrameDelayedHintText!,
                    textAlign: TextAlign.center,
                    style: TimesheetModuleTypography.caption().copyWith(
                      color: TimesheetModuleColors.surface,
                      fontWeight: FontWeight.w600,
                      shadows: const [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 6,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ] else if (faceResult != null)
            CustomPaint(
              painter: TimesheetFaceOverlayPainter(
                result: faceResult,
                overlayHint: _effectiveOverlayHint,
                fit: _previewFit,
                verifiedOnly: widget.verifyTarget,
              ),
            ),
          if (!useExternalChrome) ...[
            Positioned(
              left: TimesheetModuleLayout.cardPadding,
              right: TimesheetModuleLayout.cardPadding,
              top: TimesheetModuleLayout.cardPadding,
              child: Row(
                children: [
                  Expanded(
                    child: TimesheetCaptureStatusPill(
                      label: _statusLabel(faceResult),
                      icon: faceResult?.quality.canCapture == true
                          ? PhosphorIcons.checkCircle()
                          : PhosphorIcons.warningCircle(),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Switch camera',
                    onPressed: _availableCameras.length < 2 ||
                            _isCapturing ||
                            _isInitializingCamera ||
                            _cameraInitInFlight
                        ? null
                        : _switchCamera,
                    icon: Icon(
                      PhosphorIcons.cameraRotate(),
                      color: TimesheetModuleColors.surface,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Flash',
                    onPressed: _cameraController == null ? null : _toggleFlash,
                    icon: Icon(
                      _flashEnabled
                          ? PhosphorIcons.lightning()
                          : PhosphorIcons.lightningSlash(),
                      color: TimesheetModuleColors.surface,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: TimesheetModuleLayout.cardPadding,
              right: TimesheetModuleLayout.cardPadding,
              bottom: TimesheetModuleLayout.cardPadding,
              child: TimesheetCaptureStatusPill(
                label: _geofencePreview?.label ?? 'Waiting for GPS lock',
                icon: PhosphorIcons.mapPin(),
              ),
            ),
            if (widget.showShutter)
              Positioned(
                right: TimesheetModuleLayout.cardPadding,
                bottom: TimesheetModuleLayout.cardPadding + 48,
                child: FloatingActionButton(
                  onPressed:
                      (!_permissionsReady || _isCapturing || !_shutterEnabled)
                          ? null
                          : _capture,
                  backgroundColor: _previewTargetVerified
                      ? TmFaceMeshPainter.inTeam
                      : TimesheetModuleColors.primary,
                  child: _isCapturing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(PhosphorIcons.camera(), color: Colors.white),
                ),
              ),
          ],
        ],
      ),
    );

    if (widget.fillHeight) {
      return Stack(
        fit: StackFit.expand,
        children: [
          cameraBox,
          if (!_permissionsReady)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildPermissionPill(),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: cameraBox),
        if (!_permissionsReady) ...[
          const SizedBox(height: TimesheetModuleLayout.cardSpacing),
          _buildPermissionPill(),
        ],
      ],
    );
  }

  Future<void> _prepareCapture() async {
    if (_preparingCapture) return;
    _preparingCapture = true;
    try {
      final permissions = await _faceService.requestCameraPermissions();
      if (!mounted) return;
      _patchState(() {
        _permissions = permissions;
        _permissionsReady = permissions.canOpenCamera;
      });
      if (!permissions.canOpenCamera) return;
      // Host screen usually gated already; re-check uses cache (no self-test).
      final deviceOk = await FaceMinDeviceCheck.ensureSupported(context);
      if (!mounted) return;
      if (!deviceOk) {
        _patchState(() {
          _permissionsReady = false;
          _cameraError = 'Device not supported for face attendance';
        });
        return;
      }
      await _applyAndroidPerfProfile();
      if (!mounted) return;
      await Future.wait([_initializeCamera(), _updateCurrentLocation()]);
    } finally {
      _preparingCapture = false;
    }
  }

  Widget _buildPermissionPill() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(_faceService.openPermissionSettings(_permissions)),
      child: TimesheetCaptureStatusPill(
        label: _permissions?.missingLabel ??
            'Camera and location permission required',
        icon: PhosphorIcons.lockKey(),
        dark: false,
      ),
    );
  }

  /// Sync panel flags from [AndroidFaceCapturePerf] after [FaceMinDeviceCheck].
  Future<void> _applyAndroidPerfProfile() async {
    if (!Platform.isAndroid) return;
    try {
      AndroidFaceCapturePerf.resetLowEndWhyLogForCameraOpen();
      final info = await DeviceInfoPlugin().androidInfo;
      final ramGb =
          info.physicalRamSize > 0 ? info.physicalRamSize / 1024.0 : 0.0;
      final cores = Platform.numberOfProcessors;
      final model = '${info.brand} ${info.model}'.trim();
      _lowEndDeviceModel = model;
      _lowEndDeviceCores = cores;
      _lowEndDeviceRamGb = ramGb.toDouble();
      // lowEnd already decided in FaceMinDeviceCheck (self-test / cache).
      final lowEnd = AndroidFaceCapturePerf.isLowEnd;
      if (mounted) {
        _patchState(() => _lowEndDeviceMode = lowEnd);
      } else {
        _lowEndDeviceMode = lowEnd;
      }
    } catch (e) {
      debugPrint('Timesheet Android perf profile failed: $e');
    }
  }

  Future<void> _capture() async {
    // Single-flight: auto-capture timer, manual shutter and external chrome
    // can all fire in the same window — only the first one runs.
    if (_isCapturing || _bestFrameManualWaiting) {
      debugPrint('FaceCapture: shutter ignored — capture already running');
      return;
    }
    if (_awaitingTarget) {
      debugPrint('FaceCapture: shutter blocked — no target labor');
      _showCaptureBlockedMessage(_selectLaborText);
      return;
    }
    final previewId = _livePreviewEmployeeId;
    if (_shouldHoldDuplicateFrame) {
      final kind = _liveOverlayHint?.kind;
      debugPrint('FaceCapture: shutter blocked — ${kind?.name ?? 'hold'}');
      final name = _liveOverlayHint?.employeeName?.trim();
      final who = name == null || name.isEmpty ? 'This labor' : name;
      _showCaptureBlockedMessage(
        kind == TimesheetFaceFrameKind.outOfTeam
            ? "$who is not on this project's labor list — cannot add"
            : '$who is already added',
      );
      return;
    }
    if (previewId != null && _isEmployeeAlreadyCaptured(previewId)) {
      debugPrint('FaceCapture: shutter blocked — emp $previewId captured');
      return;
    }
    // Best-frame: quality gates do not block the shutter (TASK 08 §6).
    if (!_bestFrameModeActive && !_qualityReady) {
      debugPrint('FaceCapture: shutter blocked — quality not ready');
      return;
    }
    if (_verificationInFlight) {
      debugPrint('FaceCapture: shutter blocked — PAD in flight');
      return;
    }
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    unawaited(HapticFeedback.lightImpact());

    // TASK 08 — continuous evidence path (switch on, 1:1 only).
    if (_bestFrameModeActive) {
      await _captureBestFrameManual();
      return;
    }

    _patchState(() => _isCapturing = true);
    final tapAt = DateTime.now();
    final fast = _fastAcceptFrames(tapAt);
    if (fast.frames != null) {
      await _fastAccept(tapAt, fast);
      return;
    }
    debugPrint('FaceCapture: slow path reason=${fast.reason}');
    _slowPathStartedAt = tapAt;

    // Task 5a — PAD burst only at capture (never on the live stream).
    final padOk = await _runCaptureTimePadBurst();
    if (!padOk) {
      _patchState(() => _isCapturing = false);
      return;
    }
    final liveReady = _livenessGate.recognitionAllowed;

    if (_isStreaming) {
      await _stopImageStream();
    } else if (_iosPollingDetection) {
      await _stopIosPollingDetection();
    }
    await Future<void>.delayed(_shutterSettleDelay);
    final photo = await _takePictureWithRetry();
    if (!mounted) return;
    if (photo == null) {
      // Back off auto-capture so it doesn't hammer a camera that is still
      // finishing the previous still.
      _armAutoCaptureCooldown(const Duration(milliseconds: 1500));
      _patchState(() => _isCapturing = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Camera is finishing the last photo — try again'),
            duration: Duration(seconds: 2),
          ),
        );
      await _startLiveDetection();
      return;
    }

    var captureResult = await _faceService.analyzeImageFile(photo.path);
    if (!captureResult.quality.canCapture && liveReady) {
      captureResult = await _faceService.analyzeImageFile(
        photo.path,
        relaxedQuality: true,
        trustLiveGate: true,
      );
    }
    if (!mounted) return;
    _patchState(() => _faceResult = captureResult);

    if (!captureResult.quality.canCapture) {
      _patchState(() => _isCapturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(captureResult.quality.message)),
      );
      await _startLiveDetection();
      return;
    }

    final shutterBox = _largestFaceBox(captureResult.faceBoxes);
    if (shutterBox != null) {
      final shutterResult = await _burstPipeline.verifySingleFrame(
        BurstFrameSample(
          imagePath: photo.path,
          faceBox: shutterBox,
          classification: captureResult.classification,
        ),
      );
      _syncLivenessSnapshot();
      if (!shutterResult.passed) {
        _patchState(() => _isCapturing = false);
        try {
          await File(photo.path).delete();
        } catch (_) {}
        _blockReplayAttempt(shutterResult.message);
        return;
      }
    }

    final draft = _buildCaptureDraft(photo.path);

    if (widget.verifyTarget) {
      await _decideStillVerify(
        photo: photo,
        captureResult: captureResult,
        draft: draft,
      );
      return;
    }
    await _decideStillLegacy1toN(
      photo: photo,
      captureResult: captureResult,
      draft: draft,
    );
  }

  AttendanceCaptureDraft _buildCaptureDraft(String cropPath) {
    final position = _position;
    final capture = widget.capture;
    final now = DateTime.now();
    final workDate = capture.workDate;
    final capturedAt = workDate != null
        ? DateTime(
            workDate.year,
            workDate.month,
            workDate.day,
            now.hour,
            now.minute,
            now.second,
          )
        : now;
    final livenessLog = _livenessGate.snapshot.lastLog;
    return AttendanceCaptureDraft(
      id: 'capture_${capturedAt.millisecondsSinceEpoch}',
      projectId: capture.projectId,
      taskId: capture.taskId,
      event: capture.event,
      createdAt: capturedAt,
      cropLocalPath: cropPath,
      lat: position?.latitude,
      lon: position?.longitude,
      workerId: capture.targetWorkerId,
      syncState: AttendanceCaptureSyncState.pending,
      livenessFlagged: false,
      livenessLogJson: livenessLog?.toJson(),
      awsLivenessSessionId: livenessLog?.awsSessionId,
      awsLivenessConfidence: livenessLog?.awsConfidence,
    );
  }

  DateTime? _slowPathStartedAt;

  /// The 4 buffered stream frames (with landmarks and the preview's stored
  /// 1:1 result per frame) for a fast accept, or why there are none.
  _FastFrames _fastAcceptFrames(DateTime now) {
    _FastFrames no(String reason) =>
        (frames: null, faces: const [], verifies: const [], reason: reason);
    final target = widget.targetEmployee;
    if (!widget.verifyTarget) return no('not_1to1');
    if (target == null) return no('no_target');
    if (!_isStreaming) return no('no_stream');
    // Only a green badge at tap time; identity is decided by the burst frames.
    if (_previewVerify == null ||
        _previewVerifiedEmployeeId != target.employeeId ||
        !_previewTargetVerified) {
      return no('preview_not_verified');
    }
    const need = AntispoofConfig.burstFrameCount;
    if (_streamSampleRing.length < need ||
        _streamSampleTimes.length != _streamSampleRing.length ||
        _streamSampleFaces.length != _streamSampleRing.length ||
        _streamSampleVerify.length != _streamSampleRing.length) {
      return no('ring ${_streamSampleRing.length}/$need');
    }
    final start = _streamSampleRing.length - need;
    final frames = _streamSampleRing.sublist(start);
    if (frames.any((f) => f.rgbFrame == null)) return no('ring_no_rgb');
    final oldest = now.difference(_streamSampleTimes[start]);
    if (oldest > AntispoofConfig.livenessCaptureTtl) {
      return no('ring_stale ms=${oldest.inMilliseconds}');
    }
    return (
      frames: List<BurstFrameSample>.unmodifiable(frames),
      faces: List<TimesheetFaceLandmarkSnapshot?>.unmodifiable(
        _streamSampleFaces.sublist(start),
      ),
      verifies: List<FaceVerifyResult?>.unmodifiable(
        _streamSampleVerify.sublist(start),
      ),
      reason: '',
    );
  }

  String? _tempDirPath;

  Future<String> _tempDir() async =>
      _tempDirPath ??= (await getTemporaryDirectory()).path;

  /// Index of the largest face, latest on ties: the frame closest to the
  /// press that shows the face best.
  int _bestStreamFrameIndex(List<BurstFrameSample> frames) {
    var best = frames.length - 1;
    var bestArea = frames[best].faceBox.width * frames[best].faceBox.height;
    for (var i = frames.length - 1; i >= 0; i--) {
      final box = frames[i].faceBox;
      final area = box.width * box.height;
      if (area > bestArea) {
        best = i;
        bestArea = area;
      }
    }
    return best;
  }

  static const int _fastMinBurstVerified = 3;

  /// Background half of a fast accept (the card is already shown): photo
  /// file, then queue entry. On failure nothing stays queued and the host
  /// removes the capture.
  Future<bool> _persistFastCapture({
    required img.Image frame,
    required AttendanceCaptureDraft draft,
    required TimesheetOdooEmployee target,
  }) async {
    final sw = Stopwatch()..start();
    final path = draft.cropLocalPath;
    try {
      final bytes = await compute(_encodeCaptureJpeg, frame);
      await File(path).writeAsBytes(bytes, flush: true);
      await _queueService.enqueue(draft);
      debugPrint(
        'FaceCapture: fast capture saved ms=${sw.elapsedMilliseconds} '
        'emp=${target.employeeId}',
      );
      return true;
    } catch (e) {
      debugPrint(
        'FaceCapture: fast capture save failed emp=${target.employeeId}: $e',
      );
      await _safeDeleteFile(path);
      if (mounted) widget.onCaptureWriteFailed?.call(target, draft);
      return false;
    }
  }

  Future<bool> _persistFastCaptureJpeg({
    required List<int> jpegBytes,
    required AttendanceCaptureDraft draft,
    required TimesheetOdooEmployee target,
  }) async {
    final sw = Stopwatch()..start();
    final path = draft.cropLocalPath;
    try {
      await File(path).writeAsBytes(jpegBytes, flush: true);
      await _queueService.enqueue(draft);
      debugPrint(
        'FaceCapture: fast capture jpeg saved ms=${sw.elapsedMilliseconds} '
        'emp=${target.employeeId} bytes=${jpegBytes.length}',
      );
      return true;
    } catch (e) {
      debugPrint(
        'FaceCapture: fast capture jpeg save failed emp=${target.employeeId}: $e',
      );
      await _safeDeleteFile(path);
      if (mounted) widget.onCaptureWriteFailed?.call(target, draft);
      return false;
    }
  }

  /// 1:1 fast accept (user-approved): the preview already verified the target
  /// and the full burst runs on the 4 stream frames buffered before the press
  /// — no still photo. Those same frames must then verify as the target (best
  /// frame and at least 3 of 4), reusing the preview's stored result per frame
  /// and verifying only frames without one. Every outcome is final; the photo
  /// and queue entry are written after the card is shown.
  Future<void> _fastAccept(DateTime tapAt, _FastFrames fast) async {
    final target = widget.targetEmployee!;
    final frames = fast.frames!;
    final faces = fast.faces;
    int ms() => DateTime.now().difference(tapAt).inMilliseconds;

    final padOk = await _runCaptureTimePadBurst(streamFrames: frames);
    // Frames judged once are never reused by a later attempt.
    await _clearStreamSampleRing();
    if (!mounted) return;
    if (!padOk) {
      debugPrint('FaceCapture: fast path PAD blocked ms=${ms()}');
      _patchState(() => _isCapturing = false);
      _armAutoCaptureCooldown();
      return;
    }
    if (widget.targetEmployee?.employeeId != target.employeeId) {
      debugPrint('FaceVerify: target changed during capture — discarded');
      _patchState(() => _isCapturing = false);
      return;
    }

    // Identity on the exact frames that passed anti-spoof (same bars/cohort).
    final phaseB = widget.faceRecognition;
    if (phaseB == null || !phaseB.isReady) {
      debugPrint('FaceCapture: fast reject reason=verifier_not_ready');
      _patchState(() => _isCapturing = false);
      _armAutoCaptureCooldown();
      _showCaptureBlockedMessage('Face match failed — try again');
      return;
    }
    final bestIndex = _bestStreamFrameIndex(frames);
    final results = <FaceVerifyResult>[];
    var stored = 0;
    for (var i = 0; i < frames.length; i++) {
      final cached = fast.verifies[i];
      if (cached != null && cached.targetEmployeeId == target.employeeId) {
        results.add(cached);
        stored++;
        continue;
      }
      results.add(
        await phaseB.verifyImage(
          source: frames[i].rgbFrame!,
          faceBox: frames[i].faceBox,
          targetEmployeeId: target.employeeId,
          landmarks: faces[i],
        ),
      );
      if (!mounted) return;
    }
    final verify = results[bestIndex];
    final verifiedCount = results.where((r) => r.isVerified).length;
    final n = '$verifiedCount/${frames.length} stored=$stored';
    if (widget.targetEmployee?.employeeId != target.employeeId) {
      debugPrint('FaceVerify: target changed during capture — discarded');
      _patchState(() => _isCapturing = false);
      return;
    }
    if (!verify.isVerified || verifiedCount < _fastMinBurstVerified) {
      debugPrint(
        'FaceCapture: fast reject reason=burst_identity $n '
        'best=${verify.outcome.name} '
        't=${verify.targetScore?.toStringAsFixed(2)} ms=${ms()}',
      );
      _patchState(() => _isCapturing = false);
      _armAutoCaptureCooldown();
      _clearBadgeNow(reason: 'fast_burst_identity');
      unawaited(_alarm.playMismatch(key: target.employeeId));
      widget.onTargetVerifyFailed?.call(
        target,
        FaceVerifyResult(
          outcome: FaceVerifyOutcome.lowScore,
          targetEmployeeId: target.employeeId,
          targetScore: verify.targetScore,
          cohortMaxScore: verify.cohortMaxScore,
          cohortMaxEmployeeId: verify.cohortMaxEmployeeId,
          lead: verify.lead,
          cohortSize: verify.cohortSize,
          usedNoCohortBar: verify.usedNoCohortBar,
          faceWidthPx: verify.faceWidthPx,
        ),
      );
      return;
    }

    final best = frames[bestIndex];
    if (_isEmployeeAlreadyCaptured(target.employeeId)) {
      final replay = !(await _burstPipeline.verifySingleFrame(best)).passed;
      if (!mounted) return;
      debugPrint('FaceCapture: fast path already attended replay=$replay');
      _patchState(() => _isCapturing = false);
      _armAutoCaptureCooldown();
      if (replay) {
        _blockReplayAttempt('Presentation attack detected — use live face');
      } else {
        _enterDuplicatePreview(target);
      }
      return;
    }
    if (!_isOnProjectLaborList(target.employeeId)) {
      _patchState(() => _isCapturing = false);
      _armAutoCaptureCooldown();
      _showCaptureBlockedMessage(
        "${target.name} is not on this project's labor list — cannot add",
      );
      return;
    }

    final path =
        '${await _tempDir()}/ts_fast_${DateTime.now().microsecondsSinceEpoch}.jpg';
    if (!mounted) return;

    // Reached only after the full burst anti-spoof passed.
    final audited = _buildCaptureDraft(path).withFaceAudit(
      verified: true,
      score: verify.targetScore,
      lead: verify.usedNoCohortBar ? null : verify.lead,
      cohortSize: verify.cohortSize,
      liveness: 'pass',
    );
    debugPrint(
      'FaceCapture: fast accept ms=${ms()} burstVerified=$n '
      't=${verify.targetScore?.toStringAsFixed(2)} '
      'lead=${verify.usedNoCohortBar ? 'n/a' : verify.lead?.toStringAsFixed(2)} '
      'emp=${target.employeeId}',
    );
    _patchState(() => _isCapturing = false);
    _armAutoCaptureCooldown();
    _markJustCaptured(target.employeeId);
    widget.onTargetVerified?.call(target, audited, verify);
    unawaited(
      _speech.speakEmployeeDetected(target.name, employeeId: target.employeeId),
    );
    PendingCaptureWrites.track(
      _persistFastCapture(
        frame: best.rgbFrame!,
        draft: audited,
        target: target,
      ),
    );
    _livenessGate.resetSession();
    _syncLivenessSnapshot();
    _clearLiveOverlay();
  }

  /// 1:1 decision on the still (anti-spoof already passed). Only the target
  /// is ever named; every branch except an accepted capture deletes the photo.
  Future<void> _decideStillVerify({
    required XFile photo,
    required TimesheetFaceDetectionResult captureResult,
    required AttendanceCaptureDraft draft,
  }) async {
    final target = widget.targetEmployee;
    final phaseB = widget.faceRecognition;
    final faceBox = _largestFaceBox(captureResult.faceBoxes);

    Future<void> reject() async {
      _patchState(() => _isCapturing = false);
      _armAutoCaptureCooldown();
      await _safeDeleteFile(photo.path);
    }

    if (target == null) {
      await reject();
      _showCaptureBlockedMessage(_selectLaborText);
      await _startLiveDetection();
      return;
    }
    if (phaseB == null || !phaseB.isReady || faceBox == null) {
      debugPrint(
        'FaceVerify: skipped — ready=${phaseB?.isReady} box=${faceBox != null}',
      );
      await reject();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Face match failed — try again')),
        );
      }
      await _startLiveDetection();
      return;
    }

    final matchImagePath = captureResult.analyzedImagePath ?? photo.path;
    final verify = await phaseB.verifyCapturePhoto(
      imagePath: matchImagePath,
      faceBox: faceBox,
      targetEmployeeId: target.employeeId,
      landmarks: captureResult.primaryFace,
    );
    if (!mounted) return;
    if (widget.targetEmployee?.employeeId != target.employeeId) {
      debugPrint('FaceVerify: target changed during capture — discarded');
      await reject();
      await _startLiveDetection();
      return;
    }

    switch (verify.outcome) {
      case FaceVerifyOutcome.verified:
        if (_isEmployeeAlreadyCaptured(target.employeeId)) {
          final likelyReplay = await _isLikelyReplayFrame(
            imagePath: matchImagePath,
            faceBox: faceBox,
            classification: captureResult.classification,
          );
          await reject();
          if (likelyReplay) {
            _blockReplayAttempt('Presentation attack detected — use live face');
          } else {
            _enterDuplicatePreview(target);
          }
          await _startLiveDetection();
          return;
        }
        if (!_isOnProjectLaborList(target.employeeId)) {
          await reject();
          _showCaptureBlockedMessage(
            "${target.name} is not on this project's labor list — cannot add",
          );
          await _startLiveDetection();
          return;
        }
        // Reached only after the burst + shutter anti-spoof passed.
        final audited = draft.withFaceAudit(
          verified: true,
          score: verify.targetScore,
          lead: verify.usedNoCohortBar ? null : verify.lead,
          cohortSize: verify.cohortSize,
          liveness: 'pass',
        );
        await _queueService.enqueue(audited);
        final startedAt = _slowPathStartedAt;
        debugPrint(
          'FaceCapture: slow path accept ms='
          '${startedAt == null ? '?' : DateTime.now().difference(startedAt).inMilliseconds} '
          'emp=${target.employeeId}',
        );
        _patchState(() => _isCapturing = false);
        _armAutoCaptureCooldown();
        _markJustCaptured(target.employeeId);
        widget.onTargetVerified?.call(target, audited, verify);
        unawaited(
          _speech.speakEmployeeDetected(
            target.name,
            employeeId: target.employeeId,
          ),
        );
      case FaceVerifyOutcome.lowScore:
      case FaceVerifyOutcome.notDistinct:
        await reject();
        _clearBadgeNow(reason: 'verify_${verify.outcome.name}');
        unawaited(_alarm.playMismatch(key: target.employeeId));
        widget.onTargetVerifyFailed?.call(target, verify);
      case FaceVerifyOutcome.noTemplate:
        await reject();
        _clearBadgeNow(reason: 'verify_no_template');
        widget.onTargetVerifyFailed?.call(target, verify);
      case FaceVerifyOutcome.faceTooSmall:
        await reject();
        _instantCaptureArmed = true;
        _showCaptureBlockedMessage('Come closer to the camera');
        widget.onTargetVerifyFailed?.call(target, verify);
      case FaceVerifyOutcome.error:
        await reject();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Face match failed — try again')),
          );
        }
        widget.onTargetVerifyFailed?.call(target, verify);
    }
    await _startLiveDetection();
  }

  // ---------------------------------------------------------------------------
  // AT2 only — legacy 1:N matching. Never reached in verifyTarget mode
  // (asserted). Remove this whole section once AT2 moves to 1:1.
  // ---------------------------------------------------------------------------

  Future<void> _applyLivePreviewMatchFromImage(
    TimesheetFaceDetectionResult result,
    img.Image source, {
    bool captureImmediately = false,
  }) async {
    _assertLegacy1toN('live preview (stream)');
    final suppressed = _suppressEmbeddingPreviewUntil;
    if (suppressed != null && DateTime.now().isBefore(suppressed)) {
      return;
    }
    final phaseB = widget.faceRecognition;
    final faceBox = _largestFaceBox(result.faceBoxes);
    if (phaseB == null || !phaseB.isReady || faceBox == null) return;

    final match = await phaseB.matchImage(
      source: source,
      faceBox: faceBox,
      landmarks: result.primaryFace,
    );
    if (!mounted) return;

    if (match == null || match.best == null || !match.passesDisplayThreshold) {
      _suppressEmbeddingPreviewUntil =
          DateTime.now().add(_previewSuppressAfterMiss);
      _clearBadgeNow(reason: 'sub_threshold');
      return;
    }
    _suppressEmbeddingPreviewUntil = null;
    _lastBadgeQualifyingAt = DateTime.now();

    final emp = phaseB.employeeFromMatch(match);
    if (emp == null) {
      _clearBadgeNow(reason: 'no_employee');
      return;
    }
    if (!captureImmediately &&
        !await _previewFaceIsLive(faceBox: faceBox, rgbFrame: source)) {
      return;
    }
    if (!mounted) return;

    if (!_acceptStablePreviewIdentity(
      emp.employeeId,
      force: captureImmediately,
    )) {
      return;
    }

    _livePreviewEmployeeId = emp.employeeId;

    // Yellow: recognized but not on this project labor list (badge only).
    if (!_isOnProjectLaborList(emp.employeeId)) {
      setState(() {
        _liveOverlayHint = TimesheetFaceOverlayHint.outOfTeam(
          name: emp.name,
          fileId: emp.displayFileId,
        );
        _livePreviewBlockCapture = true;
        _livePreviewAllowAutoCapture = false;
      });
      _emitChrome();
      return;
    }

    if (_isEmployeeAlreadyCaptured(emp.employeeId)) {
      _enterDuplicatePreview(emp);
      return;
    }

    // Stream scores are weak. Show green badge at display bar; only auto-capture
    // when score is strong enough that the still is likely to clear match bar.
    final score = match.bestScore;
    _livePreviewScore = score;
    final mayAutoCapture =
        score >= FaceRecognitionMatch.pilotAutoCaptureMinScore;
    setState(() {
      _liveOverlayHint = TimesheetFaceOverlayHint.inTeam(
        name: emp.name,
        fileId: emp.displayFileId,
      );
      _livePreviewBlockCapture = false;
      _livePreviewAllowAutoCapture = mayAutoCapture;
    });
    unawaited(
        _speech.speakEmployeeDetected(emp.name, employeeId: emp.employeeId));
    if (!mayAutoCapture) {
      debugPrint(
        'FaceCapture: badge only score=${score.toStringAsFixed(3)} '
        '(need >= ${FaceRecognitionMatch.pilotAutoCaptureMinScore} to auto-capture)',
      );
      return;
    }
    if (captureImmediately && widget.autoCaptureEnabled && !_noticeHold) {
      unawaited(_capture());
    } else {
      _scheduleAutoCapture();
    }
  }

  /// Still-capture path (`ts_norm` / takePicture) — file-based match.
  Future<void> _applyLivePreviewMatch(
    TimesheetFaceDetectionResult result,
    String imagePath, {
    bool captureImmediately = false,
  }) async {
    _assertLegacy1toN('live preview (iOS polling)');
    final suppressed = _suppressEmbeddingPreviewUntil;
    if (suppressed != null && DateTime.now().isBefore(suppressed)) {
      return;
    }
    final phaseB = widget.faceRecognition;
    final faceBox = _largestFaceBox(result.faceBoxes);
    if (phaseB == null || !phaseB.isReady || faceBox == null) return;

    final match = await phaseB.matchCapturePhoto(
      imagePath: imagePath,
      faceBox: faceBox,
      landmarks: result.primaryFace,
    );
    if (!mounted) return;

    if (match == null || match.best == null || !match.passesDisplayThreshold) {
      _suppressEmbeddingPreviewUntil =
          DateTime.now().add(_previewSuppressAfterMiss);
      _clearBadgeNow(reason: 'sub_threshold');
      return;
    }
    _suppressEmbeddingPreviewUntil = null;
    _lastBadgeQualifyingAt = DateTime.now();

    final emp = phaseB.employeeFromMatch(match);
    if (emp == null) {
      _clearBadgeNow(reason: 'no_employee');
      return;
    }
    if (!captureImmediately &&
        !await _previewFaceIsLive(faceBox: faceBox, imagePath: imagePath)) {
      return;
    }
    if (!mounted) return;

    if (!_acceptStablePreviewIdentity(
      emp.employeeId,
      force: captureImmediately,
    )) {
      return;
    }

    _livePreviewEmployeeId = emp.employeeId;

    if (!_isOnProjectLaborList(emp.employeeId)) {
      setState(() {
        _liveOverlayHint = TimesheetFaceOverlayHint.outOfTeam(
          name: emp.name,
          fileId: emp.displayFileId,
        );
        _livePreviewBlockCapture = true;
        _livePreviewAllowAutoCapture = false;
      });
      _emitChrome();
      return;
    }

    if (_isEmployeeAlreadyCaptured(emp.employeeId)) {
      final likelyReplay = await _isLikelyReplayFrame(
        imagePath: imagePath,
        faceBox: faceBox,
        classification: result.classification,
      );
      if (!mounted) return;
      if (likelyReplay) {
        _blockReplayAttempt('Presentation attack detected — use live face');
        return;
      }
      _enterDuplicatePreview(emp);
      return;
    }

    final score = match.bestScore;
    _livePreviewScore = score;
    final mayAutoCapture =
        score >= FaceRecognitionMatch.pilotAutoCaptureMinScore;
    setState(() {
      _liveOverlayHint = TimesheetFaceOverlayHint.inTeam(
        name: emp.name,
        fileId: emp.displayFileId,
      );
      _livePreviewBlockCapture = false;
      _livePreviewAllowAutoCapture = mayAutoCapture;
    });
    unawaited(
        _speech.speakEmployeeDetected(emp.name, employeeId: emp.employeeId));
    if (!mayAutoCapture) return;
    if (captureImmediately && widget.autoCaptureEnabled && !_noticeHold) {
      unawaited(_capture());
    } else {
      _scheduleAutoCapture();
    }
  }

  Future<void> _decideStillLegacy1toN({
    required XFile photo,
    required TimesheetFaceDetectionResult captureResult,
    required AttendanceCaptureDraft draft,
  }) async {
    _assertLegacy1toN('still decision');
    final faceBox = _largestFaceBox(captureResult.faceBoxes);
    final faceLandmarks = captureResult.primaryFace;
    final phaseB = widget.faceRecognition;
    if (phaseB != null && faceBox != null) {
      if (!phaseB.isReady) {
        debugPrint(
          'FaceRecognition: Phase B skipped — not ready '
          '(last=${phaseB.lastSync?.status})',
        );
      } else if (widget.onRosterEmployeeMatched == null) {
        debugPrint('FaceRecognition: Phase B skipped — no roster callback');
      }
    }
    if (phaseB != null &&
        phaseB.isReady &&
        faceBox != null &&
        widget.onRosterEmployeeMatched != null) {
      final matchImagePath = captureResult.analyzedImagePath ?? photo.path;
      debugPrint(
        'FaceRecognition: running Phase B match image=$matchImagePath',
      );
      final match = await phaseB.matchCapturePhoto(
        imagePath: matchImagePath,
        faceBox: faceBox,
        landmarks: faceLandmarks,
      );
      if (!mounted) return;
      final score = match?.bestScore ?? 0;
      final best = match?.best;
      // Yellow path: soft display bar (name only, cannot add).
      if (match != null &&
          best != null &&
          match.passesDisplayThreshold &&
          !_isOnProjectLaborList(best.employeeId)) {
        final emp = phaseB.employeeFromMatch(match);
        if (emp != null) {
          _patchState(() => _isCapturing = false);
          _armAutoCaptureCooldown();
          widget.onOutOfTeamRecognized?.call(emp, draft, score);
          try {
            await File(photo.path).delete();
          } catch (_) {}
          await _startLiveDetection();
          return;
        }
      }
      // Green / add: match bar (15%), or soft accept if stream locked same person.
      // Prefer detect over "No Face" whenever a clear in-team winner exists.
      final streamLockedId = _livePreviewEmployeeId;
      final clearInTeamWinner = match != null &&
          best != null &&
          _isOnProjectLaborList(best.employeeId) &&
          match.bestScore >= FaceRecognitionMatch.activeMatchThreshold &&
          match.passesDisplayThreshold;
      final softAccept = best != null &&
          streamLockedId != null &&
          best.employeeId == streamLockedId &&
          match != null &&
          match.passesDisplayThreshold &&
          match.bestScore >= FaceRecognitionMatch.pilotSoftCaptureThreshold;
      if (match != null &&
          best != null &&
          (match.isMatch || softAccept || clearInTeamWinner)) {
        if (!match.isMatch) {
          debugPrint(
            'FaceCapture: accept still=${match.bestScore.toStringAsFixed(3)} '
            'second=${match.secondBestScore.toStringAsFixed(3)} '
            'streamLocked=$streamLockedId soft=$softAccept clear=$clearInTeamWinner',
          );
        }
        final emp = phaseB.employeeFromMatch(match);
        if (emp != null) {
          if (_isEmployeeAlreadyCaptured(emp.employeeId)) {
            final likelyReplay = await _isLikelyReplayFrame(
              imagePath: matchImagePath,
              faceBox: faceBox,
              classification: captureResult.classification,
            );
            _patchState(() => _isCapturing = false);
            _armAutoCaptureCooldown();
            try {
              await File(photo.path).delete();
            } catch (_) {}
            if (likelyReplay) {
              _blockReplayAttempt(
                  'Presentation attack detected — use live face');
              await _startLiveDetection();
              return;
            }
            _enterDuplicatePreview(emp);
            await _startLiveDetection();
            return;
          }
          await _queueService.enqueue(draft);
          _patchState(() => _isCapturing = false);
          _armAutoCaptureCooldown();
          _markJustCaptured(emp.employeeId);
          widget.onRosterEmployeeMatched!(
            emp,
            draft,
            score,
            secondBestScore: match.secondBestScore,
            closeSecondCandidate: match.hasCloseSecondCandidate,
          );
          await _startLiveDetection();
          return;
        }
      }
      _patchState(() => _isCapturing = false);
      _armAutoCaptureCooldown();
      try {
        await File(photo.path).delete();
      } catch (_) {}
      widget.onNoEmbeddingMatch?.call(
        draft,
        bestScore: score > 0 ? score : null,
        closestName: best?.name,
      );
      await _startLiveDetection();
      return;
    }

    final cropBytes = captureResult.cropBytes;
    final roster = widget.rosterEmployees;
    if (cropBytes != null &&
        roster != null &&
        roster.isNotEmpty &&
        widget.onRosterEmployeeMatched != null) {
      final withPhotos = roster.where((e) => e.canUseFaceMatch).length;
      final local = await _rosterMatcher.matchProbe(
        probeCropJpeg: cropBytes,
        roster: roster,
        httpHeaders: _faceMatchHttpHeaders(),
      );
      if (!mounted) return;
      _patchState(() => _isCapturing = false);
      if (local != null) {
        if (!_isOnProjectLaborList(local.employee.employeeId)) {
          widget.onOutOfTeamRecognized?.call(
            local.employee,
            draft,
            1.0 - (local.score / 7200).clamp(0.0, 1.0),
          );
          try {
            await File(photo.path).delete();
          } catch (_) {}
          await _startLiveDetection();
          return;
        }
        if (widget.capturedEmployeeIds.contains(local.employee.employeeId)) {
          _enterDuplicatePreview(local.employee);
          try {
            await File(photo.path).delete();
          } catch (_) {}
          await _startLiveDetection();
          return;
        }
        await _queueService.enqueue(draft);
        _markJustCaptured(local.employee.employeeId);
        widget.onRosterEmployeeMatched!(
          local.employee,
          draft,
          1.0 - (local.score / 7200).clamp(0.0, 1.0),
        );
        await _startLiveDetection();
        return;
      }
      final msg = withPhotos == 0
          ? 'No labors with HR profile photos on this project — pick employee manually'
          : 'No match to labor face photos — pick employee manually';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }

    TimesheetMatchAttendanceResult match;
    try {
      match = await _flowService.matchCapture(draft);
    } catch (error) {
      if (!mounted) return;
      _patchState(() => _isCapturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Face match failed: $error')),
      );
      await _startLiveDetection();
      return;
    }

    if (!mounted) return;
    _patchState(() => _isCapturing = false);

    widget.onCaptureMatched?.call(match, draft);
    await _startLiveDetection();
  }

  // ------------------------- end of AT2-only legacy 1:N ----------------------

  Future<void> _initializeCamera({CameraDescription? cameraOverride}) async {
    if (_cameraInitInFlight) return;
    // Re-running prepare (DeviceCheck / resume) must not dispose+recreate the
    // live controller — that kills the image stream and often drops the
    // debugger connection on iOS ("Lost connection to device").
    if (cameraOverride == null &&
        _cameraController?.value.isInitialized == true) {
      debugPrint('FaceCapture: camera already initialized — skip re-init');
      return;
    }
    _cameraInitInFlight = true;
    if (mounted) {
      setState(() {
        _isInitializingCamera = true;
        _cameraError = null;
      });
    }

    try {
      final cameras = await _faceService.availableCameraDescriptions();
      if (cameras.isEmpty) {
        throw StateError('No camera found on this device');
      }
      final selected = cameraOverride ??
          cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
            orElse: () => cameras.first,
          );
      // Low-end: medium (≈640×480) for smoother stream; others keep ≈720p.
      // Preview and image stream share the same preset in camera plugin.
      final preset = Platform.isAndroid && AndroidFaceCapturePerf.preferMediumStream
          ? ResolutionPreset.medium
          : ResolutionPreset.high;
      debugPrint(
        'FaceCapture: camera preset=$preset '
        'lowEnd=${AndroidFaceCapturePerf.isLowEnd}',
      );
      final controller = CameraController(
        selected,
        preset,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : null,
      );
      await controller.initialize();
      // The UI is portrait-only here; pinning capture orientation keeps
      // CameraPreview's aspect/rotation and still-photo EXIF consistent on
      // landscape-native tablets, whose sensor listener otherwise flips the
      // preview geometry and stretches it.
      try {
        await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      } catch (e) {
        debugPrint('FaceCapture: lockCaptureOrientation failed: $e');
      }
      await controller.setFlashMode(FlashMode.off);
      await controller.setFocusMode(FocusMode.auto);
      await controller.setExposureMode(ExposureMode.auto);
      await _resetCameraZoom(controller);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await _cameraController?.dispose();
      setState(() {
        _availableCameras = cameras;
        _camera = selected;
        _cameraController = controller;
        _flashEnabled = false;
        _isInitializingCamera = false;
      });
      await _startLiveDetection();
      // An immediate zoom reset right after initialize() is frequently ignored
      // by the platform while the preview is warming up, which leaves a stuck
      // digital zoom after switching cameras. Re-apply once the preview settles.
      unawaited(_settleCameraZoom());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isInitializingCamera = false;
        _cameraError = error.toString();
      });
    } finally {
      _cameraInitInFlight = false;
    }
  }

  Future<void> _startLiveDetection() async {
    if (_pipelinePausedForPanel) return;
    _awsLivenessLaunched = false;
    _livenessRetryTimer?.cancel();
    _clearLiveOverlay();
    await _clearBurstSamples();
    await _clearStreamSampleRing();
    _clearBestFrameWindow();
    _livenessGate.resetSession();
    _syncLivenessSnapshot();
    _padScoreFrameSeq = 0;
    _maxLiveOnUnverifiedOrRejected = 0;
    _detectFrameCount = 0;
    _detectSkippedWhileBusy = 0;
    _detectConversionMsSum = 0;
    _detectMsSum = 0;
    _detectFpsWindowStart = DateTime.fromMillisecondsSinceEpoch(0);
    _lastDetectFpsLogAt = DateTime.fromMillisecondsSinceEpoch(0);
    if (_bestFrameModeActive) {
      debugPrint(
        'BestFrame: session start min_live_frames='
        '${AppConfigService.instance.faceBestFrameMinLiveFrames} '
        'attack_test=${AppConfigService.instance.isTestMode ? 1 : 0}',
      );
    }
    FaceRecognitionService.resetDebugAlignDumpForCameraOpen();
    if (Platform.isAndroid) {
      // Self-test runs in FaceMinDeviceCheck (cached per app version+device).
      _faceService.resetAllocLogForCameraOpen();
      _faceService.logDetectorOnCameraOpen();
      _startAndroidPerfUiLog();
    }
    if (Platform.isIOS) {
      try {
        await _startImageStream();
        return;
      } catch (error) {
        debugPrint(
            'Timesheet iOS image stream unavailable, using polling: $error');
      }
      await _startIosPollingDetection();
      return;
    }
    await _startImageStream();
  }

  Future<void> _stopLiveDetection() async {
    await _stopImageStream();
    await _stopIosPollingDetection();
  }

  Future<void> _startIosPollingDetection() async {
    if (!Platform.isIOS || _iosPollingDetection) return;
    _iosPollingDetection = true;
    _iosPollingTimer?.cancel();
    _iosPollingTimer = Timer.periodic(
      const Duration(milliseconds: 850),
      (_) => unawaited(_runIosPollingFrame()),
    );
    await _runIosPollingFrame();
  }

  Future<void> _stopIosPollingDetection() async {
    _iosPollingDetection = false;
    _iosPollingTimer?.cancel();
    _iosPollingTimer = null;
  }

  Future<void> _runIosPollingFrame() async {
    final controller = _cameraController;
    if (_pipelinePausedForPanel ||
        !_iosPollingDetection ||
        controller == null ||
        !controller.value.isInitialized ||
        _isCapturing ||
        _isDetectingFrame) {
      return;
    }
    _isDetectingFrame = true;
    try {
      final photo = await _takePictureExclusive(controller);
      if (_isCapturing || !_iosPollingDetection) {
        unawaited(_safeDeleteFile(photo.path));
        return;
      }
      var result = await _faceService.analyzeImageFile(
        photo.path,
        includeCrop: false,
        trustLiveGate: true,
      );
      final matchPath = result.analyzedImagePath ?? photo.path;
      if (_bestFrameModeActive) {
        if (result.faceBoxes.isEmpty) {
          _clearBadgeNow(reason: 'no_face');
          // Hint is for face-present + PAD-ineligible, not no-face.
          _clearNoUsableFrame();
        } else if (!_isCapturing && !_holdLiveMatching) {
          try {
            final bytes = await File(matchPath).readAsBytes();
            final decoded = img.decodeImage(bytes);
            final faceBox = _largestFaceBox(result.faceBoxes);
            if (decoded != null && faceBox != null && mounted) {
              final frameSize = Size(
                decoded.width.toDouble(),
                decoded.height.toDouble(),
              );
              _markerImageSize = frameSize;
              _syncDistanceSilhouetteMeta();
              if (_silhouettePendingShow) _showDistanceSilhouette();
              _updateMarkerPositionFromDetection(faceBox);
              _enqueueBestFrameEvidence(
                _BestFramePending(
                  modelRgb: decoded,
                  modelFaceBox: faceBox,
                  markerFaceBox: faceBox,
                  uprightFrameSize: frameSize,
                  result: result,
                ),
              );
            }
          } catch (e) {
            debugPrint('BestFrame: iOS frame decode failed: $e');
          }
        }
        try {
          await File(photo.path).delete();
        } catch (_) {}
        if (!mounted) return;
        setState(() => _faceResult = result);
        _emitChrome();
        return;
      }
      // Task 5a — no stream PAD on iOS polling either; badge embed only.
      if (result.faceBoxes.isEmpty) {
        _clearBadgeNow(reason: 'no_face');
      } else if (result.quality.canCapture &&
          widget.faceRecognition?.isReady == true &&
          !_isCapturing &&
          !_holdLiveMatching) {
        if (widget.verifyTarget) {
          await _applyLiveVerify(result, imagePath: matchPath);
        } else {
          await _applyLivePreviewMatch(result, matchPath);
        }
        _lastPreviewMatchAt = DateTime.now();
      }
      try {
        await File(photo.path).delete();
      } catch (_) {}
      if (!mounted) return;
      setState(() => _faceResult = result);
      _emitChrome();
    } catch (error) {
      debugPrint('Timesheet iOS polling face detection failed: $error');
    } finally {
      _isDetectingFrame = false;
    }
  }

  Future<void> _startImageStream() async {
    final controller = _cameraController;
    final camera = _camera;
    if (controller == null ||
        camera == null ||
        !controller.value.isInitialized ||
        _isStreaming) {
      return;
    }
    await controller.startImageStream((image) {
      // Drop BEFORE touching planes / NV21 / decode. Claim busy synchronously
      // so overlapping callbacks cannot all start copies.
      _streamCallbackCount += 1;
      if (_pipelinePausedForPanel ||
          _isDetectingFrame ||
          _noticeHold ||
          _isCapturing) {
        _detectSkippedWhileBusy += 1;
        return;
      }
      final now = DateTime.now();
      final minGap = _bestFrameModeActive
          ? _bestFrameProcessInterval
          : _detectInterval;
      if (now.difference(_lastFrameDetection) < minGap) {
        _detectSkippedWhileBusy += 1;
        return;
      }
      final nth = AndroidFaceCapturePerf.streamProcessEveryNth;
      if (Platform.isAndroid && nth > 1) {
        _streamDropIndex += 1;
        if (_streamDropIndex % nth != 0) {
          _detectSkippedWhileBusy += 1;
          return;
        }
      }
      _isDetectingFrame = true;
      _lastFrameDetection = now;
      _streamProcessedCount += 1;
      unawaited(_processCameraImage(image, camera));
    });
    _isStreaming = true;
  }

  Future<void> _stopImageStream() async {
    final controller = _cameraController;
    if (controller == null || !_isStreaming) return;
    try {
      await controller.stopImageStream();
    } catch (_) {}
    _isStreaming = false;
  }

  Future<void> _processCameraImage(
    CameraImage image,
    CameraDescription camera,
  ) async {
    // Busy flag already claimed in the stream callback (before plane access).
    final now = _lastFrameDetection;

    TimesheetFaceDetectionResult? detectResult;
    _BestFramePending? pendingEvidence;
    img.Image? decodedRgb;
    img.Image? ensureDecoded() =>
        decodedRgb ??= _faceService.decodeCameraImageUpright(image, camera);

    try {
      final inputImage = _faceService.buildInputImageFromCameraImage(
        image: image,
        camera: camera,
      );
      final conversionMs = _faceService.lastInputConversionMs;
      if (inputImage == null) return;
      final uprightSize = _uprightImageSize(image, camera);
      _markerImageSize = uprightSize;
      _syncDistanceSilhouetteMeta();
      if (_silhouettePendingShow) _showDistanceSilhouette();
      final detectSw = Stopwatch()..start();
      final result = await _faceService.analyzeInputImage(
        inputImage,
        imageSize: uprightSize,
        liveStream: true,
        boxScaleX: _faceService.lastDetectBoxScaleX,
        boxScaleY: _faceService.lastDetectBoxScaleY,
      );
      final detectMs = detectSw.elapsedMilliseconds;
      if (!mounted) return;
      _noteDetectMsForLowEnd(detectMs);
      _noteDetectionFps(
        now: DateTime.now(),
        conversionMs: conversionMs,
        detectMs: detectMs,
      );
      if (result.quality.canCapture) {
        _consecutiveReadyFrames = math.min(_consecutiveReadyFrames + 1, 8);
      } else {
        _consecutiveReadyFrames = 0;
      }

      // Task 6 — clear badge on no-face / stale (N=3 only gates identity switch).
      if (result.faceBoxes.isEmpty) {
        _clearBadgeNow(reason: 'no_face');
      } else {
        final lastQual = _lastBadgeQualifyingAt;
        // 1:1 re-checks a green badge every locked interval; between checks
        // only a safety-net timeout applies.
        final staleAfter = widget.verifyTarget
            ? _previewMatchIntervalLocked * 2
            : _badgeStaleTimeout;
        if (lastQual != null &&
            now.difference(lastQual) > staleAfter &&
            _liveOverlayHint != null) {
          _clearBadgeNow(reason: 'stale');
        }
      }
      _patchState(() => _faceResult = result);
      detectResult = result;

      // Copy face region while busy (before releasing planes to next frame).
      if (_bestFrameModeActive) {
        if (result.faceBoxes.isNotEmpty &&
            !_shouldHoldDuplicateFrame &&
            !_isCapturing) {
          final faceBox = _largestFaceBox(result.faceBoxes);
          if (faceBox == null) {
            _clearNoUsableFrame();
          } else {
            _updateMarkerPositionFromDetection(faceBox);
            // Android + iOS: full upright decode so landmarks/box share one
            // space with the embedding input (pre-region/downscale path).
            final rgb = ensureDecoded();
            if (rgb != null) {
              pendingEvidence = _BestFramePending(
                modelRgb: rgb,
                modelFaceBox: faceBox,
                markerFaceBox: faceBox,
                uprightFrameSize: Size(
                  rgb.width.toDouble(),
                  rgb.height.toDouble(),
                ),
                result: result,
              );
            }
          }
        } else if (result.faceBoxes.isEmpty) {
          // Delayed hint only when a face is present but PAD-ineligible.
          _clearNoUsableFrame();
        }
      } else {
        // Legacy ring / preview: copy while busy still holds the CameraImage.
        final ringMinInterval = _lowEndDeviceMode
            ? const Duration(milliseconds: 900)
            : const Duration(milliseconds: 350);
        if (result.faceBoxes.isNotEmpty &&
            DateTime.now().difference(_lastRingSampleAt) >= ringMinInterval) {
          final ringBox = _largestFaceBox(result.faceBoxes);
          final rgb = ensureDecoded();
          if (ringBox != null && rgb != null) {
            _lastRingSampleAt = DateTime.now();
            _pushStreamSample(
              BurstFrameSample(
                rgbFrame: rgb,
                faceBox: ringBox,
                classification: result.classification,
              ),
              landmarks: result.primaryFace,
            );
          }
        }
      }
    } catch (error) {
      debugPrint('Timesheet live face detection failed: $error');
    } finally {
      _isDetectingFrame = false;
    }

    if (_bestFrameModeActive) {
      final pending = pendingEvidence;
      if (pending != null) {
        _enqueueBestFrameEvidence(pending);
      }
      return;
    }
    final streamResult = detectResult;
    if (streamResult == null) return;

    try {
      // Badge embed only (no PAD on stream). RGB already captured above when
      // needed for the ring; decode again only if preview still wants it.
      if (streamResult.quality.canCapture &&
          _isStreaming &&
          !_shouldHoldDuplicateFrame &&
          !_isCapturing &&
          !_verificationInFlight) {
        unawaited(
          _runStreamEmbeddingPreview(
            image,
            streamResult,
            decodedRgb: decodedRgb,
          ),
        );
      }
    } catch (error) {
      debugPrint('Timesheet live post-detect work failed: $error');
    }
  }

  Future<void> _updateCurrentLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      if (!mounted) return;
      _patchState(() {
        _position = position;
        _geofencePreview = _geofenceService.preview(
          point: TimesheetGeoPoint(
            lat: position.latitude,
            lon: position.longitude,
          ),
          center: const TimesheetGeoPoint(lat: 25.2048, lon: 55.2708),
          radiusM: 120,
        );
      });
    } catch (_) {
      if (!mounted) return;
      _patchState(() {
        _geofencePreview = _geofenceService.preview(
          point: null,
          center: const TimesheetGeoPoint(lat: 25.2048, lon: 55.2708),
          radiusM: 120,
        );
      });
    }
  }

  Widget _buildCameraPreview() {
    final controller = _cameraController;
    if (_isInitializingCamera || _cameraInitInFlight) {
      return const Center(
        child: CircularProgressIndicator(color: TimesheetModuleColors.surface),
      );
    }
    if (_cameraError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(TimesheetModuleLayout.cardPadding),
          child: Text(
            _cameraError ?? 'Camera unavailable',
            textAlign: TextAlign.center,
            style: TimesheetModuleTypography.body().copyWith(
              color: TimesheetModuleColors.surface,
            ),
          ),
        ),
      );
    }
    if (controller == null || !controller.value.isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIcons.userFocus(),
              color: TimesheetModuleColors.surface,
              size: 72,
            ),
            const SizedBox(height: TimesheetModuleLayout.cardSpacing),
            Text(
              'Preparing camera',
              style: TimesheetModuleTypography.h2().copyWith(
                color: TimesheetModuleColors.surface,
              ),
            ),
          ],
        ),
      );
    }
    final previewSize = controller.value.previewSize;
    final previewKey = ValueKey('${_camera?.name}_${_camera?.lensDirection}');
    if (previewSize == null) {
      return Center(child: CameraPreview(controller, key: previewKey));
    }
    // CameraPreview sizes itself with AspectRatio(ar) in landscape and
    // AspectRatio(1/ar) in portrait, keyed off the controller's orientation.
    // The tight box must follow the same rule or AspectRatio is forced to fill
    // a box of the wrong shape and the image stretches.
    final orientation = controller.value.lockedCaptureOrientation ??
        controller.value.deviceOrientation;
    final portrait = orientation == DeviceOrientation.portraitUp ||
        orientation == DeviceOrientation.portraitDown;
    final longSide = math.max(previewSize.width, previewSize.height);
    final shortSide = math.min(previewSize.width, previewSize.height);
    return FittedBox(
      fit: _previewFit,
      child: SizedBox(
        width: portrait ? shortSide : longSide,
        height: portrait ? longSide : shortSide,
        child: CameraPreview(controller, key: previewKey),
      ),
    );
  }

  /// Phones fill the screen (cover); tablets show the whole sensor frame
  /// (contain) so a 9:16 preview isn't blown up and cropped on a wide panel.
  BoxFit get _previewFit =>
      ResponsiveBreakpoints.isTabletScreen ? BoxFit.contain : BoxFit.cover;

  String _statusLabel(TimesheetFaceDetectionResult? result) {
    if (_verificationInFlight) {
      return 'Verifying liveness…';
    }
    // TASK 09: no immediate quality hints ("Move back", etc.) in best-frame
    // verify mode — delayed bottom hint only after ≥2 s.
    if (_bestFrameModeActive) {
      if (_livenessSnapshot.showSpoofWarning) {
        return _livenessSnapshot.statusMessage;
      }
      if (result == null) return 'Looking for faces';
      return 'Looking for faces';
    }
    if (_lowEndDeviceMode && result?.quality.canCapture == true) {
      return 'Low-end mode: tap capture to verify identity';
    }
    if (result == null) return 'Looking for faces';
    if (isGroup && result.faceCount > 1) {
      return '${result.faceCount} faces detected';
    }
    if (_livenessSnapshot.showSpoofWarning) {
      return _livenessSnapshot.statusMessage;
    }
    return result.quality.message;
  }

  void _onRetrySpoof() {
    _awsLivenessLaunched = false;
    _livenessRetryTimer?.cancel();
    unawaited(_clearBurstSamples());
    unawaited(_clearStreamSampleRing());
    _clearLiveOverlay();
    _livenessGate.retryAfterSpoof();
    _livenessGate.setStatusMessage('Retrying in 1s…');
    _syncLivenessSnapshot();
    if (!mounted) return;
    setState(() {});
    _emitChrome();

    _livenessRetryTimer = Timer(AntispoofConfig.livenessRetryDelay, () {
      if (!mounted) return;
      _livenessGate.setStatusMessage('Center your face in the frame');
      _syncLivenessSnapshot();
      setState(() {});
      _emitChrome();
    });
  }

  Future<void> _launchAwsLiveness() async {
    if (!AntispoofConfig.useAwsFaceLiveness) return;
    if (_awsLivenessLaunched || !mounted) return;
    final phase = _livenessGate.snapshot.phase;
    if (phase != LivenessGatePhase.onDevicePassed &&
        phase != LivenessGatePhase.awsRequired) {
      return;
    }
    _awsLivenessLaunched = true;
    _livenessGate.markAwsRequired();

    final awsResult = await Navigator.of(context).push<TmAwsFaceLivenessResult>(
      MaterialPageRoute(
        builder: (_) => const TmAwsFaceLivenessScreen(),
      ),
    );

    if (!mounted) return;

    if (awsResult == null) {
      _awsLivenessLaunched = false;
      _livenessGate.resetSession();
      _syncLivenessSnapshot();
      setState(() {});
      _emitChrome();
      return;
    }

    _livenessGate.completeAwsLiveness(
      sessionId: awsResult.sessionId,
      confidence: awsResult.confidence,
      live: awsResult.live,
    );
    _syncLivenessSnapshot();
    setState(() {});
    _emitChrome();
  }

  Future<void> _resetCameraZoom(CameraController controller) async {
    try {
      if (!controller.value.isInitialized) return;
      final minZoom = await controller.getMinZoomLevel();
      final maxZoom = await controller.getMaxZoomLevel();
      if (minZoom <= 0 || maxZoom < minZoom) return;
      await controller.setZoomLevel(minZoom.clamp(minZoom, maxZoom));
    } catch (_) {
      // Zoom is best-effort on iOS multi-lens switches.
    }
  }

  /// Re-applies the minimum zoom a couple of times after the preview settles so
  /// a switched camera can't stay stuck on a leftover digital zoom.
  Future<void> _settleCameraZoom() async {
    for (final delay in const [
      Duration(milliseconds: 300),
      Duration(milliseconds: 700),
    ]) {
      await Future<void>.delayed(delay);
      final controller = _cameraController;
      if (!mounted || controller == null || !controller.value.isInitialized) {
        return;
      }
      await _resetCameraZoom(controller);
    }
  }

  Future<void> _switchCamera() async {
    if (_availableCameras.length < 2 ||
        _cameraInitInFlight ||
        _isCapturing ||
        _isInitializingCamera) {
      return;
    }
    final current = _camera;
    // Prefer a clean front ↔ back toggle. Round-robin across every physical
    // lens (wide/ultrawide/tele) left multi-camera phones on the same side
    // and felt like the flip "did nothing".
    final wantDirection = current?.lensDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    final nextCamera = _availableCameras.firstWhere(
      (c) => c.lensDirection == wantDirection,
      orElse: () {
        final currentIndex =
            current == null ? 0 : _availableCameras.indexOf(current);
        final nextIndex = (currentIndex + 1) % _availableCameras.length;
        return _availableCameras[nextIndex];
      },
    );
    if (nextCamera == current) return;
    // Task 6 — blank name immediately on flip (before teardown).
    _clearBadgeNow(reason: 'camera_switch');
    await _stopLiveDetection();
    final oldController = _cameraController;
    _awsLivenessLaunched = false;
    _livenessGate.resetSession();
    _syncLivenessSnapshot();
    _patchState(() {
      _cameraController = null;
      _camera = nextCamera;
      _faceResult = null;
    });
    await oldController?.dispose();
    if (!mounted) return;
    await _initializeCamera(cameraOverride: nextCamera);
  }

  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    final next = !_flashEnabled;
    try {
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _flashEnabled = next);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flash is not available on this camera')),
      );
    }
  }

  Rect? _largestFaceBox(List<Rect> boxes) {
    if (boxes.isEmpty) return null;
    Rect best = boxes.first;
    var area = best.width * best.height;
    for (var i = 1; i < boxes.length; i++) {
      final b = boxes[i];
      final a = b.width * b.height;
      if (a > area) {
        area = a;
        best = b;
      }
    }
    return best;
  }
}

class TimesheetCaptureStatusPill extends StatelessWidget {
  const TimesheetCaptureStatusPill({
    super.key,
    required this.label,
    required this.icon,
    this.dark = true,
  });

  final String label;
  final IconData icon;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fg =
        dark ? TimesheetModuleColors.surface : TimesheetModuleColors.primary;
    final bg = dark
        ? TimesheetModuleColors.surface.withValues(alpha: 0.12)
        : TimesheetModuleColors.primaryTint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TimesheetModuleTypography.caption().copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// TASK 09 — BioTime-style corner-bracket square + employee id (no name).
class BestFrameMarkerOverlayPainter extends CustomPainter {
  const BestFrameMarkerOverlayPainter({
    required this.imageSize,
    required this.faceBox,
    required this.fit,
    this.employeeId,
    this.neutralOnly = false,
    this.progressLabel,
    this.outOfTeam = false,
    this.mirrorX = false,
  });

  final Size imageSize;
  final Rect faceBox;
  final BoxFit fit;
  final int? employeeId;
  final bool neutralOnly;

  /// Walk-up collecting evidence, e.g. `1/3`.
  final String? progressLabel;

  /// Walk-up: project labor not in Your Team (amber, no id).
  final bool outOfTeam;

  /// Front camera preview is mirrored; ML Kit boxes are not.
  final bool mirrorX;

  @override
  void paint(Canvas canvas, Size size) {
    if (imageSize.width == 0 || imageSize.height == 0) return;
    final scaled = scaleFaceBoxToView(
      box: faceBox,
      viewSize: size,
      imageSize: imageSize,
      fit: fit,
      mirrorX: mirrorX,
    );
    final Color color;
    if (outOfTeam) {
      color = TmFaceMeshPainter.outOfTeam;
    } else if (neutralOnly) {
      color = TmFaceMeshPainter.neutral.withValues(alpha: 0.55);
    } else if (progressLabel != null) {
      color = Colors.white;
    } else {
      color = TmFaceMeshPainter.inTeam;
    }
    TmFaceMeshPainter.paintCornerBracketSquare(
      canvas: canvas,
      faceBox: scaled,
      color: color,
      strokeWidth: neutralOnly ? 1.5 : 3,
    );
    if (outOfTeam) {
      final square = TmFaceMeshPainter.expandedSquareForFace(scaled);
      final tp = TextPainter(
        text: TextSpan(
          text: 'Not in your team',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            backgroundColor: color.withValues(alpha: 0.85),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width * 0.7);
      tp.paint(
        canvas,
        Offset(
          (square.center.dx - tp.width / 2).clamp(4.0, size.width - tp.width - 4),
          (square.top - tp.height - 6).clamp(4.0, size.height - tp.height - 4),
        ),
      );
      return;
    }
    if (!neutralOnly && employeeId != null && employeeId! > 0) {
      final square = TmFaceMeshPainter.expandedSquareForFace(scaled);
      final label = progressLabel == null
          ? '$employeeId'
          : '$employeeId · $progressLabel';
      TmFaceMeshPainter.paintEmployeeIdPill(
        canvas: canvas,
        squareBox: square,
        employeeId: employeeId!,
        badgeColor: progressLabel != null
            ? const Color(0xFF546E7A)
            : TmFaceMeshPainter.inTeam,
        viewSize: size,
        labelOverride: label,
      );
    }
  }

  @override
  bool shouldRepaint(covariant BestFrameMarkerOverlayPainter oldDelegate) {
    return oldDelegate.imageSize != imageSize ||
        oldDelegate.faceBox != faceBox ||
        oldDelegate.employeeId != employeeId ||
        oldDelegate.neutralOnly != neutralOnly ||
        oldDelegate.progressLabel != progressLabel ||
        oldDelegate.outOfTeam != outOfTeam ||
        oldDelegate.fit != fit ||
        oldDelegate.mirrorX != mirrorX;
  }
}

class TimesheetFaceOverlayPainter extends CustomPainter {
  const TimesheetFaceOverlayPainter({
    required this.result,
    this.overlayHint,
    this.fit = BoxFit.cover,
    this.verifiedOnly = false,
  });

  final TimesheetFaceDetectionResult result;
  final TimesheetFaceOverlayHint? overlayHint;

  /// 1:1 verify mode: no marker on a face until the target is verified, so
  /// neutral ("Verifying…", "Select a labor") badges are not painted.
  final bool verifiedOnly;

  /// Must match the preview's [BoxFit] so badges land on the face.
  final BoxFit fit;

  @override
  void paint(Canvas canvas, Size size) {
    if (result.faceBoxes.isEmpty) return;

    final imageSize = result.imageSize;
    if (imageSize == null || imageSize.width == 0 || imageSize.height == 0) {
      return;
    }

    final hint = overlayHint;
    final kind = hint?.kind ?? TimesheetFaceFrameKind.quality;
    if (verifiedOnly && kind == TimesheetFaceFrameKind.quality) return;

    // Boxes come back in upright (rotated) image space while [imageSize] may
    // be the raw sensor frame — align orientation with the view, then map with
    // the same uniform cover transform the preview uses (BoxFit.cover), so the
    // badge stays on the face on tall phones and wide tablets alike.
    final frameColor = switch (kind) {
      TimesheetFaceFrameKind.inTeam => TmFaceMeshPainter.inTeam,
      TimesheetFaceFrameKind.outOfTeam => TmFaceMeshPainter.outOfTeam,
      TimesheetFaceFrameKind.duplicate => TmFaceMeshPainter.duplicate,
      TimesheetFaceFrameKind.quality => TmFaceMeshPainter.neutral,
    };

    final name = hint?.employeeName?.trim();
    final fileId = hint?.fileId?.trim();
    final showIdentity = name != null && name.isNotEmpty;
    if (!showIdentity) return;

    final primary = result.primaryFace;
    final primaryBox = primary?.boundingBox;
    final boxes = primaryBox != null ? <Rect>[primaryBox] : result.faceBoxes;

    for (var i = 0; i < boxes.length; i++) {
      final box = boxes[i];
      final scaled = scaleFaceBoxToView(
        box: box,
        viewSize: size,
        imageSize: imageSize,
        fit: fit,
      );
      if (i == 0) {
        TmFaceMeshPainter.paintNameBadge(
          canvas: canvas,
          faceBox: scaled,
          badgeColor: frameColor,
          name: name,
          fileId: fileId,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant TimesheetFaceOverlayPainter oldDelegate) {
    return oldDelegate.result != result ||
        oldDelegate.overlayHint != overlayHint ||
        oldDelegate.verifiedOnly != verifiedOnly;
  }
}
