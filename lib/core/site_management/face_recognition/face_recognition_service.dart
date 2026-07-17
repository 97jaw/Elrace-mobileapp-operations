import 'dart:ui';

import 'package:el_race/core/site_management/face_recognition/data/models/face_e3_verification_report.dart';
import 'package:el_race/core/site_management/face_recognition/data/models/face_embedding_record.dart';
import 'package:el_race/core/site_management/face_recognition/data/models/face_match_result.dart';
import 'package:el_race/core/site_management/face_recognition/face_pilot_log_store.dart';
import 'package:el_race/core/site_management/face_recognition/data/repositories/face_db_repository.dart';
import 'package:el_race/core/site_management/face_recognition/domain/face_embedder.dart';
import 'package:el_race/core/site_management/face_recognition/domain/face_matcher.dart';
import 'package:el_race/core/site_management/face_recognition/domain/face_preprocessor.dart';
import 'package:el_race/core/site_management/face_recognition/face_match_logger.dart';
import 'package:el_race/core/site_management/face_recognition/face_recognition_availability.dart';
import 'package:el_race/core/site_management/face_recognition/face_recognition_config.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';
import 'package:el_race/core/timesheet/services/face_capture_service.dart';
import 'package:flutter/foundation.dart';

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
  FaceSyncResult? _lastSync;

  FaceSyncResult? get lastSync => _lastSync;
  bool get isReady => _syncReady;

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
    if (_syncReady) {
      try {
        await _embedder.ensureLoaded();
        _engineReady = true;
      } catch (e) {
        debugPrint('FaceRecognition: TFLite preload failed: $e');
        _syncReady = false;
        _engineReady = false;
        _engineLoadFailed = true;
      }
    }
    return result;
  }

  /// Full re-download of face DB (use when Odoo enrollment changed outside the app).
  Future<FaceSyncResult> syncFaceDbForceRefresh() async {
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
    if (_syncReady) {
      try {
        await _embedder.ensureLoaded();
        _engineReady = true;
      } catch (e) {
        debugPrint('FaceRecognition: TFLite preload failed: $e');
        _syncReady = false;
        _engineReady = false;
        _engineLoadFailed = true;
      }
    }
    return result;
  }

  /// Match capture photo against cached face DB. Returns null if sync/engine not ready.
  Future<FaceMatchResult?> matchCapturePhoto({
    required String imagePath,
    required Rect faceBox,
    TimesheetFaceLandmarkSnapshot? landmarks,
  }) async {
    if (!_syncReady) return null;
    try {
      final totalSw = Stopwatch()..start();
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
      final embedSw = Stopwatch()..start();
      final embedding = await _embedder.generateEmbedding(tensor);
      final embedMs = embedSw.elapsedMilliseconds;
      var probeNormSq = 0.0;
      for (final v in embedding) {
        probeNormSq += v * v;
      }
      final roster = await _repository.loadCached();
      if (roster.isEmpty) return FaceMatchResult.none;
      _logCacheDiagnostics(roster);
      final matchSw = Stopwatch()..start();
      final result = _matcher.findBestMatch(embedding, roster);
      final matchMs = matchSw.elapsedMilliseconds;
      final totalMs = totalSw.elapsedMilliseconds;
      final best = result.best;
      if (best != null && kDebugMode) {
        final perTemplate = _matcher.scoreTemplatesForEmployee(
          embedding,
          roster,
          best.employeeId,
        );
        FaceMatchLogger.logTemplateScores(
          employeeId: best.employeeId,
          scores: perTemplate
              .map((t) => (pose: t.pose, score: t.score))
              .toList(),
        );
        final e3Pass = perTemplate.isNotEmpty &&
            perTemplate.first.score >=
                FaceRecognitionMatch.verificationMinCosine;
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
        matchedAtProductionThreshold: result.isMatch,
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
        'match=${result.isMatch} '
        'emp=${best?.employeeId} ${best?.name} '
        'timing=pre${preprocessMs}+emb${embedMs}+mat${matchMs}=${totalMs}ms',
      );
      return result;
    } catch (e, st) {
      debugPrint('FaceRecognition.matchCapturePhoto failed: $e\n$st');
      return null;
    }
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
      final roster = await _repository.loadCached();
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
        templateScores: perTemplate
            .map((t) => (pose: t.pose, score: t.score))
            .toList(),
        preprocessMs: preprocessMs,
        embedMs: embedMs,
      );
    } catch (e, st) {
      debugPrint('FaceRecognition.verifyCaptureAgainstEmployee failed: $e\n$st');
      return null;
    }
  }

  /// Dump pilot JSONL to app documents (debug builds).
  Future<String?> exportPilotMatchLogs() => FacePilotLogStore.exportJsonlSnapshot();

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
