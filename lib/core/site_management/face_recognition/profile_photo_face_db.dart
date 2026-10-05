import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:el_race/core/site_management/face_recognition/data/models/face_embedding_record.dart';
import 'package:el_race/core/site_management/face_recognition/domain/face_embedder.dart';
import 'package:el_race/core/site_management/face_recognition/domain/face_preprocessor.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';
import 'package:el_race/core/timesheet/services/face_capture_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// TEST ONLY (feature/profile-photo-matching): attendance ignores the
/// enrollment face DB (0 templates used) and matches against one template per
/// project labour built on device from the Odoo profile photo. Thresholds and
/// screens unchanged. `--dart-define=PROFILE_PHOTO_MATCH=false` restores the
/// enrollment behaviour.
abstract final class ProfilePhotoMatchTest {
  static const bool enabled =
      bool.fromEnvironment('PROFILE_PHOTO_MATCH', defaultValue: true);
}

class ProfilePhotoFaceDb {
  ProfilePhotoFaceDb._();

  static final ProfilePhotoFaceDb instance = ProfilePhotoFaceDb._();

  static const int _parallelDownloads = 4;

  List<TimesheetOdooEmployee> _labour = const [];

  /// employeeId → unit embedding, or null when the photo is missing or has
  /// no usable face (so it isn't downloaded again this session).
  final Map<int, List<double>?> _embeddings = {};
  final Map<int, ({int sourceWidth, int sourceHeight, int faceSourcePx})>
      _photoInfo = {};
  Future<void>? _building;

  FacePreprocessor? _preprocessor;
  FaceEmbedder? _embedder;

  /// Called when the attendance screen loads the project labour list.
  void setLabour(List<TimesheetOdooEmployee> labour) {
    _labour = labour.where((e) => e.canUseFaceMatch).toList();
    debugPrint(
      'ProfilePhotoMatch: labour roster set ${_labour.length} employees',
    );
    final preprocessor = _preprocessor;
    final embedder = _embedder;
    if (preprocessor != null && embedder != null) {
      unawaited(rows(preprocessor: preprocessor, embedder: embedder));
    }
  }

  bool hasTemplateFor(int employeeId) => _embeddings[employeeId] != null;

  /// Profile-photo rows for the current labour roster; builds missing ones.
  Future<List<FaceEmbeddingRecord>> rows({
    required FacePreprocessor preprocessor,
    required FaceEmbedder embedder,
  }) async {
    _preprocessor = preprocessor;
    _embedder = embedder;
    final labour = _labour;
    if (labour.isEmpty) {
      debugPrint('ProfilePhotoMatch: no labour roster yet — 0 templates');
      return const [];
    }
    while (_building != null) {
      await _building;
    }
    final missing =
        labour.where((e) => !_embeddings.containsKey(e.employeeId)).toList();
    if (missing.isNotEmpty) {
      final build = _build(missing, preprocessor, embedder);
      _building = build;
      try {
        await build;
      } finally {
        _building = null;
      }
    }

    return [
      for (final e in labour)
        if (_embeddings[e.employeeId] != null)
          FaceEmbeddingRecord(
            employeeId: e.employeeId,
            empCode: e.displayFileId,
            name: e.name,
            department: e.department ?? '',
            jobTitle: e.jobPosition ?? '',
            inForemanTeam: true,
            pose: 'profile_photo',
            embedding: _embeddings[e.employeeId]!,
          ),
    ];
  }

  Future<void> _build(
    List<TimesheetOdooEmployee> employees,
    FacePreprocessor preprocessor,
    FaceEmbedder embedder,
  ) async {
    final sw = Stopwatch()..start();
    final capture = TimesheetFaceCaptureService();
    final dir = await getTemporaryDirectory();
    var ok = 0;
    var noPhoto = 0;
    var noFace = 0;
    try {
      await embedder.ensureLoaded();
      for (var i = 0; i < employees.length; i += _parallelDownloads) {
        final batch = employees.skip(i).take(_parallelDownloads).toList();
        final photos = await Future.wait(batch.map(_download));
        for (var j = 0; j < batch.length; j++) {
          final employee = batch[j];
          final bytes = photos[j];
          List<double>? embedding;
          String outcome;
          if (bytes == null) {
            outcome = 'noPhoto';
            noPhoto++;
          } else {
            embedding = await _embed(
              employee.employeeId,
              bytes,
              dir,
              capture,
              preprocessor,
              embedder,
            );
            if (embedding == null) {
              outcome = 'noFace';
              noFace++;
            } else {
              outcome = 'ok';
              ok++;
            }
          }
          _embeddings[employee.employeeId] = embedding;
          debugPrint(
            'ProfilePhotoMatch: emp=${employee.employeeId} '
            '${employee.name} $outcome',
          );
        }
      }
    } finally {
      await capture.dispose();
    }
    debugPrint(
      'ProfilePhotoMatch: built ${employees.length} employees '
      'ok=$ok noPhoto=$noPhoto noFace=$noFace in ${sw.elapsedMilliseconds}ms',
    );
    _logQualityReport(employees);
  }

  Future<Uint8List?> _download(TimesheetOdooEmployee employee) async {
    final url = employee.faceMatchImageUrl;
    if (url == null) return null;
    try {
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      final type = response.headers['content-type'] ?? '';
      if (response.statusCode != 200 ||
          response.bodyBytes.isEmpty ||
          !type.startsWith('image/') ||
          type.contains('svg')) {
        return null;
      }
      return response.bodyBytes;
    } catch (e) {
      debugPrint(
        'ProfilePhotoMatch: emp=${employee.employeeId} download failed: $e',
      );
      return null;
    }
  }

  Future<List<double>?> _embed(
    int employeeId,
    Uint8List bytes,
    Directory dir,
    TimesheetFaceCaptureService capture,
    FacePreprocessor preprocessor,
    FaceEmbedder embedder,
  ) async {
    try {
      final prepared = await compute(_prepareProfilePhoto, bytes);
      if (prepared == null) {
        debugPrint('ProfilePhotoMatch: emp=$employeeId undecodable image');
        return null;
      }
      final file = File('${dir.path}/profile_face_$employeeId.jpg');
      await file.writeAsBytes(prepared.jpg);
      final detection = await capture.analyzeImageFile(
        file.path,
        includeCrop: false,
        relaxedQuality: true,
      );
      final face = detection.primaryFace;
      final analyzedPath = detection.analyzedImagePath;
      if (face == null || analyzedPath == null) {
        debugPrint(
          'ProfilePhotoMatch: emp=$employeeId detector found no face '
          'faces=${detection.faceCount} img=${detection.imageSize}',
        );
        return null;
      }
      var tensor = await preprocessor.buildInputTensorFromCaptureAsync(
        imagePath: analyzedPath,
        faceBox: face.boundingBox,
        landmarks: face,
      );
      tensor ??= await preprocessor.buildInputTensorFromCaptureAsync(
        imagePath: file.path,
        faceBox: face.boundingBox,
      );
      if (tensor == null) {
        debugPrint(
          'ProfilePhotoMatch: emp=$employeeId crop failed '
          'img=${detection.imageSize} box=${face.boundingBox} '
          'eyes=${face.leftEye}/${face.rightEye} faces=${detection.faceCount}',
        );
        return null;
      }
      _photoInfo[employeeId] = (
        sourceWidth: prepared.sourceWidth,
        sourceHeight: prepared.sourceHeight,
        faceSourcePx: (face.boundingBox.width / prepared.scale).round(),
      );
      return _unit(await embedder.generateEmbedding(tensor));
    } catch (e) {
      debugPrint('ProfilePhotoMatch: emp=$employeeId embed failed: $e');
      return null;
    }
  }

  /// HR photos are often 128 px thumbnails or transparent PNGs cropped tight
  /// to the head; the detector needs a larger, opaque image with some margin.
  static _PreparedPhoto? _prepareProfilePhoto(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    var photo = img.bakeOrientation(decoded);
    final sourceWidth = photo.width;
    final sourceHeight = photo.height;
    var scale = 1.0;
    final shortSide = math.min(photo.width, photo.height);
    if (shortSide < _minPhotoShortSidePx) {
      scale = _minPhotoShortSidePx / shortSide;
      photo = img.copyResize(
        photo,
        width: (photo.width * scale).round(),
        height: (photo.height * scale).round(),
        interpolation: img.Interpolation.cubic,
      );
    }
    final margin = (math.max(photo.width, photo.height) * 0.15).round();
    final canvas = img.Image(
      width: photo.width + margin * 2,
      height: photo.height + margin * 2,
    );
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(canvas, photo, dstX: margin, dstY: margin);
    return (
      jpg: img.encodeJpg(canvas, quality: 95),
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      scale: scale,
    );
  }

  static const int _minPhotoShortSidePx = 480;

  /// Face narrower than this in the original upload is upscaled guesswork.
  static const int _lowResFacePx = 90;

  /// Two different employees' photos closer than this are easily confused.
  static const double _lookAlikeCosine = 0.45;

  /// One line per profile template, worst first, so HR knows which photos to
  /// replace.
  void _logQualityReport(List<TimesheetOdooEmployee> employees) {
    final names = {for (final e in _labour) e.employeeId: e.name};
    final built = [
      for (final e in _labour)
        if (_embeddings[e.employeeId] != null) e.employeeId,
    ];
    final lines = <({int rank, String text})>[];
    var good = 0;
    var lowRes = 0;
    var lookAlike = 0;
    for (final e in employees) {
      final id = e.employeeId;
      final emb = _embeddings[id];
      final info = _photoInfo[id];
      if (emb == null || info == null) continue;
      var closestId = -1;
      var closest = -1.0;
      for (final other in built) {
        if (other == id) continue;
        final score = _dot(emb, _embeddings[other]!);
        if (score > closest) {
          closest = score;
          closestId = other;
        }
      }
      final isLowRes = info.faceSourcePx < _lowResFacePx;
      final isLookAlike = closest >= _lookAlikeCosine;
      final grade = isLowRes && isLookAlike
          ? 'LOW_RES+LOOK_ALIKE'
          : isLowRes
              ? 'LOW_RES'
              : isLookAlike
                  ? 'LOOK_ALIKE'
                  : 'good';
      if (grade == 'good') good++;
      if (isLowRes) lowRes++;
      if (isLookAlike) lookAlike++;
      lines.add((
        rank: (isLowRes ? 2 : 0) + (isLookAlike ? 1 : 0),
        text: 'ProfilePhotoQuality: $grade emp=$id ${e.name} '
            'photo=${info.sourceWidth}x${info.sourceHeight} '
            'face=${info.faceSourcePx}px closest=emp $closestId '
            '${names[closestId] ?? ''} ${closest.toStringAsFixed(3)}',
      ));
    }
    lines.sort((a, b) => b.rank.compareTo(a.rank));
    for (final line in lines) {
      debugPrint(line.text);
    }
    debugPrint(
      'ProfilePhotoQuality: summary good=$good lowRes=$lowRes '
      'lookAlike=$lookAlike (lowRes = face < ${_lowResFacePx}px in upload, '
      'lookAlike = >= $_lookAlikeCosine to another employee)',
    );
  }

  static double _dot(List<double> a, List<double> b) {
    var sum = 0.0;
    for (var i = 0; i < a.length; i++) {
      sum += a[i] * b[i];
    }
    return sum;
  }

  static List<double> _unit(List<double> v) {
    var sum = 0.0;
    for (final x in v) {
      sum += x * x;
    }
    if (sum <= 0) return v;
    final inv = 1 / math.sqrt(sum);
    return [for (final x in v) x * inv];
  }
}

typedef _PreparedPhoto = ({
  Uint8List jpg,
  int sourceWidth,
  int sourceHeight,
  double scale,
});
