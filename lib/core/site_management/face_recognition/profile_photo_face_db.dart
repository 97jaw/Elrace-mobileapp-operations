import 'dart:io';
import 'dart:math' as math;

import 'package:el_race/core/site_management/face_recognition/data/models/face_embedding_record.dart';
import 'package:el_race/core/site_management/face_recognition/domain/face_embedder.dart';
import 'package:el_race/core/site_management/face_recognition/domain/face_preprocessor.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';
import 'package:el_race/core/timesheet/services/face_capture_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// TEST ONLY (feature/profile-photo-matching): attendance matches against one
/// template per employee built from the Odoo profile photo instead of the
/// enrollment templates. Same employees as the enrollment face DB, same
/// thresholds and screens. Build with `--dart-define=PROFILE_PHOTO_MATCH=false`
/// to compare against enrollment.
abstract final class ProfilePhotoMatchTest {
  static const bool enabled =
      bool.fromEnvironment('PROFILE_PHOTO_MATCH', defaultValue: true);
}

class ProfilePhotoFaceDb {
  ProfilePhotoFaceDb._();

  static final ProfilePhotoFaceDb instance = ProfilePhotoFaceDb._();

  /// employeeId → unit embedding, or null when the photo is missing or has
  /// no usable face (so it isn't downloaded again this session).
  final Map<int, List<double>?> _embeddings = {};
  Future<void>? _building;

  /// Profile-photo rows for the employees present in [enrollmentRows].
  Future<List<FaceEmbeddingRecord>> rowsFor(
    List<FaceEmbeddingRecord> enrollmentRows, {
    required FacePreprocessor preprocessor,
    required FaceEmbedder embedder,
  }) async {
    final byEmployee = <int, FaceEmbeddingRecord>{};
    for (final row in enrollmentRows) {
      byEmployee.putIfAbsent(row.employeeId, () => row);
    }
    final missing =
        byEmployee.keys.where((id) => !_embeddings.containsKey(id)).toList();
    if (missing.isNotEmpty) {
      while (_building != null) {
        await _building;
      }
      final stillMissing =
          missing.where((id) => !_embeddings.containsKey(id)).toList();
      if (stillMissing.isNotEmpty) {
        final build = _build(stillMissing, preprocessor, embedder);
        _building = build;
        try {
          await build;
        } finally {
          _building = null;
        }
      }
    }

    final rows = <FaceEmbeddingRecord>[];
    for (final entry in byEmployee.entries) {
      final embedding = _embeddings[entry.key];
      if (embedding == null) continue;
      final source = entry.value;
      rows.add(FaceEmbeddingRecord(
        employeeId: source.employeeId,
        empCode: source.empCode,
        name: source.name,
        department: source.department,
        jobTitle: source.jobTitle,
        inForemanTeam: source.inForemanTeam,
        pose: 'profile_photo',
        embedding: embedding,
      ));
    }
    return rows;
  }

  Future<void> _build(
    List<int> employeeIds,
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
      for (final id in employeeIds) {
        final result = await _embedOne(
          id,
          dir,
          capture,
          preprocessor,
          embedder,
        );
        _embeddings[id] = result.embedding;
        switch (result.outcome) {
          case _Outcome.ok:
            ok++;
          case _Outcome.noPhoto:
            noPhoto++;
          case _Outcome.noFace:
            noFace++;
        }
        debugPrint(
          'ProfilePhotoMatch: emp=$id ${result.outcome.name}',
        );
      }
    } finally {
      await capture.dispose();
    }
    debugPrint(
      'ProfilePhotoMatch: built ${employeeIds.length} employees '
      'ok=$ok noPhoto=$noPhoto noFace=$noFace in ${sw.elapsedMilliseconds}ms',
    );
  }

  Future<({List<double>? embedding, _Outcome outcome})> _embedOne(
    int employeeId,
    Directory dir,
    TimesheetFaceCaptureService capture,
    FacePreprocessor preprocessor,
    FaceEmbedder embedder,
  ) async {
    const none = (embedding: null, outcome: _Outcome.noPhoto);
    try {
      final url = Uri.parse(
        '$kTimesheetErpPublicBase/public/employee/image/$employeeId',
      );
      final response =
          await http.get(url).timeout(const Duration(seconds: 15));
      final type = response.headers['content-type'] ?? '';
      if (response.statusCode != 200 ||
          response.bodyBytes.isEmpty ||
          !type.startsWith('image/') ||
          type.contains('svg')) {
        return none;
      }
      final file = File('${dir.path}/profile_face_$employeeId.img');
      await file.writeAsBytes(response.bodyBytes);

      final detection = await capture.analyzeImageFile(
        file.path,
        includeCrop: false,
        relaxedQuality: true,
      );
      final face = detection.primaryFace;
      final analyzedPath = detection.analyzedImagePath;
      if (face == null || analyzedPath == null) {
        return (embedding: null, outcome: _Outcome.noFace);
      }
      final tensor = await preprocessor.buildInputTensorFromCaptureAsync(
        imagePath: analyzedPath,
        faceBox: face.boundingBox,
        landmarks: face,
      );
      if (tensor == null) {
        return (embedding: null, outcome: _Outcome.noFace);
      }
      final raw = await embedder.generateEmbedding(tensor);
      return (embedding: _unit(raw), outcome: _Outcome.ok);
    } catch (e) {
      debugPrint('ProfilePhotoMatch: emp=$employeeId failed: $e');
      return none;
    }
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

enum _Outcome { ok, noPhoto, noFace }
