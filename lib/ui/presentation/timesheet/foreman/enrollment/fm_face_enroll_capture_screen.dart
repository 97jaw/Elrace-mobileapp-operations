import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:el_race/core/site_management/face_recognition/data/models/face_enrollment_pose.dart';
import 'package:el_race/core/site_management/face_recognition/face_recognition_config.dart';
import 'package:el_race/core/site_management/face_recognition/face_recognition_provider.dart';
import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';
import 'package:el_race/core/timesheet/providers/timesheet_enrollment_status_provider.dart';
import 'package:el_race/core/timesheet/providers/timesheet_hr_scope_provider.dart';
import 'package:el_race/core/timesheet/services/face_capture_service.dart';
import 'package:el_race/core/timesheet/services/timesheet_acting_guard.dart';
import 'package:el_race/core/timesheet/services/timesheet_project_access_service.dart';
import 'package:el_race/core/utils/app_orientations.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/foreman/enrollment/widgets/fm_face_enroll_oval_overlay.dart';
import 'package:el_race/ui/presentation/timesheet/foreman/enrollment/widgets/fm_face_enroll_processing_sheet.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_route_args.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Success/ready highlight for enrollment guides, mask, pose dots and the
/// completion state — green so it reads as "good", not an error red.
const Color _kEnrollReadyGreen = Color(0xFF3DDC84);

/// Guided multi-pose enrollment — auto-capture when pose + quality pass.
class FmFaceEnrollCaptureScreen extends ConsumerStatefulWidget {
  const FmFaceEnrollCaptureScreen({
    super.key,
    required this.args,
  });

  final TimesheetFaceEnrollCaptureArgs args;

  @override
  ConsumerState<FmFaceEnrollCaptureScreen> createState() =>
      _FmFaceEnrollCaptureScreenState();
}

class _FmFaceEnrollCaptureScreenState
    extends ConsumerState<FmFaceEnrollCaptureScreen>
    with CapturePortraitLock<FmFaceEnrollCaptureScreen> {
  final _captureService = TimesheetFaceCaptureService();
  CameraController? _controller;
  Future<XFile>? _pictureInFlight;
  AppLifecycleListener? _lifecycleListener;
  bool _permissionDenied = false;
  CameraDescription? _camera;
  List<CameraDescription> _cameras = const [];
  bool _cameraSwitching = false;
  bool _initializing = true;
  String? _initError;
  bool _capturing = false;
  bool _isStreaming = false;
  bool _isAnalyzingFrame = false;
  String? _hint;
  bool _previewReady = false;
  TimesheetFaceQualityStatus? _qualityStatus;
  int _poseIndex = 0;
  final Map<FaceEnrollmentPose, String> _paths = {};
  FmFaceEnrollProcessStep? _processStep;
  String? _processError;
  DateTime _lastFrameAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _readySince;
  DateTime _suppressAutoUntil = DateTime.fromMillisecondsSinceEpoch(0);
  bool _autoCaptureInFlight = false;
  int _consecutiveReadyFrames = 0;

  /// Best verified frame so far for the current turned pose.
  FaceEnrollmentPose? _turnedCandidatePose;
  String? _turnedCandidatePath;
  double _turnedCandidateSharpness = -1;
  int _turnedVerifiedFrames = 0;

  /// Bumped on every open/switch so in-flight frame analysis and iOS pollers
  /// drop results from a disposed or replaced camera session.
  int _cameraSessionId = 0;
  int _iosPollerGeneration = 0;

  bool get _isFrontCamera =>
      _camera?.lensDirection == CameraLensDirection.front;

  static const _streamInterval = Duration(milliseconds: 250);
  static const _holdReadyDuration = Duration(milliseconds: 300);
  static const _requiredReadyFrames = 2;

  /// Turned poses sample faster; `_isAnalyzingFrame` still drops overlap.
  static const _turnedPoseStreamInterval = Duration(milliseconds: 120);

  /// Verified turned frames compared before keeping the sharpest; fewer are
  /// used when the head leaves the pose first.
  static const _turnedFramesToCompare = 2;

  /// Short backoff only after a rejected still — never between good poses.
  static const _failureBackoff = Duration(milliseconds: 400);

  TimesheetOdooEmployee get _employee => widget.args.employee;

  FaceEnrollmentPose get _currentPose =>
      FaceEnrollmentPose.captureOrder[_poseIndex];

  bool get _processing => _processStep != null;

  Color get _frameColor {
    if (_paths.containsKey(_currentPose) && _capturing) {
      return _kEnrollReadyGreen;
    }
    if (_previewReady) return _kEnrollReadyGreen;
    if (_qualityStatus == TimesheetFaceQualityStatus.poseOutOfRange) {
      return const Color(0xFFFFB74D);
    }
    return Colors.white;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_initCamera());
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        if (!mounted || !_permissionDenied) return;
        setState(() {
          _initializing = true;
          _initError = null;
        });
        unawaited(_initCamera());
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    _clearTurnedCandidate();
    _cameraSessionId++;
    _iosPollerGeneration++;
    unawaited(_stopStream());
    final controller = _controller;
    _controller = null;
    unawaited(controller?.dispose());
    unawaited(_captureService.dispose());
    super.dispose();
  }

  Future<void> _initCamera() async {
    final granted = await _captureService.requestCameraOnlyPermission();
    if (!granted) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _permissionDenied = true;
        _initError = 'Camera permission is required for enrollment.';
      });
      return;
    }
    _permissionDenied = false;
    try {
      final cameras = await _captureService.availableCameraDescriptions();
      if (cameras.isEmpty) {
        throw StateError('No camera found on this device');
      }
      final preferred = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _cameras = cameras;
      await _openCamera(preferred);
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _hint = _currentPose.instruction;
      });
      await _startStream();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _initError = 'Could not open camera: $e';
      });
    }
  }

  Future<void> _resetCameraZoom(CameraController controller) async {
    try {
      if (!controller.value.isInitialized) return;
      // Some iOS lenses return null from the platform channel for zoom APIs
      // right after switch/init — treat as unsupported and skip quietly.
      final minZoom = await controller.getMinZoomLevel();
      final maxZoom = await controller.getMaxZoomLevel();
      if (minZoom <= 0 || maxZoom < minZoom) return;
      final target = minZoom.clamp(minZoom, maxZoom);
      await controller.setZoomLevel(target);
    } catch (_) {
      // Zoom is best-effort; never block enroll / flip on platform nulls.
    }
  }

  /// Re-apply min zoom after preview warm-up so a flipped camera doesn't keep
  /// a stuck digital zoom from the previous session.
  Future<void> _settleCameraZoom(int sessionId) async {
    for (final delay in const [
      Duration(milliseconds: 450),
      Duration(milliseconds: 900),
    ]) {
      await Future<void>.delayed(delay);
      if (!mounted || sessionId != _cameraSessionId) return;
      final controller = _controller;
      if (controller == null || !controller.value.isInitialized) return;
      await _resetCameraZoom(controller);
    }
  }

  /// One `takePicture` at a time: the iOS poller and the manual/auto shutter
  /// otherwise race into "Previous capture has not returned yet".
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

  Future<void> _waitForInFlightAnalysis({
    Duration timeout = const Duration(milliseconds: 1200),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while ((_isAnalyzingFrame || _autoCaptureInFlight) &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
  }

  Future<void> _openCamera(CameraDescription camera) async {
    _cameraSessionId++;
    _iosPollerGeneration++;
    final sessionId = _cameraSessionId;
    final controller = CameraController(
      camera,
      Platform.isIOS ? ResolutionPreset.high : ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : null,
    );
    await controller.initialize();
    if (!mounted || sessionId != _cameraSessionId) {
      await controller.dispose();
      return;
    }
    // Pose rules read yaw/pitch; a rotated frame on a landscape-native tablet
    // swaps them, so keep capture geometry portrait like attendance.
    try {
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
    } catch (e) {
      debugPrint('FmFaceEnroll: lockCaptureOrientation failed: $e');
    }
    await controller.setFlashMode(FlashMode.off);
    await controller.setFocusMode(FocusMode.auto);
    await _resetCameraZoom(controller);
    if (!mounted || sessionId != _cameraSessionId) {
      await controller.dispose();
      return;
    }
    final old = _controller;
    setState(() {
      _controller = controller;
      _camera = camera;
    });
    await old?.dispose();
    unawaited(_settleCameraZoom(sessionId));
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 ||
        _cameraSwitching ||
        _capturing ||
        _processing ||
        _autoCaptureInFlight) {
      return;
    }
    _cameraSwitching = true;
    if (mounted) setState(() {});
    try {
      // Invalidate any in-flight frame callbacks before tearing down.
      _cameraSessionId++;
      _iosPollerGeneration++;
      await _stopStream();
      await _waitForInFlightAnalysis();
      if (!mounted) return;
      // Toggle strictly between front and back so devices with several back
      // lenses (wide/ultrawide/tele) don't get stuck on a same-side lens.
      final wantDirection =
          _isFrontCamera ? CameraLensDirection.back : CameraLensDirection.front;
      final next = _cameras.firstWhere(
        (c) => c.lensDirection == wantDirection,
        orElse: () => _cameras.firstWhere(
          (c) => c != _camera,
          orElse: () => _cameras.first,
        ),
      );
      await _openCamera(next);
      if (!mounted) return;
      _clearTurnedCandidate();
      setState(() {
        _previewReady = false;
        _qualityStatus = null;
        _consecutiveReadyFrames = 0;
        _readySince = null;
        _suppressAutoUntil =
            DateTime.now().add(const Duration(milliseconds: 900));
        _hint = _currentPose.instruction;
      });
      // Clear BEFORE restarting the stream — `_startStream` / frame analysis
      // both no-op while `_cameraSwitching` is true, which left enroll stuck
      // on a frozen preview after every flip.
      _cameraSwitching = false;
      await _startStream();
    } finally {
      _cameraSwitching = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _startStream() async {
    final controller = _controller;
    final camera = _camera;
    final sessionId = _cameraSessionId;
    if (controller == null ||
        camera == null ||
        !controller.value.isInitialized ||
        _isStreaming ||
        _processing) {
      return;
    }
    try {
      // Snapshot [camera] so ML Kit orientation stays correct if the user
      // flips while a frame is still queued from the previous lens.
      await controller.startImageStream((image) {
        unawaited(_onCameraFrame(image, camera, sessionId));
      });
      if (sessionId != _cameraSessionId) {
        try {
          await controller.stopImageStream();
        } catch (_) {}
        return;
      }
      _isStreaming = true;
    } catch (e) {
      debugPrint('FmFaceEnroll: stream start failed: $e');
      if (Platform.isIOS && mounted && sessionId == _cameraSessionId) {
        unawaited(_iosPreviewPolling(sessionId));
      }
    }
  }

  Future<void> _iosPreviewPolling(int sessionId) async {
    final pollerGen = ++_iosPollerGeneration;
    while (mounted &&
        !_processing &&
        pollerGen == _iosPollerGeneration &&
        sessionId == _cameraSessionId &&
        _poseIndex < FaceEnrollmentPose.captureOrder.length) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted ||
          pollerGen != _iosPollerGeneration ||
          sessionId != _cameraSessionId ||
          _capturing ||
          _processing ||
          _isStreaming ||
          _cameraSwitching) {
        continue;
      }
      final controller = _controller;
      final camera = _camera;
      if (controller == null ||
          camera == null ||
          !controller.value.isInitialized) {
        continue;
      }
      if (DateTime.now().isBefore(_suppressAutoUntil)) continue;
      try {
        final photo = await _takePictureExclusive(controller);
        if (sessionId != _cameraSessionId || !mounted) {
          try {
            await File(photo.path).delete();
          } catch (_) {}
          return;
        }
        final preview = await _captureService.validateEnrollmentFrame(
          photo.path,
          _currentPose,
          frontCamera: camera.lensDirection == CameraLensDirection.front,
          requireSharpness: false,
        );
        try {
          await File(photo.path).delete();
        } catch (_) {}
        if (!mounted || sessionId != _cameraSessionId) return;
        setState(() {
          _previewReady = preview.ok;
          _hint = preview.message;
        });
        if (preview.ok) {
          _consecutiveReadyFrames += 1;
          _readySince ??= DateTime.now();
          final heldLongEnough =
              DateTime.now().difference(_readySince!) >= _holdReadyDuration;
          final stableEnough = _consecutiveReadyFrames >= _requiredReadyFrames;
          if (heldLongEnough && stableEnough) {
            await _autoCapturePose();
          }
        } else {
          _consecutiveReadyFrames = 0;
          _readySince = null;
        }
      } catch (_) {}
    }
  }

  Future<void> _stopStream() async {
    final controller = _controller;
    if (controller == null || !_isStreaming) {
      _isStreaming = false;
      return;
    }
    try {
      await controller.stopImageStream();
    } catch (_) {}
    _isStreaming = false;
  }

  Future<void> _onCameraFrame(
    CameraImage image,
    CameraDescription camera,
    int sessionId,
  ) async {
    if (sessionId != _cameraSessionId ||
        _processing ||
        _capturing ||
        _cameraSwitching ||
        _isAnalyzingFrame ||
        !_isStreaming) {
      return;
    }
    final now = DateTime.now();
    if (now.isBefore(_suppressAutoUntil)) return;
    final interval = _currentPose == FaceEnrollmentPose.front
        ? _streamInterval
        : _turnedPoseStreamInterval;
    if (now.difference(_lastFrameAt) < interval) return;

    _isAnalyzingFrame = true;
    _lastFrameAt = now;
    final isFront = camera.lensDirection == CameraLensDirection.front;
    try {
      final inputImage = TimesheetFaceCaptureService.inputImageFromCameraImage(
        image: image,
        camera: camera,
      );
      if (inputImage == null) return;
      if (sessionId != _cameraSessionId) return;

      final preview = await _captureService.previewEnrollmentPose(
        inputImage,
        _currentPose,
        frontCamera: isFront,
      );
      if (!mounted || sessionId != _cameraSessionId) return;

      setState(() {
        _previewReady = preview.readyToCapture;
        _hint = preview.message;
        _qualityStatus = preview.qualityStatus;
      });

      if (preview.readyToCapture &&
          _currentPose != FaceEnrollmentPose.front &&
          sessionId == _cameraSessionId &&
          !_cameraSwitching) {
        await _captureTurnedPoseFromFrame(image, camera, sessionId);
      } else if (preview.readyToCapture) {
        _consecutiveReadyFrames += 1;
        _readySince ??= now;
        final heldLongEnough =
            now.difference(_readySince!) >= _holdReadyDuration;
        final stableEnough = _consecutiveReadyFrames >= _requiredReadyFrames;
        if (heldLongEnough &&
            stableEnough &&
            sessionId == _cameraSessionId &&
            !_cameraSwitching) {
          await _autoCapturePose();
        }
      } else {
        _consecutiveReadyFrames = 0;
        _readySince = null;
        if (_turnedCandidatePose == _currentPose &&
            sessionId == _cameraSessionId &&
            !_cameraSwitching) {
          await _acceptTurnedCandidate();
        }
      }
    } catch (e) {
      debugPrint('FmFaceEnroll: frame analysis failed: $e');
    } finally {
      _isAnalyzingFrame = false;
    }
  }

  /// Left / right / up: the head only passes through the angle briefly, so
  /// keep frames that passed instead of stopping the stream for a still.
  /// Live detection is helped by face tracking across frames; the final
  /// enrollment check is not, so each frame is re-checked as a still before
  /// it counts, and the sharpest of [_turnedFramesToCompare] is kept.
  /// Falls back to the still path if the frame can't be encoded.
  Future<void> _captureTurnedPoseFromFrame(
    CameraImage image,
    CameraDescription camera,
    int sessionId,
  ) async {
    if (_capturing || _processing || _autoCaptureInFlight) return;
    final pose = _currentPose;
    _capturing = true;
    var accept = false;
    try {
      final path = await _captureService.saveEnrollmentStreamFrame(
        image,
        camera,
      );
      if (!mounted || sessionId != _cameraSessionId) return;
      if (path == null) {
        _capturing = false;
        await _autoCapturePose();
        return;
      }
      final sharpness =
          await _captureService.verifiedEnrollmentFrameSharpness(path);
      if (!mounted || sessionId != _cameraSessionId || pose != _currentPose) {
        _deleteQuietly(path);
        return;
      }
      if (sharpness == null) {
        _deleteQuietly(path);
        return;
      }
      if (_turnedCandidatePose != pose) _clearTurnedCandidate();
      if (sharpness > _turnedCandidateSharpness) {
        final previous = _turnedCandidatePath;
        if (previous != null) _deleteQuietly(previous);
        _turnedCandidatePose = pose;
        _turnedCandidatePath = path;
        _turnedCandidateSharpness = sharpness;
      } else {
        _deleteQuietly(path);
      }
      _turnedVerifiedFrames += 1;
      accept = _turnedVerifiedFrames >= _turnedFramesToCompare;
    } finally {
      _capturing = false;
    }
    if (accept) await _acceptTurnedCandidate();
  }

  Future<void> _acceptTurnedCandidate() async {
    final pose = _turnedCandidatePose;
    final path = _turnedCandidatePath;
    _turnedCandidatePose = null;
    _turnedCandidatePath = null;
    _turnedCandidateSharpness = -1;
    _turnedVerifiedFrames = 0;
    if (pose == null || path == null || pose != _currentPose || !mounted) {
      return;
    }
    _paths[pose] = path;
    final nextIndex = _nextMissingPoseIndex();
    if (nextIndex == null) {
      await _submitEnrollment();
      return;
    }
    setState(() {
      _poseIndex = nextIndex;
      _hint = _currentPose.instruction;
      _qualityStatus = null;
      _previewReady = false;
      _consecutiveReadyFrames = 0;
      _readySince = null;
    });
  }

  void _clearTurnedCandidate() {
    final path = _turnedCandidatePath;
    if (path != null) _deleteQuietly(path);
    _turnedCandidatePose = null;
    _turnedCandidatePath = null;
    _turnedCandidateSharpness = -1;
    _turnedVerifiedFrames = 0;
  }

  void _deleteQuietly(String path) {
    unawaited(File(path).delete().then((_) {}, onError: (_) {}));
  }

  Future<void> _autoCapturePose() async {
    if (_capturing || _processing || _autoCaptureInFlight) return;
    _autoCaptureInFlight = true;
    _readySince = null;
    _consecutiveReadyFrames = 0;
    try {
      await _capturePose(auto: true);
    } finally {
      _autoCaptureInFlight = false;
    }
  }

  Future<void> _capturePose({bool auto = false}) async {
    final controller = _controller;
    final camera = _camera;
    final sessionId = _cameraSessionId;
    if (controller == null ||
        camera == null ||
        !controller.value.isInitialized ||
        _capturing ||
        _cameraSwitching) {
      return;
    }
    final isFront = camera.lensDirection == CameraLensDirection.front;
    setState(() {
      _capturing = true;
      _hint = auto ? 'Capturing…' : 'Hold still…';
      _previewReady = false;
    });
    await _stopStream();

    try {
      final file = await _takePictureExclusive(controller);
      if (sessionId != _cameraSessionId || !mounted) {
        try {
          await File(file.path).delete();
        } catch (_) {}
        return;
      }
      final validation = await _captureService.validateEnrollmentFrame(
        file.path,
        _currentPose,
        frontCamera: isFront,
        requireSharpness: !auto,
        trustStreamPose: auto,
      );
      if (!validation.ok) {
        if (!mounted || sessionId != _cameraSessionId) return;
        setState(() {
          _capturing = false;
          _hint = validation.message;
          _consecutiveReadyFrames = 0;
          _suppressAutoUntil = DateTime.now().add(_failureBackoff);
        });
        await _startStream();
        return;
      }

      _paths[_currentPose] = validation.imagePath;
      if (!mounted || sessionId != _cameraSessionId) return;

      final nextIndex = _nextMissingPoseIndex();
      if (nextIndex != null) {
        setState(() {
          _poseIndex = nextIndex;
          _capturing = false;
          _hint = _currentPose.instruction;
          _qualityStatus = null;
          _previewReady = false;
          _consecutiveReadyFrames = 0;
          _readySince = null;
        });
        await _startStream();
        return;
      }

      setState(() => _capturing = false);
      await _submitEnrollment();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _hint = 'Capture failed. Adjust and try again.';
        _suppressAutoUntil = DateTime.now().add(_failureBackoff * 2);
      });
      await _startStream();
    }
  }

  Future<void> _submitEnrollment() async {
    // Camera opens while acting; only the final enroll upload is refused.
    if (mounted &&
        TimesheetActingGuard.blockWrite(
          context,
          ref,
          action: 'Submitting enrollment',
        )) {
      return;
    }
    await _stopStream();
    setState(() {
      _processStep = FmFaceEnrollProcessStep.validating;
      _processError = null;
    });
    if (!await _passesEnrollmentChecks()) return;
    if (!mounted) return;
    setState(() => _processStep = FmFaceEnrollProcessStep.uploading);

    final result = await ref
        .read(faceEnrollmentServiceProvider)
        .enrollOdooEmployee(
          employeeId: _employee.employeeId,
          foremanEmployeeId: TimesheetProjectAccessService.loginEmployeeId(),
          imagePathsByPose: Map<FaceEnrollmentPose, String>.from(_paths),
          refreshFaceDbAfterUpload: false,
          waitForTemplatesInFaceDb: false,
        );

    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _processStep = FmFaceEnrollProcessStep.uploading;
        _processError = result.message ?? 'Upload failed';
      });
      return;
    }

    setState(() => _processStep = FmFaceEnrollProcessStep.submitted);
    ref.invalidate(timesheetHrScopeProvider);
    ref.invalidate(timesheetForemanEnrollmentMapProvider);
    ref.invalidate(faceDbSyncProvider);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    setState(() => _processStep = FmFaceEnrollProcessStep.done);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    Navigator.of(context).pop(true);
  }

  int? _nextMissingPoseIndex() {
    const order = FaceEnrollmentPose.captureOrder;
    for (var i = 0; i < order.length; i++) {
      if (!_paths.containsKey(order[i])) return i;
    }
    return null;
  }

  /// Runs once after every pose is captured: all poses must be the same
  /// person, and the face must not already belong to another employee.
  /// Local engine failures fall through (the server still validates).
  Future<bool> _passesEnrollmentChecks() async {
    final photos = <({
      String key,
      String imagePath,
      Rect faceBox,
      TimesheetFaceLandmarkSnapshot? landmarks,
    })>[];
    for (final pose in FaceEnrollmentPose.captureOrder) {
      final path = _paths[pose];
      if (path == null) continue;
      try {
        final detection = await _captureService.analyzeImageFile(
          path,
          includeCrop: false,
          trustLiveGate: true,
        );
        final face = detection.primaryFace;
        if (face == null) {
          if (!mounted) return false;
          if (pose == FaceEnrollmentPose.front) {
            _restartEnrollment('Front photo unclear — look straight again');
          } else {
            _retakePose(pose, 'No face in that photo — retake');
          }
          return false;
        }
        photos.add((
          key: pose.name,
          imagePath: detection.analyzedImagePath ?? path,
          faceBox: face.boundingBox,
          landmarks: face,
        ));
      } catch (e) {
        debugPrint('FmFaceEnroll: check detect failed ${pose.name}: $e');
      }
    }
    final report =
        await ref.read(faceRecognitionServiceProvider).checkEnrollmentPhotos(
              employeeId: _employee.employeeId,
              photos: photos,
            );
    if (!mounted) return false;
    if (report == null) return true;

    final mismatched =
        report.keysBelow(FaceEnrollmentChecks.samePersonMinCosine);
    if (mismatched.length >= 2) {
      // Most poses disagree with the front photo — the front is the odd one.
      _restartEnrollment(
          'Different faces detected — start again with one person');
      return false;
    }
    if (mismatched.length == 1) {
      final pose = FaceEnrollmentPose.values.byName(mismatched.first);
      _retakePose(pose, 'That photo looks like a different person — retake');
      return false;
    }

    final dup = report.duplicateOf;
    if (dup != null) {
      final blocked =
          report.duplicateScore >= FaceEnrollmentChecks.duplicateBlockCosine;
      final warn =
          report.duplicateScore >= FaceEnrollmentChecks.duplicateWarnCosine;
      if (blocked || warn) {
        final proceed = await _confirmDuplicate(dup.name, blocked: blocked);
        if (!mounted) return false;
        if (!proceed) {
          _restartEnrollment(_employee.name.isEmpty
              ? 'Start again'
              : 'Start again with ${_employee.name}');
          return false;
        }
      }
    }
    return true;
  }

  void _retakePose(FaceEnrollmentPose pose, String hint) {
    _paths.remove(pose);
    _clearTurnedCandidate();
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(hint)));
    setState(() {
      _processStep = null;
      _processError = null;
      _poseIndex = FaceEnrollmentPose.captureOrder.indexOf(pose);
      _hint = hint;
      _previewReady = false;
      _qualityStatus = null;
      _consecutiveReadyFrames = 0;
      _readySince = null;
      _suppressAutoUntil = DateTime.now().add(_failureBackoff);
    });
    unawaited(_startStream());
  }

  void _restartEnrollment(String hint) {
    _paths.clear();
    _retakePose(FaceEnrollmentPose.captureOrder.first, hint);
  }

  Future<bool> _confirmDuplicate(String otherName,
      {required bool blocked}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(blocked ? 'Face already enrolled' : 'Possible duplicate'),
        content: Text(
          blocked
              ? 'This face is already enrolled as $otherName. '
                  'It cannot be enrolled for ${_employee.name}.'
              : 'This face looks similar to $otherName, who is already '
                  'enrolled. Make sure this is ${_employee.name}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Retake'),
          ),
          if (!blocked)
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Enroll anyway'),
            ),
        ],
      ),
    );
    return result ?? false;
  }

  void _dismissProcessError() {
    setState(() {
      _processStep = null;
      _processError = null;
      _hint = _currentPose.instruction;
    });
    unawaited(_startStream());
  }

  /// Sized to the sensor's portrait aspect and cover-cropped, so the preview
  /// never stretches when the screen ratio differs (tablets especially).
  Widget _buildCameraPreview(CameraController controller) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return Center(child: CameraPreview(controller));
    }
    final shortSide = previewSize.shortestSide;
    final longSide = previewSize.longestSide;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: shortSide,
          height: longSide,
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_initError != null) {
      return TmScaffold(
        appBar: AppBar(title: const Text('Face enrollment')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_initError!, textAlign: TextAlign.center),
                if (_permissionDenied) ...[
                  const SizedBox(height: 16),
                  const FilledButton(
                    onPressed: openAppSettings,
                    child: Text('Open Settings'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_controller != null)
            KeyedSubtree(
              key: ValueKey(
                'enroll-cam-${_camera?.name ?? 'none'}-'
                '${_camera?.lensDirection.name ?? 'unknown'}',
              ),
              child: _buildCameraPreview(_controller!),
            ),
          FmFaceEnrollOvalOverlay(
            frameColor: _frameColor,
            instruction: _hint ?? _currentPose.instruction,
          ),
          SafeArea(
            child: Column(
              children: [
                _EnrollHeader(employee: _employee),
                const Spacer(),
                _PoseProgress(
                  poses: FaceEnrollmentPose.captureOrder,
                  completed: _paths.keys.toSet(),
                  current: _currentPose,
                ),
                const SizedBox(height: 10),
                _QualityStatusRow(
                  ready: _previewReady,
                  capturing: _capturing,
                  qualityStatus: _qualityStatus,
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _processing
                            ? null
                            : () => Navigator.maybePop(context),
                        icon: Icon(PhosphorIcons.x(), color: Colors.white),
                      ),
                      Expanded(
                        child: Text(
                          _capturing
                              ? 'Saving pose…'
                              : 'Auto-capture when pose & quality pass',
                          textAlign: TextAlign.center,
                          style: TimesheetModuleTypography.caption().copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Capture manually',
                        onPressed: _processing || _capturing
                            ? null
                            : () => _capturePose(auto: false),
                        icon:
                            Icon(PhosphorIcons.camera(), color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_processing)
            FmFaceEnrollProcessingSheet(
              step: _processStep!,
              errorMessage: _processError,
            ),
          if (_processError != null)
            Positioned(
              left: 20,
              right: 20,
              bottom: 120,
              child: TmPrimaryButton(
                label: 'Try again',
                warm: true,
                onPressed: _dismissProcessError,
              ),
            ),
        ],
      ),
    );
  }
}

class _QualityStatusRow extends StatelessWidget {
  const _QualityStatusRow({
    required this.ready,
    required this.capturing,
    this.qualityStatus,
  });

  final bool ready;
  final bool capturing;
  final TimesheetFaceQualityStatus? qualityStatus;

  @override
  Widget build(BuildContext context) {
    final icon = capturing
        ? PhosphorIcons.circleNotch()
        : ready
            ? PhosphorIcons.checkCircle()
            : PhosphorIcons.scanSmiley();
    final label = capturing
        ? 'Processing frame…'
        : ready
            ? 'Quality OK — capturing soon'
            : _labelForStatus(qualityStatus);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: ready ? _kEnrollReadyGreen : Colors.white70,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _labelForStatus(TimesheetFaceQualityStatus? status) {
    return switch (status) {
      TimesheetFaceQualityStatus.noFace => 'Find your face in the oval',
      TimesheetFaceQualityStatus.tooSmall => 'Move closer',
      TimesheetFaceQualityStatus.poseOutOfRange => 'Adjust head pose',
      TimesheetFaceQualityStatus.eyesClosed => 'Open your eyes',
      TimesheetFaceQualityStatus.tooBlurry => 'Hold still',
      TimesheetFaceQualityStatus.pass => 'Checking quality…',
      null => 'Checking quality…',
    };
  }
}

class _EnrollHeader extends StatelessWidget {
  const _EnrollHeader({required this.employee});

  final TimesheetOdooEmployee employee;

  @override
  Widget build(BuildContext context) {
    final imageUrl = employee.faceMatchImageUrl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: TimesheetModuleColors.navy,
            backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
            child: imageUrl == null
                ? Text(
                    employee.name.isNotEmpty
                        ? employee.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
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
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'File ID: ${employee.displayFileId}',
                  style: TimesheetModuleTypography.caption().copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PoseProgress extends StatelessWidget {
  const _PoseProgress({
    required this.poses,
    required this.completed,
    required this.current,
  });

  final List<FaceEnrollmentPose> poses;
  final Set<FaceEnrollmentPose> completed;
  final FaceEnrollmentPose current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final pose in poses) ...[
          _PoseDot(
            label: pose.shortLabel,
            done: completed.contains(pose),
            active: pose == current,
          ),
          if (pose != poses.last) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _PoseDot extends StatelessWidget {
  const _PoseDot({
    required this.label,
    required this.done,
    required this.active,
  });

  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = done
        ? _kEnrollReadyGreen
        : active
            ? Colors.white
            : Colors.white38;
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? _kEnrollReadyGreen.withValues(alpha: 0.25)
                : Colors.black38,
            border: Border.all(color: color, width: 2),
          ),
          child: done ? Icon(Icons.check, color: color, size: 18) : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
