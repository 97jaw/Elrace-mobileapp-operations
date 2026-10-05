import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:el_race/core/site_management/face_recognition/data/models/face_e3_verification_report.dart';
import 'package:el_race/core/site_management/face_recognition/data/models/face_embedding_record.dart';
import 'package:el_race/core/site_management/face_recognition/data/models/face_enrollment_check_report.dart';
import 'package:el_race/core/site_management/face_recognition/data/models/face_match_result.dart';
import 'package:el_race/core/site_management/face_recognition/face_pilot_log_store.dart';
import 'package:el_race/core/site_management/face_recognition/data/repositories/face_db_repository.dart';
import 'package:el_race/core/site_management/face_recognition/domain/face_embedder.dart';
import 'package:el_race/core/site_management/face_recognition/domain/face_matcher.dart';
import 'package:el_race/core/site_management/face_recognition/domain/face_preprocessor.dart';
import 'package:el_race/core/site_management/face_recognition/face_match_logger.dart';
import 'package:el_race/core/site_management/face_recognition/face_recognition_availability.dart';
import 'package:el_race/core/site_management/face_recognition/face_recognition_config.dart';
import 'package:el_race/core/site_management/face_recognition/profile_photo_face_db.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';
import 'package:el_race/core/timesheet/services/face_capture_service.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Site Management Phase B — on-device embed + match (no UI).
class FaceRecognitionService {
  FaceRecognitionService({
    FaceDbRepository? repository,
    FacePreprocessor? preprocessor,
    FaceEmbedder? embedder,
    FaceMatcher? matcher,
  })  : _repository = repository ?? FaceDbRepository(),
        _preprocessor = preprocessor ?? const FacePreprocessor(),
        _embedder = embedder ?? FaceEmbedder.instance,
        _matcher = matcher ?? FaceMatcher();

  final FaceDbRepository _repository;
  final FacePreprocessor _preprocessor;
  final FaceEmbedder _embedder;
  final FaceMatcher _matcher;

  bool _syncReady = false;
  bool _engineReady = false;
  bool _engineLoadFailed = false;
  String? _engineError;
  FaceSyncResult? _lastSync;

  FaceSyncResult? get lastSync => _lastSync;
  bool get isReady => _syncReady;

  /// Underlying reason the TFLite engine failed to load (release diagnostics).
  String? get engineError => _engineError;

  FaceRecognitionAvailability get availability {
    if (_lastSync == null) {
      return FaceRecognitionAvailability.notInitialized;
    }
    // Empty face DB is not an engine failure (was misreported before).
    if (_lastSync!.status == FaceSyncStatus.empty) {
      return FaceRecognitionAvailability.noEmbeddings;
    }
    if (_engineLoadFailed) {
      return FaceRecognitionAvailability.engineFailed;
    }
    return _lastSync!.toAvailability(engineReady: _syncReady && _engineReady);
  }

  Future<FaceSyncResult> syncFaceDb() async {
    if (ProfilePhotoMatchTest.enabled) return _profilePhotoSync();
    final result = await _repository.syncIfNeeded();
    _lastSync = result;
    _syncReady = result.status == FaceSyncStatus.upToDate ||
        result.status == FaceSyncStatus.synced ||
        (result.status == FaceSyncStatus.failed &&
            result.message != null &&
            result.message!.startsWith('offline_cache'));
    debugPrint(
      'FaceRecognition: sync status=${result.status} '
      'templates=${result.count} ready=$_syncReady '
      '${result.message ?? ''}',
    );
    _engineReady = false;
    _engineLoadFailed = false;
    _engineError = null;
    if (_syncReady) {
      try {
        await _embedder.ensureLoaded();
        _engineReady = true;
      } catch (e) {
        debugPrint('FaceRecognition: TFLite preload failed: $e');
        _syncReady = false;
        _engineReady = false;
        _engineLoadFailed = true;
        _engineError = e.toString();
      }
    }
    return result;
  }

  /// Test build: never reads the enrollment face DB; templates come from the
  /// labour roster's profile photos instead.
  Future<FaceSyncResult> _profilePhotoSync() async {
    final result = FaceSyncResult.upToDate(count: 0);
    _lastSync = result;
    debugPrint(
      'ProfilePhotoMatch: enrollment face DB ignored — 0 templates used',
    );
    try {
      await _embedder.ensureLoaded();
      _engineReady = true;
      _syncReady = true;
      _engineLoadFailed = false;
      _engineError = null;
      unawaited(ProfilePhotoFaceDb.instance.rows(
        preprocessor: _preprocessor,
        embedder: _embedder,
      ));
    } catch (e) {
      debugPrint('FaceRecognition: TFLite preload failed: $e');
      _syncReady = false;
      _engineReady = false;
      _engineLoadFailed = true;
      _engineError = e.toString();
    }
    return result;
  }

  /// Full re-download of face DB (use when Odoo enrollment changed outside the app).
  Future<FaceSyncResult> syncFaceDbForceRefresh() async {
    if (ProfilePhotoMatchTest.enabled) return _profilePhotoSync();
    final result = await _repository.forceRefresh();
    _lastSync = result;
    _syncReady = result.status == FaceSyncStatus.upToDate ||
        result.status == FaceSyncStatus.synced ||
        (result.status == FaceSyncStatus.failed &&
            result.message != null &&
            result.message!.startsWith('offline_cache'));
    debugPrint(
      'FaceRecognition: force refresh status=${result.status} '
      'templates=${result.count} ready=$_syncReady',
    );
    _engineReady = false;
    _engineLoadFailed = false;
    _engineError = null;
    if (_syncReady) {
      try {
        await _embedder.ensureLoaded();
        _engineReady = true;
      } catch (e) {
        debugPrint('FaceRecognition: TFLite preload failed: $e');
        _syncReady = false;
        _engineReady = false;
        _engineLoadFailed = true;
        _engineError = e.toString();
      }
    }
    return result;
  }

  /// Match capture photo against cached face DB. Returns null if sync/engine not ready.
  Future<FaceMatchResult?> matchCapturePhoto({
    required String imagePath,
    required Rect faceBox,
    TimesheetFaceLandmarkSnapshot? landmarks,
    int? focusEmployeeId,
  }) async {
    if (!_syncReady) return null;
    try {
      final preprocessSw = Stopwatch()..start();
      final tensor = await _preprocessor.buildInputTensorFromCaptureAsync(
        imagePath: imagePath,
        faceBox: faceBox,
        landmarks: landmarks,
      );
      final preprocessMs = preprocessSw.elapsedMilliseconds;
      if (tensor == null) {
        debugPrint(
          'FaceRecognition: chip build failed path=$imagePath box=$faceBox',
        );
        return FaceMatchResult.none;
      }
      return _matchFromTensor(
        tensor: tensor,
        preprocessMs: preprocessMs,
        imagePath: imagePath,
        focusEmployeeId: focusEmployeeId,
      );
    } catch (e, st) {
      debugPrint('FaceRecognition.matchCapturePhoto failed: $e\n$st');
      return null;
    }
  }

  /// Live-path match from an already-decoded RGB frame (no disk I/O).
  Future<FaceMatchResult?> matchImage({
    required img.Image source,
    required Rect faceBox,
    TimesheetFaceLandmarkSnapshot? landmarks,
    int? focusEmployeeId,
  }) async {
    if (!_syncReady) return null;
    try {
      final preprocessSw = Stopwatch()..start();
      final tensor = _preprocessor.buildInputTensorFromImage(
        source: source,
        faceBox: faceBox,
        landmarks: landmarks,
      );
      final preprocessMs = preprocessSw.elapsedMilliseconds;
      if (tensor == null) {
        debugPrint('FaceRecognition: chip build failed (memory) box=$faceBox');
        return FaceMatchResult.none;
      }
      return _matchFromTensor(
        tensor: tensor,
        preprocessMs: preprocessMs,
        imagePath: 'memory://camera_frame',
        focusEmployeeId: focusEmployeeId,
      );
    } catch (e, st) {
      debugPrint('FaceRecognition.matchImage failed: $e\n$st');
      return null;
    }
  }

  Future<FaceMatchResult?> _matchFromTensor({
    required Float32List tensor,
    required int preprocessMs,
    required String imagePath,
    int? focusEmployeeId,
  }) async {
    final totalSw = Stopwatch()..start();
    final embedSw = Stopwatch()..start();
    final embedding = await _embedder.generateEmbedding(tensor);
    final embedMs = embedSw.elapsedMilliseconds;
    var probeNormSq = 0.0;
    for (final v in embedding) {
      probeNormSq += v * v;
    }
    final roster = await _attendanceRoster();
    if (roster.isEmpty) return FaceMatchResult.none;
    _logCacheDiagnostics(roster);
    final matchSw = Stopwatch()..start();
    final result = _matcher.findBestMatch(embedding, roster);
    final matchMs = matchSw.elapsedMilliseconds;
    if (ProfilePhotoMatchTest.enabled) {
      debugPrint(
        'ProfilePhotoMatch: result '
        'emp=${result.best?.employeeId} ${result.best?.name} '
        'best=${result.bestScore.toStringAsFixed(3)} '
        'second=${result.secondBestScore.toStringAsFixed(3)} '
        'margin=${result.winnerMargin.toStringAsFixed(3)} '
        'match=${result.isMatch} templates=${roster.length} (profile photos)',
      );
    }
    final totalMs = totalSw.elapsedMilliseconds + preprocessMs;
    final best = result.best;
    if (best != null && kDebugMode) {
      final perTemplate = _matcher.scoreTemplatesForEmployee(
        embedding,
        roster,
        best.employeeId,
      );
      FaceMatchLogger.logTemplateScores(
        employeeId: best.employeeId,
        scores: perTemplate.map((t) => (pose: t.pose, score: t.score)).toList(),
      );
      final e3Pass = perTemplate.isNotEmpty &&
          perTemplate.first.score >= FaceRecognitionMatch.verificationMinCosine;
      debugPrint(
        'FaceRecognition: E.3 topTemplate='
        '${perTemplate.isNotEmpty ? perTemplate.first.score.toStringAsFixed(4) : "n/a"} '
        'pass=${e3Pass ? "YES" : "NO"} '
        '(need >= ${FaceRecognitionMatch.verificationMinCosine})',
      );
    }
    FaceMatchLogger.logAttempt(
      bestScore: result.bestScore,
      secondBestScore: result.secondBestScore,
      employeeId: best?.employeeId,
      employeeName: best?.name,
      inForemanTeam: best?.inForemanTeam ?? false,
      matchedAtProductionThreshold:
          result.bestScore >= FaceRecognitionMatch.defaultThreshold,
      templateCount: roster.length,
      preprocessMs: preprocessMs,
      embedMs: embedMs,
      matchMs: matchMs,
      totalMs: totalMs,
      imagePath: imagePath,
    );
    debugPrint(
      'FaceRecognition: probeNorm=${probeNormSq.toStringAsFixed(4)} '
      'cacheRows=${roster.length} '
      'best=${result.bestScore.toStringAsFixed(4)} '
      'second=${result.secondBestScore.toStringAsFixed(4)} '
      'margin=${result.winnerMargin.toStringAsFixed(4)} '
      'match=${result.isMatch} display=${result.passesDisplayThreshold} '
      'emp=${best?.employeeId} ${best?.name} '
      'timing=pre$preprocessMs+emb$embedMs+mat$matchMs=${totalMs}ms',
    );
    if (focusEmployeeId == null) return result;
    final focus = _matcher.scoreTemplatesForEmployee(
      embedding,
      roster,
      focusEmployeeId,
    );
    final focusScore = focus.isEmpty ? null : focus.first.score;
    debugPrint(
      'FaceRecognition: focus emp=$focusEmployeeId '
      'score=${focusScore?.toStringAsFixed(4) ?? 'no_templates'}',
    );
    return result.withFocusScore(focusScore);
  }

  /// Full re-download when [employeeId] (e.g. just enrolled) has no templates
  /// in the local cache yet. Returns true once templates are present.
  Future<bool> ensureTemplatesFor(int employeeId) async {
    if (ProfilePhotoMatchTest.enabled) {
      await _attendanceRoster();
      return ProfilePhotoFaceDb.instance.hasTemplateFor(employeeId);
    }
    var roster = await _repository.loadCached();
    if (roster.any((r) => r.employeeId == employeeId)) return true;
    await syncFaceDbForceRefresh();
    roster = await _repository.loadCached();
    final ok = roster.any((r) => r.employeeId == employeeId);
    debugPrint('FaceRecognition: ensureTemplatesFor emp=$employeeId ok=$ok');
    return ok;
  }

  /// Templates attendance matches against: enrollment templates, or (test
  /// build) one profile-photo template per enrolled employee.
  Future<List<FaceEmbeddingRecord>> _attendanceRoster() {
    if (!ProfilePhotoMatchTest.enabled) return _repository.loadCached();
    return ProfilePhotoFaceDb.instance.rows(
      preprocessor: _preprocessor,
      embedder: _embedder,
    );
  }

  void _logCacheDiagnostics(List<FaceEmbeddingRecord> roster) {
    for (var i = 0; i < roster.length && i < 3; i++) {
      final row = roster[i];
      var normSq = 0.0;
      for (final v in row.embedding) {
        normSq += v * v;
      }
      debugPrint(
        'FaceRecognition: cache[$i] emp=${row.employeeId} '
        'dim=${row.embedding.length} normSq=${normSq.toStringAsFixed(4)} '
        'pose=${row.pose}',
      );
    }
  }

  /// E.3 — compare live capture embedding to one employee's cached templates.
  Future<FaceE3VerificationReport?> verifyCaptureAgainstEmployee({
    required String imagePath,
    required Rect faceBox,
    required int employeeId,
    TimesheetFaceLandmarkSnapshot? landmarks,
  }) async {
    if (!_syncReady) return null;
    try {
      final preprocessSw = Stopwatch()..start();
      final tensor = await _preprocessor.buildInputTensorFromCaptureAsync(
        imagePath: imagePath,
        faceBox: faceBox,
        landmarks: landmarks,
      );
      final preprocessMs = preprocessSw.elapsedMilliseconds;
      if (tensor == null) return null;
      final embedSw = Stopwatch()..start();
      final embedding = await _embedder.generateEmbedding(tensor);
      final embedMs = embedSw.elapsedMilliseconds;
      if (kDebugMode) {
        _embedder.debugPrintEmbeddingHead(embedding, label: 'E.3 probe');
      }
      final roster = await _attendanceRoster();
      final perTemplate = _matcher.scoreTemplatesForEmployee(
        embedding,
        roster,
        employeeId,
      );
      if (perTemplate.isEmpty) return null;
      final top = perTemplate.first.score;
      final passes = top >= FaceRecognitionMatch.verificationMinCosine;
      return FaceE3VerificationReport(
        employeeId: employeeId,
        topScore: top,
        passesVerification: passes,
        templateScores:
            perTemplate.map((t) => (pose: t.pose, score: t.score)).toList(),
        preprocessMs: preprocessMs,
        embedMs: embedMs,
      );
    } catch (e, st) {
      debugPrint(
          'FaceRecognition.verifyCaptureAgainstEmployee failed: $e\n$st');
      return null;
    }
  }

  /// Enrollment-only: embeds every captured pose once, then scores each pose
  /// against the first photo (same person) and against the cached face DB
  /// excluding [employeeId] (duplicate). Returns null if the engine can't run,
  /// so enrollment is never blocked by a local model failure.
  Future<FaceEnrollmentCheckReport?> checkEnrollmentPhotos({
    required int employeeId,
    required List<
            ({
              String key,
              String imagePath,
              Rect faceBox,
              TimesheetFaceLandmarkSnapshot? landmarks,
            })>
        photos,
  }) async {
    if (photos.isEmpty) return null;
    try {
      await _embedder.ensureLoaded();
      final embeddings = <String, List<double>>{};
      for (final photo in photos) {
        final tensor = await _preprocessor.buildInputTensorFromCaptureAsync(
          imagePath: photo.imagePath,
          faceBox: photo.faceBox,
          landmarks: photo.landmarks,
        );
        if (tensor == null) continue;
        embeddings[photo.key] =
            _unit(await _embedder.generateEmbedding(tensor));
      }
      final reference = embeddings[photos.first.key];
      if (reference == null) return null;

      final samePerson = <String, double>{
        for (final e in embeddings.entries)
          if (e.key != photos.first.key) e.key: _dotUnit(reference, e.value),
      };

      final roster = (await _repository.loadCached())
          .where(
            (r) =>
                r.employeeId != employeeId &&
                r.embedding.length == FaceRecognitionModel.embeddingDim,
          )
          .toList();
      FaceEmbeddingRecord? dupRow;
      var dupScore = 0.0;
      if (roster.isNotEmpty && embeddings.isNotEmpty) {
        final unitRoster = [for (final r in roster) _unit(r.embedding)];
        final sums = <int, double>{};
        for (final probe in embeddings.values) {
          final perEmployee = <int, double>{};
          for (var i = 0; i < roster.length; i++) {
            final id = roster[i].employeeId;
            final s = _dotUnit(probe, unitRoster[i]);
            if (s > (perEmployee[id] ?? -1)) perEmployee[id] = s;
          }
          perEmployee.forEach((id, s) => sums[id] = (sums[id] ?? 0) + s);
        }
        int? bestId;
        sums.forEach((id, sum) {
          final mean = sum / embeddings.length;
          if (mean > dupScore) {
            dupScore = mean;
            bestId = id;
          }
        });
        if (bestId != null) {
          dupRow = roster.firstWhere((r) => r.employeeId == bestId);
        }
      }

      debugPrint(
        'FaceEnrollCheck: emp=$employeeId samePerson='
        '${samePerson.map((k, v) => MapEntry(k, v.toStringAsFixed(3)))} '
        'dup=${dupRow?.employeeId} ${dupRow?.name} '
        'score=${dupScore.toStringAsFixed(3)} roster=${roster.length}',
      );
      return FaceEnrollmentCheckReport(
        samePersonScores: samePerson,
        duplicateOf: dupRow,
        duplicateScore: dupScore,
      );
    } catch (e, st) {
      debugPrint('FaceRecognition.checkEnrollmentPhotos failed: $e\n$st');
      return null;
    }
  }

  static List<double> _unit(List<double> v) {
    var sum = 0.0;
    for (final x in v) {
      sum += x * x;
    }
    final n = math.sqrt(sum);
    if (n < 1e-9) return v;
    return [for (final x in v) x / n];
  }

  static double _dotUnit(List<double> a, List<double> b) {
    final n = math.min(a.length, b.length);
    var s = 0.0;
    for (var i = 0; i < n; i++) {
      s += a[i] * b[i];
    }
    return s;
  }

  /// Dump pilot JSONL to app documents (debug builds).
  Future<String?> exportPilotMatchLogs() =>
      FacePilotLogStore.exportJsonlSnapshot();

  TimesheetOdooEmployee? employeeFromMatch(FaceMatchResult result) {
    final best = result.best;
    if (best == null) return null;
    return TimesheetOdooEmployee(
      id: best.employeeId,
      employeeId: best.employeeId,
      name: best.name,
      fileId: best.empCode,
      department: best.department,
      jobPosition: best.jobTitle,
      hasProfileImage: true,
    );
  }
}
