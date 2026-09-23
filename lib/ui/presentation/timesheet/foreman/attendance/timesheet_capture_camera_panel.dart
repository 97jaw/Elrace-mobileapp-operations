import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/network/timesheet_functions_client.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/burst_verification_pipeline.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/antispoof_config.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/minifasnet_fusion_engine.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/timesheet_liveness_gate.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/timesheet_face_classification_snapshot.dart';
import 'package:el_race/core/site_management/face_recognition/face_recognition_config.dart';
import 'package:el_race/core/site_management/face_recognition/face_recognition_service.dart';
import 'package:el_race/core/timesheet/services/timesheet_roster_face_matcher.dart';
import 'package:el_race/core/timesheet/services/capture_queue_service.dart';
import 'package:el_race/core/timesheet/services/face_capture_service.dart';
import 'package:el_race/core/timesheet/services/geofence_service.dart';
import 'package:el_race/core/timesheet/services/tm_face_detection_speech_service.dart';
import 'package:el_race/core/timesheet/services/timesheet_capture_flow_service.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_route_args.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/face_recognition/tm_face_mesh_painter.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/face_recognition/tm_aws_face_liveness_screen.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Live chrome state for parent-built overlays (Add timesheet full screen).
class TimesheetCaptureChromeSnapshot {
  const TimesheetCaptureChromeSnapshot({
    required this.faceStatus,
    required this.geofenceLabel,
    required this.canCapture,
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
  });

  final String faceStatus;
  final String geofenceLabel;
  final bool canCapture;
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
    this.overlayHint,
    this.capturedEmployeeIds = const {},
    this.projectLaborEmployeeIds = const {},
    this.onDuplicateRecognized,
    this.onAlreadyAttended,
  });

  final TimesheetCaptureArgs capture;
  final bool showShutter;
  final bool fillHeight;
  final bool externalChrome;
  final bool autoCaptureEnabled;
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

class TimesheetCaptureCameraPanelState extends State<TimesheetCaptureCameraPanel> {
  static const double _minSupportedAndroidRamGb = 4.5;
  static const int _minSupportedAndroidCpuCores = 6;
  static const double _lowTierAndroidRamGb = 6.5;
  static const Duration _streamDetectInterval = Duration(milliseconds: 280);
  static const Duration _streamDetectIntervalFast = Duration(milliseconds: 180);
  static const Duration _previewMatchInterval = Duration(milliseconds: 550);
  static const Duration _previewMatchIntervalLocked = Duration(milliseconds: 900);
  static const Duration _autoCaptureHold = Duration(milliseconds: 420);
  static const Duration _autoCaptureHoldLocked = Duration(milliseconds: 220);
  static const Duration _previewSuppressAfterMiss = Duration(milliseconds: 900);
  static const Duration _shutterSettleDelay = Duration(milliseconds: 120);
  /// Clear badge if no qualifying embed for this long (Task 6).
  static const Duration _badgeStaleTimeout = Duration(milliseconds: 400);

  final TimesheetFaceCaptureService _faceService = TimesheetFaceCaptureService();
  final TimesheetCaptureQueueService _queueService =
      TimesheetCaptureQueueService();
  final TimesheetCaptureFlowService _flowService = TimesheetCaptureFlowService();
  final TimesheetGeofenceService _geofenceService =
      const TimesheetGeofenceService();
  final TimesheetRosterFaceMatcher _rosterMatcher =
      TimesheetRosterFaceMatcher();
  final TimesheetLivenessGate _livenessGate = TimesheetLivenessGate();
  final BurstVerificationPipeline _burstPipeline = BurstVerificationPipeline();
  final TmFaceDetectionSpeechService _speech = TmFaceDetectionSpeechService();

  List<CameraDescription> _availableCameras = const [];
  CameraController? _cameraController;
  CameraDescription? _camera;
  TimesheetFaceDetectionResult? _faceResult;
  TimesheetGeofencePreview? _geofencePreview;
  Position? _position;
  bool _flashEnabled = false;
  bool _permissionsReady = false;
  bool _isCapturing = false;
  bool _isInitializingCamera = false;
  bool _isDetectingFrame = false;
  bool _isStreaming = false;
  bool _lowEndDeviceMode = false;
  bool _iosPollingDetection = false;
  bool _cameraInitInFlight = false;
  String? _cameraError;
  DateTime _lastFrameDetection = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _iosPollingTimer;
  Timer? _autoCaptureTimer;
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
  LivenessGateSnapshot _livenessSnapshot = const LivenessGateSnapshot(
    phase: LivenessGatePhase.idle,
    statusMessage: 'Center your face in the frame',
  );

  Duration get _detectInterval =>
      _consecutiveReadyFrames >= 2
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

  bool _isEmployeeAlreadyCaptured(int employeeId) =>
      widget.capturedEmployeeIds.contains(employeeId);

  bool _isOnProjectLaborList(int employeeId) =>
      widget.projectLaborEmployeeIds.contains(employeeId);

  bool get _shouldHoldDuplicateFrame =>
      _livePreviewBlockCapture ||
      (_livePreviewEmployeeId != null &&
          _isEmployeeAlreadyCaptured(_livePreviewEmployeeId!));

  bool get isGroup => widget.capture.mode == 'group';
  TimesheetFaceOverlayHint? get _effectiveOverlayHint =>
      widget.overlayHint ?? _liveOverlayHint;
  bool get _qualityReady => _faceResult?.quality.canCapture == true;

  bool get _livenessReady {
    if (_livenessGate.expireIfNeeded()) {
      _syncLivenessSnapshot();
      _clearLiveOverlay();
    }
    return _livenessGate.recognitionAllowed;
  }

  /// Quality gate only — PAD runs at capture (Task 5a), not on the live stream.
  bool get canCapture =>
      _qualityReady && !_isCapturing && !_verificationInFlight;

  void _syncLivenessSnapshot() {
    _livenessSnapshot = _livenessGate.snapshot;
  }

  void _emitChrome() {
    widget.onChromeChanged?.call(
      TimesheetCaptureChromeSnapshot(
        faceStatus: _statusLabel(_faceResult),
        geofenceLabel: _geofencePreview?.label ?? 'Waiting for GPS lock',
        canCapture: canCapture,
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
      ),
    );
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
  Future<bool> _runCaptureTimePadBurst() async {
    if (_livenessGate.recognitionAllowed) return true;

    var samples = _preShutterSamplesFromRing();
    if (samples.length < AntispoofConfig.burstFrameCount) {
      samples = List<BurstFrameSample>.from(_streamSampleRing);
    }
    if (samples.isEmpty) {
      debugPrint('FaceCapture: PAD blocked — no stream frames yet');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hold still a moment, then capture again'),
          ),
        );
      }
      return false;
    }

    _verificationInFlight = true;
    _livenessGate.markVerifying();
    _syncLivenessSnapshot();
    _emitChrome();
    try {
      // Ensure PAD interpreters are warm before first capture invoke.
      await MinifasnetFusionEngine.instance.ensureLoaded();
      final BurstVerificationResult verifyResult;
      if (samples.length >= AntispoofConfig.burstFrameCount) {
        verifyResult = await _burstPipeline.verify(samples).timeout(
          AntispoofConfig.maxVerificationBudget,
          onTimeout: () => const BurstVerificationResult(
            passed: false,
            message: 'Verification timed out — retry',
          ),
        );
      } else {
        // Short ring (just opened camera) — integrity path, still capture-only.
        verifyResult = await _burstPipeline
            .verifyIntegrity(
              samples,
              requireTemporal: samples.length >= 2,
            )
            .timeout(
              AntispoofConfig.maxVerificationBudget,
              onTimeout: () => const BurstVerificationResult(
                passed: false,
                message: 'Verification timed out — retry',
              ),
            );
      }
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

  Future<XFile?> _takePictureWithRetry() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return null;
    try {
      return await controller.takePicture();
    } on CameraException catch (error) {
      // Avoid re-initializing camera mid-session; it causes visible stalls.
      debugPrint('FaceCapture takePicture failed: $error');
      return null;
    }
  }

  Future<void> _clearStreamSampleRing() async {
    final stale = List<BurstFrameSample>.from(_streamSampleRing);
    _streamSampleRing.clear();
    for (final sample in stale) {
      await _safeDeleteSampleTemp(sample);
    }
  }

  void _pushStreamSample(BurstFrameSample sample) {
    if (_streamSampleRing.length >= 4) {
      final old = _streamSampleRing.removeAt(0);
      unawaited(_safeDeleteSampleTemp(old));
    }
    _streamSampleRing.add(sample);
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

  void _enterDuplicatePreview(TimesheetOdooEmployee emp) {
    final alreadyShowing = _livePreviewBlockCapture &&
        _livePreviewEmployeeId == emp.employeeId;
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
    if (!alreadyShowing) {
      widget.onAlreadyAttended?.call(emp);
      unawaited(_speech.speakAlreadyAttended(employeeId: emp.employeeId));
    }
  }

  @override
  void didUpdateWidget(covariant TimesheetCaptureCameraPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.capturedEmployeeIds == widget.capturedEmployeeIds) return;
    final previewId = _livePreviewEmployeeId;
    if (previewId == null || !_isEmployeeAlreadyCaptured(previewId)) return;
    _autoCaptureTimer?.cancel();
    _previewDebounceTimer?.cancel();
    _faceReadySince = null;
    if (!mounted) return;
    setState(() {
      _livePreviewBlockCapture = true;
      _livePreviewAllowAutoCapture = false;
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
        _shouldHoldDuplicateFrame ||
        _isCapturing ||
        _verificationInFlight ||
        widget.faceRecognition?.isReady != true) {
      return;
    }
    if (_livePreviewAllowAutoCapture && _livePreviewEmployeeId != null) {
      return;
    }
    final now = DateTime.now();
    if (now.difference(_lastPreviewMatchAt) < _previewMatchCooldown) {
      return;
    }
    if (!result.quality.canCapture || result.faceBoxes.isEmpty) return;

    _previewMatchInFlight = true;
    try {
      final rgb = decodedRgb ?? _faceService.decodeCameraImage(image);
      if (rgb == null) return;
      await _applyLivePreviewMatchFromImage(result, rgb);
    } catch (e) {
      debugPrint('Timesheet stream embedding preview failed: $e');
    } finally {
      _previewMatchInFlight = false;
      _lastPreviewMatchAt = DateTime.now();
    }
  }

  Future<void> _applyLivePreviewMatchFromImage(
    TimesheetFaceDetectionResult result,
    img.Image source, {
    bool captureImmediately = false,
  }) async {
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

    if (match == null ||
        match.best == null ||
        !match.passesDisplayThreshold) {
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
        _livePreviewBlockCapture = false;
        _livePreviewAllowAutoCapture = false;
      });
      return;
    }

    // Duplicate hint only — PAD runs at capture (Task 5a), not here.
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
    unawaited(_speech.speakEmployeeDetected(emp.name, employeeId: emp.employeeId));
    if (!mayAutoCapture) {
      debugPrint(
        'FaceCapture: badge only score=${score.toStringAsFixed(3)} '
        '(need >= ${FaceRecognitionMatch.pilotAutoCaptureMinScore} to auto-capture)',
      );
      return;
    }
    if (captureImmediately) {
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

    if (match == null ||
        match.best == null ||
        !match.passesDisplayThreshold) {
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
        _livePreviewBlockCapture = false;
        _livePreviewAllowAutoCapture = false;
      });
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
    unawaited(_speech.speakEmployeeDetected(emp.name, employeeId: emp.employeeId));
    if (!mayAutoCapture) return;
    if (captureImmediately) {
      unawaited(_capture());
    } else {
      _scheduleAutoCapture();
    }
  }

  void _scheduleAutoCapture() {
    _autoCaptureTimer?.cancel();
    if (!widget.autoCaptureEnabled ||
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

  void _armAutoCaptureCooldown([Duration duration = const Duration(seconds: 2)]) {
    _autoCaptureCooldownUntil = DateTime.now().add(duration);
    _faceReadySince = null;
    _autoCaptureTimer?.cancel();
  }

  Future<void> capturePhoto() => _capture();

  Future<void> switchCameraExternal() => _switchCamera();

  Future<void> toggleFlashExternal() => _toggleFlash();

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
    // Defer TFLite anti-spoof load until after first frame so opening the
    // camera isn't paired with a cold "Initialized TensorFlow Lite runtime"
    // on the same tick as preview start / camera flip.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(MinifasnetFusionEngine.instance.ensureLoaded());
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
  }

  @override
  void dispose() {
    _iosPollingTimer?.cancel();
    _autoCaptureTimer?.cancel();
    _previewDebounceTimer?.cancel();
    _livenessRetryTimer?.cancel();
    unawaited(_clearStreamSampleRing());
    unawaited(_stopLiveDetection());
    unawaited(_speech.dispose());
    _cameraController?.dispose();
    _faceService.dispose();
    super.dispose();
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
          if (faceResult != null)
            CustomPaint(
              painter: TimesheetFaceOverlayPainter(
                result: faceResult,
                overlayHint: _effectiveOverlayHint,
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
                  onPressed: (!_permissionsReady || _isCapturing || !canCapture)
                      ? null
                      : _capture,
                  backgroundColor: TimesheetModuleColors.primary,
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
              child: TimesheetCaptureStatusPill(
                label: 'Camera and location permission required',
                icon: PhosphorIcons.lockKey(),
                dark: false,
              ),
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
          TimesheetCaptureStatusPill(
            label: 'Camera and location permission required',
            icon: PhosphorIcons.lockKey(),
            dark: false,
          ),
        ],
      ],
    );
  }

  Future<void> _prepareCapture() async {
    final permissions = await _faceService.requestCameraPermissions();
    if (!mounted) return;
    _patchState(() => _permissionsReady = permissions.canOpenCamera);
    if (!permissions.canOpenCamera) return;
    final supported = await _checkAndroidDeviceSupport();
    if (!supported) return;
    await Future.wait([_initializeCamera(), _updateCurrentLocation()]);
  }

  Future<bool> _checkAndroidDeviceSupport() async {
    if (!Platform.isAndroid) return true;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final ramGb = info.physicalRamSize > 0 ? info.physicalRamSize / 1024.0 : 0;
      final cores = Platform.numberOfProcessors;
      final unsupported = (ramGb > 0 && ramGb < _minSupportedAndroidRamGb) ||
          cores < _minSupportedAndroidCpuCores;
      final lowTier = !unsupported &&
          ((ramGb > 0 && ramGb <= _lowTierAndroidRamGb) || cores <= 8);
      if (unsupported) {
        if (!mounted) return false;
        final ramLabel = ramGb > 0 ? ramGb.toStringAsFixed(1) : 'unknown';
        _patchState(() {
          _cameraError =
              'This device is not supported for reliable face attendance.\n'
              'Device: ${info.brand} ${info.model}\n'
              'RAM: ${ramLabel}GB, CPU cores: $cores\n'
              'Minimum required: ${_minSupportedAndroidRamGb.toStringAsFixed(1)}GB RAM and $_minSupportedAndroidCpuCores CPU cores.\n'
              'Please use a newer device.';
        });
        return false;
      }
      if (lowTier && mounted) {
        _patchState(() => _lowEndDeviceMode = true);
      }
    } catch (e) {
      debugPrint('Timesheet device capability check failed: $e');
    }
    return true;
  }

  Future<void> _capture() async {
    if (_shouldHoldDuplicateFrame) {
      debugPrint('FaceCapture: shutter blocked — duplicate');
      return;
    }
    final previewId = _livePreviewEmployeeId;
    if (previewId != null && _isEmployeeAlreadyCaptured(previewId)) {
      debugPrint('FaceCapture: shutter blocked — emp $previewId captured');
      return;
    }
    if (!_qualityReady) {
      debugPrint('FaceCapture: shutter blocked — quality not ready');
      return;
    }
    if (_verificationInFlight) {
      debugPrint('FaceCapture: shutter blocked — PAD in flight');
      return;
    }
    _patchState(() => _isCapturing = true);
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      _patchState(() => _isCapturing = false);
      return;
    }

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
    if (photo == null) {
      _patchState(() => _isCapturing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera busy — hold still and try again'),
          ),
        );
      }
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
    final draftId = 'capture_${capturedAt.millisecondsSinceEpoch}';
    final livenessLog = _livenessGate.snapshot.lastLog;
    final draft = AttendanceCaptureDraft(
      id: draftId,
      projectId: capture.projectId,
      taskId: capture.taskId,
      event: capture.event,
      createdAt: capturedAt,
      cropLocalPath: photo.path,
      lat: position?.latitude,
      lon: position?.longitude,
      workerId: capture.targetWorkerId,
      syncState: AttendanceCaptureSyncState.pending,
      livenessFlagged: false,
      livenessLogJson: livenessLog?.toJson(),
      awsLivenessSessionId: livenessLog?.awsSessionId,
      awsLivenessConfidence: livenessLog?.awsConfidence,
    );

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
      final matchImagePath =
          captureResult.analyzedImagePath ?? photo.path;
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
              _blockReplayAttempt('Presentation attack detected — use live face');
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

  Future<void> _initializeCamera({CameraDescription? cameraOverride}) async {
    if (_cameraInitInFlight) return;
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
      // Android: high (≈720p) — medium hurt still-match scores (0.20–0.27).
      // Stream cost is controlled by Task 5a (no PAD) + throttle, not preset alone.
      final preset = ResolutionPreset.high;
      final controller = CameraController(
        selected,
        preset,
        enableAudio: false,
        imageFormatGroup:
            Platform.isAndroid ? ImageFormatGroup.yuv420 : null,
      );
      await controller.initialize();
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
    _awsLivenessLaunched = false;
    _livenessRetryTimer?.cancel();
    _clearLiveOverlay();
    await _clearBurstSamples();
    await _clearStreamSampleRing();
    _livenessGate.resetSession();
    _syncLivenessSnapshot();
    if (Platform.isIOS) {
      try {
        await _startImageStream();
        return;
      } catch (error) {
        debugPrint('Timesheet iOS image stream unavailable, using polling: $error');
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
    if (!_iosPollingDetection ||
        controller == null ||
        !controller.value.isInitialized ||
        _isCapturing ||
        _isDetectingFrame) {
      return;
    }
    _isDetectingFrame = true;
    try {
      final photo = await controller.takePicture();
      var result = await _faceService.analyzeImageFile(
        photo.path,
        includeCrop: false,
        trustLiveGate: true,
      );
      final matchPath = result.analyzedImagePath ?? photo.path;
      // Task 5a — no stream PAD on iOS polling either; badge embed only.
      if (result.faceBoxes.isEmpty) {
        _clearBadgeNow(reason: 'no_face');
      } else if (result.quality.canCapture &&
          widget.faceRecognition?.isReady == true &&
          !_isCapturing &&
          !_shouldHoldDuplicateFrame) {
        await _applyLivePreviewMatch(result, matchPath);
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
    final now = DateTime.now();
    if (_isDetectingFrame ||
        now.difference(_lastFrameDetection) < _detectInterval) {
      return;
    }
    _isDetectingFrame = true;
    _lastFrameDetection = now;
    try {
      final inputImage = TimesheetFaceCaptureService.inputImageFromCameraImage(
        image: image,
        camera: camera,
      );
      if (inputImage == null) return;
      final result = await _faceService.analyzeInputImage(
        inputImage,
        imageSize: Size(image.width.toDouble(), image.height.toDouble()),
        liveStream: true,
      );
      if (!mounted) return;
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
        if (lastQual != null &&
            now.difference(lastQual) > _badgeStaleTimeout &&
            _liveOverlayHint != null) {
          _clearBadgeNow(reason: 'stale');
        }
      }
      _patchState(() => _faceResult = result);

      // Keep a short in-memory ring for capture-time PAD only (Task 5a).
      // Do NOT run MiniFASNet on the stream.
      final ringMinInterval = _lowEndDeviceMode
          ? const Duration(milliseconds: 900)
          : const Duration(milliseconds: 350);
      img.Image? decodedRgb;
      img.Image? ensureDecoded() =>
          decodedRgb ??= _faceService.decodeCameraImage(image);

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
          );
        }
      }

      // Badge embed only (no PAD on stream).
      if (result.quality.canCapture &&
          _isStreaming &&
          !_shouldHoldDuplicateFrame &&
          !_isCapturing &&
          !_verificationInFlight) {
        unawaited(
          _runStreamEmbeddingPreview(
            image,
            result,
            decodedRgb: ensureDecoded(),
          ),
        );
      }
    } catch (error) {
      debugPrint('Timesheet live face detection failed: $error');
    } finally {
      _isDetectingFrame = false;
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
      return CameraPreview(controller, key: previewKey);
    }
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: previewSize.height,
        height: previewSize.width,
        child: CameraPreview(controller, key: previewKey),
      ),
    );
  }

  String _statusLabel(TimesheetFaceDetectionResult? result) {
    if (_verificationInFlight) {
      return 'Verifying liveness…';
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

class TimesheetFaceOverlayPainter extends CustomPainter {
  const TimesheetFaceOverlayPainter({
    required this.result,
    this.overlayHint,
  });

  final TimesheetFaceDetectionResult result;
  final TimesheetFaceOverlayHint? overlayHint;

  @override
  void paint(Canvas canvas, Size size) {
    if (result.faceBoxes.isEmpty) return;

    final imageSize = result.imageSize;
    if (imageSize == null || imageSize.width == 0 || imageSize.height == 0) {
      return;
    }

    final hint = overlayHint;
    final kind = hint?.kind ?? TimesheetFaceFrameKind.quality;

    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;
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
      final scaled = Rect.fromLTRB(
        box.left * scaleX,
        box.top * scaleY,
        box.right * scaleX,
        box.bottom * scaleY,
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
        oldDelegate.overlayHint != overlayHint;
  }
}
