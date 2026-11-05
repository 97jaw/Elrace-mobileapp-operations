import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/antispoof_config.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/burst_verification_pipeline.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/hybrid_liveness_gate.dart';
import 'package:el_race/core/site_management/face_recognition/domain/face_verifier.dart';
import 'package:el_race/core/site_management/face_recognition/face_min_device_check.dart';
import 'package:el_race/core/site_management/face_recognition/face_recognition_service.dart';
import 'package:el_race/core/site_management/face_recognition/profile_photo_face_db.dart';
import 'package:el_race/core/timesheet/services/face_capture_service.dart';
import 'package:el_race/ui/presentation/attendance_checkin/face/self_face_template_service.dart';
import 'package:el_race/ui/presentation/attendance_checkin/face/self_face_verify_result.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// 1:1 self face verify for attendance check-in / check-out.
///
/// Reuses core MiniFASNet + MobileFaceNet. No timesheet panel / fm_* imports.
class SelfFaceVerifyScreen extends StatefulWidget {
  const SelfFaceVerifyScreen({
    super.key,
    required this.isCheckIn,
  });

  final bool isCheckIn;

  @override
  State<SelfFaceVerifyScreen> createState() => _SelfFaceVerifyScreenState();
}

class _SelfFaceVerifyScreenState extends State<SelfFaceVerifyScreen> {
  final TimesheetFaceCaptureService _capture = TimesheetFaceCaptureService();
  final TimesheetLivenessGate _liveness = TimesheetLivenessGate();
  final BurstVerificationPipeline _burst = BurstVerificationPipeline();
  late final FaceRecognitionService _face = FaceRecognitionService(
    profileDb: ProfilePhotoFaceDb.self,
  );

  CameraController? _camera;
  String _guidance = 'Hold still…';
  bool _busy = false;
  bool _autoFired = false;
  int _failCount = 0;
  bool _streamListening = false;
  int _tempSeq = 0;

  final List<BurstFrameSample> _burstBuf = [];
  DateTime? _lastBurstAt;

  @override
  void initState() {
    super.initState();
    unawaited(_boot());
  }

  Future<void> _boot() async {
    final device = await FaceMinDeviceCheck.evaluate();
    if (!device.passed) {
      _popResult(
        SelfFaceVerifyResult(
          verified: false,
          score: 0,
          livenessOk: false,
          message: SelfFaceTemplateService.deviceMessage,
        ),
      );
      return;
    }

    final tpl = SelfFaceTemplateService.instance;
    if (tpl.status == SelfFaceTemplateStatus.pending) {
      setState(() => _guidance = 'Preparing face check…');
      for (var i = 0;
          i < 40 && tpl.status == SelfFaceTemplateStatus.pending;
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    if (tpl.status != SelfFaceTemplateStatus.ready || tpl.employeeId == null) {
      _popResult(
        SelfFaceVerifyResult(
          verified: false,
          score: 0,
          livenessOk: false,
          message: tpl.reason ?? SelfFaceTemplateService.noPhotoMessage,
        ),
      );
      return;
    }

    await _face.syncFaceDb();
    final cams = await _capture.availableCameraDescriptions();
    final front =
        cams.where((c) => c.lensDirection == CameraLensDirection.front);
    final cam =
        front.isNotEmpty ? front.first : (cams.isNotEmpty ? cams.first : null);
    if (cam == null) {
      _popResult(
        const SelfFaceVerifyResult(
          verified: false,
          score: 0,
          livenessOk: false,
          message: 'No camera available.',
        ),
      );
      return;
    }

    final controller = CameraController(
      cam,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await controller.initialize();
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _camera = controller;
      _guidance = 'Hold still…';
    });
    await controller.startImageStream(_onStreamFrame);
    _streamListening = true;
  }

  void _popResult(SelfFaceVerifyResult result) {
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  Future<void> _onStreamFrame(CameraImage image) async {
    if (_busy || _autoFired || !mounted) return;
    final now = DateTime.now();
    if (_lastBurstAt != null &&
        now.difference(_lastBurstAt!) < AntispoofConfig.burstFrameInterval) {
      return;
    }
    _lastBurstAt = now;
    if (_burstBuf.length >= AntispoofConfig.burstFrameCount) return;

    final rgb = _capture.decodeCameraImage(image);
    if (rgb == null) return;

    try {
      final path = await _writeTempJpg(img.encodeJpg(rgb, quality: 80));
      final detection = await _capture.analyzeImageFile(
        path,
        includeCrop: false,
        alreadyNormalized: true,
      );
      if (!detection.quality.canCapture || detection.primaryFace == null) {
        if (mounted) setState(() => _guidance = detection.quality.message);
        return;
      }
      if (mounted) setState(() => _guidance = 'Hold still…');

      _burstBuf.add(
        BurstFrameSample(
          imagePath: path,
          rgbFrame: rgb,
          faceBox: detection.primaryFace!.boundingBox,
          classification: detection.classification,
        ),
      );

      if (_burstBuf.length >= AntispoofConfig.burstFrameCount) {
        unawaited(_tryAutoVerify());
      }
    } catch (e) {
      debugPrint('SelfFaceVerify stream: $e');
    }
  }

  Future<String> _writeTempJpg(List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/self_face_${DateTime.now().millisecondsSinceEpoch}_'
      '${_tempSeq++}.jpg',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> _tryAutoVerify() async {
    if (_busy || _autoFired) return;
    _busy = true;
    if (mounted) setState(() => _guidance = 'Verifying…');
    try {
      final frames = List<BurstFrameSample>.of(_burstBuf);
      final burstResult = await _burst.verify(frames);
      _liveness.completeBurstVerification(
        passed: burstResult.passed,
        message: burstResult.message,
        layer1: burstResult.lastLayer1,
      );
      if (!burstResult.passed) {
        if (mounted) setState(() => _guidance = burstResult.message);
        return;
      }

      final sample = frames.last;
      final rgb = sample.rgbFrame;
      if (rgb == null) return;

      final empId = SelfFaceTemplateService.instance.employeeId!;
      final verify = await _face.verifyImage(
        source: rgb,
        faceBox: sample.faceBox,
        targetEmployeeId: empId,
      );
      if (verify.outcome == FaceVerifyOutcome.verified) {
        _autoFired = true;
        _popResult(
          SelfFaceVerifyResult(
            verified: true,
            score: verify.targetScore ?? 0,
            livenessOk: true,
          ),
        );
        return;
      }
      _failMatch();
    } finally {
      _busy = false;
      _burstBuf.clear();
    }
  }

  void _failMatch() {
    _failCount += 1;
    _liveness.resetSession();
    if (_failCount >= 3) {
      _popResult(SelfFaceVerifyResult.failedMatch);
      return;
    }
    if (mounted) {
      setState(
        () => _guidance = 'Face not matched — try again ($_failCount/3)',
      );
    }
  }

  Future<void> _onShutter() async {
    if (_busy || _camera == null) return;
    _busy = true;
    if (mounted) setState(() => _guidance = 'Capturing…');
    try {
      if (_streamListening) {
        await _camera!.stopImageStream();
        _streamListening = false;
      }
      final shot = await _camera!.takePicture();
      final detection = await _capture.analyzeImageFile(shot.path);
      if (!detection.quality.canCapture || detection.primaryFace == null) {
        if (mounted) setState(() => _guidance = detection.quality.message);
        await _restartStream();
        return;
      }
      final bytes = await File(shot.path).readAsBytes();
      final rgb = img.decodeImage(bytes);
      if (rgb == null) {
        await _restartStream();
        return;
      }
      final box = detection.primaryFace!.boundingBox;
      final sample = BurstFrameSample(
        imagePath: shot.path,
        rgbFrame: rgb,
        faceBox: box,
        classification: detection.classification,
      );
      final integrity = await _burst.verifyIntegrity(
        [sample, sample, sample, sample],
        requireTemporal: false,
      );
      if (!integrity.passed) {
        if (mounted) setState(() => _guidance = integrity.message);
        await _restartStream();
        return;
      }
      final empId = SelfFaceTemplateService.instance.employeeId!;
      final verify = await _face.verifyImage(
        source: rgb,
        faceBox: box,
        targetEmployeeId: empId,
        landmarks: detection.primaryFace,
      );
      if (verify.outcome == FaceVerifyOutcome.verified) {
        _popResult(
          SelfFaceVerifyResult(
            verified: true,
            score: verify.targetScore ?? 0,
            livenessOk: true,
          ),
        );
        return;
      }
      _failMatch();
      await _restartStream();
    } catch (e) {
      debugPrint('SelfFaceVerify shutter: $e');
      if (mounted) setState(() => _guidance = 'Try again');
      await _restartStream();
    } finally {
      _busy = false;
    }
  }

  Future<void> _restartStream() async {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) return;
    if (!_streamListening) {
      await cam.startImageStream(_onStreamFrame);
      _streamListening = true;
    }
  }

  @override
  void dispose() {
    final cam = _camera;
    if (cam != null) {
      if (_streamListening) {
        unawaited(cam.stopImageStream().catchError((_) {}));
      }
      unawaited(cam.dispose());
    }
    unawaited(_capture.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isCheckIn ? 'Check In' : 'Check Out';
    final cam = _camera;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              Container(
                color: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          color: HomeGlassTheme.textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(width: 48.w),
                  ],
                ),
              ),
              Expanded(
                child: cam == null || !cam.value.isInitialized
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          CameraPreview(cam),
                          CustomPaint(painter: _CornerFramePainter()),
                          Positioned(
                            left: 24.w,
                            right: 24.w,
                            bottom: 120.h,
                            child: Center(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16.w,
                                  vertical: 8.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20.r),
                                ),
                                child: Text(
                                  _guidance,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 28.h,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: GestureDetector(
                                onTap: _busy ? null : _onShutter,
                                child: Container(
                                  width: 72.w,
                                  height: 72.w,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 4,
                                    ),
                                  ),
                                  child: Container(
                                    margin: EdgeInsets.all(4.w),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CornerFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    const inset = 48.0;
    const len = 36.0;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    void corner(Offset o, double dx, double dy) {
      canvas.drawLine(o, o + Offset(dx, 0), paint);
      canvas.drawLine(o, o + Offset(0, dy), paint);
    }

    corner(rect.topLeft, len, len);
    corner(rect.topRight, -len, len);
    corner(rect.bottomLeft, len, -len);
    corner(rect.bottomRight, -len, -len);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
