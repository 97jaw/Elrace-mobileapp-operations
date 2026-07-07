import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:el_race/core/site_management/face_recognition/antispoof/timesheet_face_classification_snapshot.dart';
import 'package:el_race/core/site_management/face_recognition/data/models/face_enrollment_pose.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

enum TimesheetFaceQualityStatus {
  pass,
  noFace,
  tooSmall,
  poseOutOfRange,
  eyesClosed,
  tooBlurry,
}

enum TimesheetLivenessPrompt {
  lookAtCamera,
  blink,
  turnHeadLeft,
  turnHeadRight,
}

class TimesheetFaceQualityResult {
  const TimesheetFaceQualityResult({
    required this.status,
    required this.message,
    required this.canCapture,
  });

  final TimesheetFaceQualityStatus status;
  final String message;
  final bool canCapture;
}

/// Eye / contour positions for mesh overlay + Phase B alignment.
class TimesheetFaceLandmarkSnapshot {
  const TimesheetFaceLandmarkSnapshot({
    required this.boundingBox,
    this.leftEye,
    this.rightEye,
    this.nose,
    this.leftCheek,
    this.rightCheek,
    this.mouthLeft,
    this.mouthRight,
    this.mouthBottom,
    this.leftEar,
    this.rightEar,
    this.meshContours = const [],
  });

  final Rect boundingBox;
  final Offset? leftEye;
  final Offset? rightEye;
  final Offset? nose;
  final Offset? leftCheek;
  final Offset? rightCheek;
  final Offset? mouthLeft;
  final Offset? mouthRight;
  final Offset? mouthBottom;
  final Offset? leftEar;
  final Offset? rightEar;

  /// ML Kit contour polylines (image space), ordered for full-face mesh draw.
  final List<List<Offset>> meshContours;
}

class TimesheetEnrollmentPreviewResult {
  const TimesheetEnrollmentPreviewResult({
    required this.readyToCapture,
    required this.message,
    this.qualityStatus,
  });

  final bool readyToCapture;
  final String message;
  final TimesheetFaceQualityStatus? qualityStatus;
}

class TimesheetEnrollmentFrameResult {
  const TimesheetEnrollmentFrameResult({
    required this.ok,
    required this.message,
    required this.imagePath,
  });

  final bool ok;
  final String message;
  final String imagePath;
}

class TimesheetFaceDetectionResult {
  const TimesheetFaceDetectionResult({
    required this.faceCount,
    required this.faceBoxes,
    required this.quality,
    this.imageSize,
    this.cropBytes,
    /// EXIF-corrected path used for ML Kit boxes (use for Phase B crop).
    this.analyzedImagePath,
    this.primaryFace,
    this.classification,
  });

  final int faceCount;
  final List<Rect> faceBoxes;
  final TimesheetFaceQualityResult quality;
  final Size? imageSize;
  final Uint8List? cropBytes;
  final String? analyzedImagePath;
  final TimesheetFaceLandmarkSnapshot? primaryFace;
  final TimesheetFaceClassificationSnapshot? classification;
}

class TimesheetFaceCapturePermissions {
  const TimesheetFaceCapturePermissions({
    required this.cameraGranted,
    required this.locationGranted,
  });

  final bool cameraGranted;
  final bool locationGranted;

  bool get canOpenCamera => cameraGranted && locationGranted;
}

/// Camera + ML Kit facade for Module 6 face capture.
///
/// Mock-first boundary: this service only detects and crops on-device faces.
/// It never calls AWS Rekognition directly; matching stays behind Firebase
/// callable clients. // TODO(backend)
class TimesheetFaceCaptureService {
  TimesheetFaceCaptureService({FaceDetector? detector})
      : _detector = detector ??
            FaceDetector(
              options: FaceDetectorOptions(
                enableClassification: true,
                enableLandmarks: true,
                enableContours: true,
                enableTracking: true,
                minFaceSize: minFaceDetectorSize,
                performanceMode: FaceDetectorMode.fast,
              ),
            );

  static const int cropSizePx = 224;
  /// Still capture / shutter quality (absolute px in analyzed image).
  static const double minFaceWidthPx = 80;
  /// Live stream — fraction of frame width (allows normal arm-length distance).
  static const double minFaceWidthFractionStream = 0.062;
  static const double minFaceWidthStreamFloorPx = 48;
  static const double maxHeadPoseDegrees = 20;
  static const double maxHeadPoseDegreesStream = 28;
  static const double minEyeOpenProbability = 0.35;
  static const double minEyeOpenProbabilityStream = 0.28;
  static const double minSharpnessScore = 18;
  static const double minFaceDetectorSize = 0.08;

  final FaceDetector _detector;
  final math.Random _random = math.Random();

  Future<TimesheetFaceCapturePermissions> requestCameraPermissions() async {
    final cameraStatus = await Permission.camera.request();
    final locationStatus = await Permission.locationWhenInUse.request();
    return TimesheetFaceCapturePermissions(
      cameraGranted: cameraStatus.isGranted,
      locationGranted: locationStatus.isGranted,
    );
  }

  Future<List<CameraDescription>> availableCameraDescriptions() {
    return availableCameras();
  }

  Future<TimesheetFaceDetectionResult> analyzeImageFile(
    String imagePath, {
    bool includeCrop = true,
    bool relaxedQuality = false,
    bool trustLiveGate = false,
  }) async {
    final normalizedPath = await _normalizedImagePath(imagePath);
    final inputImage = InputImage.fromFilePath(normalizedPath);
    final faces = await _detector.processImage(inputImage);
    final decoded = await _decodeImage(normalizedPath);
    var quality = _evaluateQuality(
      faces,
      relaxedQuality || trustLiveGate ? null : decoded,
    );

    if (!quality.canCapture &&
        (relaxedQuality || trustLiveGate) &&
        faces.isNotEmpty) {
      quality = _evaluateQuality(faces, null);
    }

    if (!quality.canCapture && trustLiveGate && faces.isNotEmpty) {
      quality = const TimesheetFaceQualityResult(
        status: TimesheetFaceQualityStatus.pass,
        message: 'Quality gate passed. Ready to capture.',
        canCapture: true,
      );
    }

    Uint8List? cropBytes;
    if (includeCrop && quality.canCapture && faces.isNotEmpty) {
      cropBytes = await cropFaceFromFile(
        normalizedPath,
        faces.first.boundingBox,
      );
    }

    final primary = faces.isNotEmpty ? _largestFace(faces) : null;
    return TimesheetFaceDetectionResult(
      faceCount: faces.length,
      faceBoxes: faces.map((face) => face.boundingBox).toList(),
      quality: quality,
      imageSize: decoded == null
          ? null
          : Size(decoded.width.toDouble(), decoded.height.toDouble()),
      cropBytes: cropBytes,
      analyzedImagePath: normalizedPath,
      primaryFace: primary == null ? null : _landmarkSnapshot(primary),
      classification: primary == null
          ? null
          : TimesheetFaceClassificationSnapshot.fromFace(primary),
    );
  }

  /// Fixes EXIF rotation so still captures match live ML Kit frames.
  Future<String> _normalizedImagePath(String imagePath) async {
    final decoded = await _decodeImage(imagePath);
    if (decoded == null) return imagePath;
    final oriented = img.bakeOrientation(decoded);
    final dir = await getTemporaryDirectory();
    final out = File(
      '${dir.path}/ts_norm_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await out.writeAsBytes(img.encodeJpg(oriented, quality: 92));
    return out.path;
  }

  /// Silent JPEG from live [CameraImage] stream (no [CameraController.takePicture]).
  Future<String?> saveStreamFrameJpeg(CameraImage image) async {
    try {
      final decoded = _decodeCameraImage(image);
      if (decoded == null) return null;
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/ts_stream_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(path).writeAsBytes(img.encodeJpg(decoded, quality: 82));
      return path;
    } catch (e) {
      debugPrint('TimesheetFaceCapture: stream frame encode failed: $e');
      return null;
    }
  }

  img.Image? _decodeCameraImage(CameraImage image) {
    if (image.format.group == ImageFormatGroup.bgra8888 &&
        image.planes.isNotEmpty) {
      final plane = image.planes.first;
      return img.Image.fromBytes(
        width: image.width,
        height: image.height,
        bytes: plane.bytes.buffer,
        bytesOffset: plane.bytes.offsetInBytes,
        rowStride: plane.bytesPerRow,
        order: img.ChannelOrder.bgra,
      );
    }
    if (image.format.group == ImageFormatGroup.yuv420 &&
        image.planes.length >= 3) {
      return _yuv420ToRgbImage(image);
    }
    return null;
  }

  img.Image? _yuv420ToRgbImage(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final out = img.Image(width: width, height: height);
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;
    final uvRowStride = uPlane.bytesPerRow;

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final yIndex = y * yPlane.bytesPerRow + x;
        final uvIndex = (y >> 1) * uvRowStride + (x >> 1) * uvPixelStride;
        if (yIndex >= yPlane.bytes.length || uvIndex >= uPlane.bytes.length) {
          continue;
        }
        final yVal = yPlane.bytes[yIndex];
        final uVal = uPlane.bytes[uvIndex];
        final vVal = vPlane.bytes[uvIndex];
        final r = (yVal + 1.370705 * (vVal - 128)).clamp(0, 255).toInt();
        final g = (yVal - 0.337633 * (uVal - 128) - 0.698001 * (vVal - 128))
            .clamp(0, 255)
            .toInt();
        final b = (yVal + 1.732446 * (uVal - 128)).clamp(0, 255).toInt();
        out.setPixelRgb(x, y, r, g, b);
      }
    }
    return out;
  }

  Future<TimesheetFaceDetectionResult> analyzeInputImage(
    InputImage inputImage, {
    Size? imageSize,
    bool liveStream = false,
  }) async {
    final faces = await _detector.processImage(inputImage);
    final quality = _evaluateQuality(
      faces,
      null,
      frameSize: imageSize,
      liveStream: liveStream,
    );
    final primary = faces.isNotEmpty ? _largestFace(faces) : null;
    return TimesheetFaceDetectionResult(
      faceCount: faces.length,
      faceBoxes: faces.map((face) => face.boundingBox).toList(),
      quality: quality,
      imageSize: imageSize,
      primaryFace: primary == null ? null : _landmarkSnapshot(primary),
      classification: primary == null
          ? null
          : TimesheetFaceClassificationSnapshot.fromFace(primary),
    );
  }

  Future<Uint8List?> cropFaceFromFile(String imagePath, Rect faceBox) async {
    final source = await _decodeImage(imagePath);
    if (source == null) return null;

    final padded = _paddedCropRect(faceBox, source.width, source.height);
    final cropped = img.copyCrop(
      source,
      x: padded.left.round(),
      y: padded.top.round(),
      width: padded.width.round(),
      height: padded.height.round(),
    );
    final resized = img.copyResize(
      cropped,
      width: cropSizePx,
      height: cropSizePx,
      interpolation: img.Interpolation.average,
    );
    return Uint8List.fromList(img.encodeJpg(resized, quality: 92));
  }

  TimesheetLivenessPrompt nextLivenessPrompt() {
    final prompts = [
      TimesheetLivenessPrompt.lookAtCamera,
      TimesheetLivenessPrompt.blink,
      TimesheetLivenessPrompt.turnHeadLeft,
      TimesheetLivenessPrompt.turnHeadRight,
    ];
    return prompts[_random.nextInt(prompts.length)];
  }

  bool isLivenessPromptSatisfied(
    TimesheetLivenessPrompt prompt,
    Face face,
  ) {
    switch (prompt) {
      case TimesheetLivenessPrompt.lookAtCamera:
        return (face.headEulerAngleY ?? 0).abs() <= 8;
      case TimesheetLivenessPrompt.blink:
        return (face.leftEyeOpenProbability ?? 1) < 0.25 ||
            (face.rightEyeOpenProbability ?? 1) < 0.25;
      case TimesheetLivenessPrompt.turnHeadLeft:
        return (face.headEulerAngleY ?? 0) < -12;
      case TimesheetLivenessPrompt.turnHeadRight:
        return (face.headEulerAngleY ?? 0) > 12;
    }
  }

  TimesheetFaceDetectionResult createMockPassResult() {
    return const TimesheetFaceDetectionResult(
      faceCount: 1,
      faceBoxes: [Rect.fromLTWH(82, 74, 164, 164)],
      quality: TimesheetFaceQualityResult(
        status: TimesheetFaceQualityStatus.pass,
        message: 'Quality gate passed. Ready to capture.',
        canCapture: true,
      ),
      cropBytes: null,
    );
  }

  static InputImage? inputImageFromCameraImage({
    required CameraImage image,
    required CameraDescription camera,
  }) {
    final rotation = _rotationFromSensorOrientation(camera.sensorOrientation);
    final size = Size(image.width.toDouble(), image.height.toDouble());

    if (Platform.isIOS && image.format.group == ImageFormatGroup.bgra8888) {
      final plane = image.planes.first;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: size,
          rotation: rotation,
          format: InputImageFormat.bgra8888,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    }

    if (Platform.isIOS && image.format.group == ImageFormatGroup.yuv420) {
      return InputImage.fromBytes(
        bytes: _concatenatePlanes(image),
        metadata: InputImageMetadata(
          size: size,
          rotation: rotation,
          format: InputImageFormat.yuv420,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    }

    if (Platform.isAndroid && image.format.group == ImageFormatGroup.yuv420) {
      final bytes = _yuv420ToNv21(image);
      if (bytes == null) return null;
      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: size,
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );
    }

    debugPrint('Unsupported camera image format: ${image.format.group}');
    return null;
  }

  /// Live enrollment gate — pose + quality without attendance "face forward" yaw cap.
  Future<TimesheetEnrollmentPreviewResult> previewEnrollmentPose(
    InputImage inputImage,
    FaceEnrollmentPose pose, {
    bool frontCamera = true,
  }) async {
    final faces = await _detector.processImage(inputImage);
    return _previewFromFaces(
      faces,
      pose,
      frontCamera: frontCamera,
    );
  }

  /// Enrollment still capture — same rules as preview + optional blur check.
  Future<TimesheetEnrollmentFrameResult> validateEnrollmentFrame(
    String imagePath,
    FaceEnrollmentPose pose, {
    bool frontCamera = true,
    bool requireSharpness = true,
    bool trustStreamPose = false,
  }) async {
    final normalizedPath = await _normalizedImagePath(imagePath);
    final inputImage = InputImage.fromFilePath(normalizedPath);
    final faces = await _detector.processImage(inputImage);
    final decoded = await _decodeImage(normalizedPath);
    final preview = _previewFromFaces(
      faces,
      pose,
      frontCamera: frontCamera,
      image: requireSharpness ? decoded : null,
      skipPoseCheck: trustStreamPose,
    );
    if (!preview.readyToCapture) {
      return TimesheetEnrollmentFrameResult(
        ok: false,
        message: preview.message,
        imagePath: normalizedPath,
      );
    }
    return TimesheetEnrollmentFrameResult(
      ok: true,
      message: 'Pose accepted',
      imagePath: normalizedPath,
    );
  }

  TimesheetEnrollmentPreviewResult _previewFromFaces(
    List<Face> faces,
    FaceEnrollmentPose pose, {
    bool frontCamera = true,
    img.Image? image,
    bool skipPoseCheck = false,
  }) {
    if (faces.isEmpty) {
      return const TimesheetEnrollmentPreviewResult(
        readyToCapture: false,
        message: 'No face detected. Look at the camera.',
        qualityStatus: TimesheetFaceQualityStatus.noFace,
      );
    }
    if (faces.length != 1) {
      return const TimesheetEnrollmentPreviewResult(
        readyToCapture: false,
        message: 'Only one face should be in the frame.',
      );
    }
    final face = _largestFace(faces);
    final yaw = face.headEulerAngleY ?? 0;
    final pitch = face.headEulerAngleX ?? 0;

    if (face.boundingBox.width < minFaceWidthPx) {
      return const TimesheetEnrollmentPreviewResult(
        readyToCapture: false,
        message: 'Move closer to the camera.',
        qualityStatus: TimesheetFaceQualityStatus.tooSmall,
      );
    }

    final roll = (face.headEulerAngleZ ?? 0).abs();
    if (roll > 28) {
      return const TimesheetEnrollmentPreviewResult(
        readyToCapture: false,
        message: 'Keep your head level.',
        qualityStatus: TimesheetFaceQualityStatus.poseOutOfRange,
      );
    }

    final leftEye = face.leftEyeOpenProbability;
    final rightEye = face.rightEyeOpenProbability;
    if ((leftEye != null && leftEye < minEyeOpenProbability) ||
        (rightEye != null && rightEye < minEyeOpenProbability)) {
      return const TimesheetEnrollmentPreviewResult(
        readyToCapture: false,
        message: 'Open your eyes.',
        qualityStatus: TimesheetFaceQualityStatus.eyesClosed,
      );
    }

    if (image != null && _sharpnessScore(image) < minSharpnessScore) {
      return const TimesheetEnrollmentPreviewResult(
        readyToCapture: false,
        message: 'Hold still. Image is too blurry.',
        qualityStatus: TimesheetFaceQualityStatus.tooBlurry,
      );
    }

    if (!skipPoseCheck &&
        !pose.matchesHeadAngles(
          yaw: yaw,
          pitch: pitch,
          frontCamera: frontCamera,
        )) {
      return TimesheetEnrollmentPreviewResult(
        readyToCapture: false,
        message: pose.poseHint(
          yaw: yaw,
          pitch: pitch,
          frontCamera: frontCamera,
        ),
        qualityStatus: TimesheetFaceQualityStatus.poseOutOfRange,
      );
    }

    return const TimesheetEnrollmentPreviewResult(
      readyToCapture: true,
      message: 'Perfect — hold still',
    );
  }

  Future<void> dispose() => _detector.close();

  static InputImageRotation _rotationFromSensorOrientation(int orientation) {
    switch (orientation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      case 0:
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  static Uint8List? _yuv420ToNv21(CameraImage image) {
    if (image.planes.length < 3) return null;
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final out = Uint8List(width * height + (width * height ~/ 2));
    var offset = 0;

    for (var row = 0; row < height; row += 1) {
      final rowStart = row * yPlane.bytesPerRow;
      out.setRange(
        offset,
        offset + width,
        yPlane.bytes,
        rowStart,
      );
      offset += width;
    }

    final uvWidth = width ~/ 2;
    final uvHeight = height ~/ 2;
    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;

    for (var row = 0; row < uvHeight; row += 1) {
      for (var col = 0; col < uvWidth; col += 1) {
        final uIndex = row * uPlane.bytesPerRow + col * uPixelStride;
        final vIndex = row * vPlane.bytesPerRow + col * vPixelStride;
        if (offset + 1 >= out.length ||
            uIndex >= uPlane.bytes.length ||
            vIndex >= vPlane.bytes.length) {
          return out;
        }
        out[offset] = vPlane.bytes[vIndex];
        out[offset + 1] = uPlane.bytes[uIndex];
        offset += 2;
      }
    }

    return out;
  }

  static Uint8List _concatenatePlanes(CameraImage image) {
    final length = image.planes.fold<int>(
      0,
      (total, plane) => total + plane.bytes.length,
    );
    final bytes = Uint8List(length);
    var offset = 0;
    for (final plane in image.planes) {
      bytes.setRange(offset, offset + plane.bytes.length, plane.bytes);
      offset += plane.bytes.length;
    }
    return bytes;
  }

  TimesheetFaceQualityResult _evaluateQuality(
    List<Face> faces,
    img.Image? image, {
    Size? frameSize,
    bool liveStream = false,
  }) {
    if (faces.isEmpty) {
      return const TimesheetFaceQualityResult(
        status: TimesheetFaceQualityStatus.noFace,
        message: 'No face detected. Look at the camera.',
        canCapture: false,
      );
    }

    final face = _largestFace(faces);
    final minWidth = liveStream && frameSize != null
        ? math.max(
            minFaceWidthStreamFloorPx,
            frameSize.width * minFaceWidthFractionStream,
          )
        : minFaceWidthPx;
    if (face.boundingBox.width < minWidth) {
      return TimesheetFaceQualityResult(
        status: TimesheetFaceQualityStatus.tooSmall,
        message: liveStream
            ? 'Step into frame — face the camera.'
            : 'Move closer to the camera.',
        canCapture: false,
      );
    }

    final maxPose = liveStream ? maxHeadPoseDegreesStream : maxHeadPoseDegrees;
    final yaw = (face.headEulerAngleY ?? 0).abs();
    final roll = (face.headEulerAngleZ ?? 0).abs();
    if (yaw > maxPose || roll > maxPose) {
      return const TimesheetFaceQualityResult(
        status: TimesheetFaceQualityStatus.poseOutOfRange,
        message: 'Face the camera and hold still.',
        canCapture: false,
      );
    }

    final minEye = liveStream ? minEyeOpenProbabilityStream : minEyeOpenProbability;
    final leftEye = face.leftEyeOpenProbability;
    final rightEye = face.rightEyeOpenProbability;
    if ((leftEye != null && leftEye < minEye) ||
        (rightEye != null && rightEye < minEye)) {
      return const TimesheetFaceQualityResult(
        status: TimesheetFaceQualityStatus.eyesClosed,
        message: 'Open eyes and retake.',
        canCapture: false,
      );
    }

    if (image != null && _sharpnessScore(image) < minSharpnessScore) {
      return const TimesheetFaceQualityResult(
        status: TimesheetFaceQualityStatus.tooBlurry,
        message: 'Hold still. Image is too blurry.',
        canCapture: false,
      );
    }

    return const TimesheetFaceQualityResult(
      status: TimesheetFaceQualityStatus.pass,
      message: 'Quality gate passed. Ready to capture.',
      canCapture: true,
    );
  }

  Face _largestFace(List<Face> faces) {
    Face best = faces.first;
    var bestArea = best.boundingBox.width * best.boundingBox.height;
    for (final face in faces.skip(1)) {
      final area = face.boundingBox.width * face.boundingBox.height;
      if (area > bestArea) {
        best = face;
        bestArea = area;
      }
    }
    return best;
  }

  TimesheetFaceLandmarkSnapshot _landmarkSnapshot(Face face) {
    Offset? lm(FaceLandmarkType type) {
      final p = face.landmarks[type]?.position;
      if (p == null) return null;
      return Offset(p.x.toDouble(), p.y.toDouble());
    }

    return TimesheetFaceLandmarkSnapshot(
      boundingBox: face.boundingBox,
      leftEye: lm(FaceLandmarkType.leftEye),
      rightEye: lm(FaceLandmarkType.rightEye),
      nose: lm(FaceLandmarkType.noseBase),
      leftCheek: lm(FaceLandmarkType.leftCheek),
      rightCheek: lm(FaceLandmarkType.rightCheek),
      mouthLeft: lm(FaceLandmarkType.leftMouth),
      mouthRight: lm(FaceLandmarkType.rightMouth),
      mouthBottom: lm(FaceLandmarkType.bottomMouth),
      leftEar: lm(FaceLandmarkType.leftEar),
      rightEar: lm(FaceLandmarkType.rightEar),
      meshContours: _meshContours(face),
    );
  }

  List<List<Offset>> _meshContours(Face face) {
    const types = <FaceContourType>[
      FaceContourType.face,
      FaceContourType.leftEyebrowTop,
      FaceContourType.leftEyebrowBottom,
      FaceContourType.rightEyebrowTop,
      FaceContourType.rightEyebrowBottom,
      FaceContourType.leftEye,
      FaceContourType.rightEye,
      FaceContourType.noseBridge,
      FaceContourType.noseBottom,
      FaceContourType.upperLipTop,
      FaceContourType.upperLipBottom,
      FaceContourType.lowerLipTop,
      FaceContourType.lowerLipBottom,
      FaceContourType.leftCheek,
      FaceContourType.rightCheek,
    ];

    final out = <List<Offset>>[];
    for (final type in types) {
      final contour = face.contours[type];
      if (contour == null || contour.points.length < 2) continue;
      out.add(
        contour.points
            .map((p) => Offset(p.x.toDouble(), p.y.toDouble()))
            .toList(growable: false),
      );
    }
    return out;
  }

  Future<img.Image?> _decodeImage(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) return null;
    return img.decodeImage(await file.readAsBytes());
  }

  Rect _paddedCropRect(Rect faceBox, int imageWidth, int imageHeight) {
    final padding = faceBox.width * 0.22;
    final left = math.max(0.0, faceBox.left - padding);
    final top = math.max(0.0, faceBox.top - padding);
    final right = math.min(imageWidth.toDouble(), faceBox.right + padding);
    final bottom = math.min(imageHeight.toDouble(), faceBox.bottom + padding);
    return Rect.fromLTRB(left, top, right, bottom);
  }

  double _sharpnessScore(img.Image image) {
    if (image.width < 3 || image.height < 3) return 0;

    var samples = 0;
    var sum = 0.0;
    var squaredSum = 0.0;
    final stepX = math.max(1, image.width ~/ 32);
    final stepY = math.max(1, image.height ~/ 32);

    for (var y = 1; y < image.height - 1; y += stepY) {
      for (var x = 1; x < image.width - 1; x += stepX) {
        final center = _luminance(image.getPixel(x, y));
        final laplacian = (_luminance(image.getPixel(x - 1, y)) +
                _luminance(image.getPixel(x + 1, y)) +
                _luminance(image.getPixel(x, y - 1)) +
                _luminance(image.getPixel(x, y + 1))) -
            (4 * center);
        samples += 1;
        sum += laplacian;
        squaredSum += laplacian * laplacian;
      }
    }

    if (samples == 0) return 0;
    final mean = sum / samples;
    return (squaredSum / samples) - (mean * mean);
  }

  double _luminance(img.Pixel pixel) {
    return (0.299 * pixel.r) + (0.587 * pixel.g) + (0.114 * pixel.b);
  }
}
