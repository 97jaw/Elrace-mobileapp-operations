import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
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
import 'package:el_race/core/site_management/face_recognition/domain/face_verifier.dart';
import 'package:el_race/core/site_management/face_recognition/domain/face_walkup.dart';
import 'package:el_race/core/site_management/face_recognition/face_match_logger.dart';
import 'package:el_race/core/site_management/face_recognition/face_recognition_availability.dart';
import 'package:el_race/core/site_management/face_recognition/face_recognition_config.dart';
import 'package:el_race/core/site_management/face_recognition/profile_photo_face_db.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';
import 'package:el_race/core/timesheet/services/face_capture_service.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

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

  /// Probe crop for [_attendanceRoster] / [_verifyTemplates]: aligned only
  /// when those templates are phone-built profile templates. Server and
  /// enrollment templates were built with the legacy crop.
  FaceChipCrop get _rosterCrop => ProfilePhotoMatchTest.enabled
      ? FaceChipCrop.fivePoint
      : FaceChipCrop.legacy;

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
      final chip = await _preprocessor.buildInputTensorFromCaptureAsync(
        imagePath: imagePath,
        faceBox: faceBox,
        landmarks: landmarks,
        crop: _rosterCrop,
      );
      final preprocessMs = preprocessSw.elapsedMilliseconds;
      if (chip == null) {
        debugPrint(
          'FaceRecognition: chip build failed path=$imagePath box=$faceBox',
        );
        return FaceMatchResult.none;
      }
      return _matchFromTensor(
        chip: chip,
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
      final chip = _preprocessor.buildInputTensorFromImage(
        source: source,
        faceBox: faceBox,
        landmarks: landmarks,
        crop: _rosterCrop,
      );
      final preprocessMs = preprocessSw.elapsedMilliseconds;
      if (chip == null) {
        debugPrint('FaceRecognition: chip build failed (memory) box=$faceBox');
        return FaceMatchResult.none;
      }
      return _matchFromTensor(
        chip: chip,
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
    required FaceChipTensor chip,
    required int preprocessMs,
    required String imagePath,
    int? focusEmployeeId,
  }) async {
    final align = chip.align.logName;
    final totalSw = Stopwatch()..start();
    final embedSw = Stopwatch()..start();
    final embedding = await _embedder.generateEmbedding(chip.tensor);
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
        'match=${result.isMatch} templates=${roster.length} (profile photos) '
        'align=$align',
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
      'emp=${best?.employeeId} ${best?.name} align=$align '
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
      'score=${focusScore?.toStringAsFixed(4) ?? 'no_templates'} align=$align',
    );
    return result.withFocusScore(focusScore);
  }

  /// 1:1 verify of [targetEmployeeId] on a still capture (file). Face width
  /// is checked against `FaceVerifyTuning.minFacePx`.
  Future<FaceVerifyResult> verifyCapturePhoto({
    required String imagePath,
    required Rect faceBox,
    required int targetEmployeeId,
    TimesheetFaceLandmarkSnapshot? landmarks,
  }) =>
      _verify(
        targetEmployeeId: targetEmployeeId,
        faceWidthPx: faceBox.width,
        imagePath: imagePath,
        buildTensor: () => _preprocessor.buildInputTensorFromCaptureAsync(
          imagePath: imagePath,
          faceBox: faceBox,
          landmarks: landmarks,
          crop: _rosterCrop,
        ),
      );

  /// 1:1 verify on an upright RGB live frame (no face-size check).
  Future<FaceVerifyResult> verifyImage({
    required img.Image source,
    required Rect faceBox,
    required int targetEmployeeId,
    TimesheetFaceLandmarkSnapshot? landmarks,
  }) =>
      _verify(
        targetEmployeeId: targetEmployeeId,
        faceWidthPx: null,
        imagePath: 'memory://camera_frame',
        buildTensor: () async => _preprocessor.buildInputTensorFromImage(
          source: source,
          faceBox: faceBox,
          landmarks: landmarks,
          crop: _rosterCrop,
        ),
      );

  /// Debug-only: one aligned 112×112 dump per camera open.
  static bool _debugAlignDumped = false;

  /// Call on every camera open so the next identify may dump once.
  static void resetDebugAlignDumpForCameraOpen() {
    _debugAlignDumped = false;
  }

  /// Walk-up identify on an upright RGB live frame (TASK 10 §3).
  ///
  /// [source] / [faceBox] / [landmarks] must share one coordinate space
  /// (full upright frame after [decodeCameraImageUpright]).
  Future<FaceWalkUpResult> identifyWalkUpImage({
    required img.Image source,
    required Rect faceBox,
    TimesheetFaceLandmarkSnapshot? landmarks,
  }) async {
    if (!_syncReady || !ProfilePhotoMatchTest.enabled) {
      debugPrint('WalkUp: no_result reason=not_ready');
      return FaceWalkUpResult.none;
    }
    final facePx = faceBox.width;
    if (facePx < 112) {
      debugPrint(
        'WalkUp: no_result reason=face_too_small face_px=${facePx.toStringAsFixed(0)} '
        'src=${source.width}x${source.height}',
      );
      return FaceWalkUpResult.none;
    }
    final built = _preprocessor.buildChip112FromImage(
      source,
      faceBox,
      landmarks: landmarks,
      crop: _rosterCrop,
    );
    if (built == null) {
      debugPrint(
        'WalkUp: no_result reason=no_embedding '
        'face_px=${facePx.toStringAsFixed(0)} '
        'src=${source.width}x${source.height} '
        'has_lm=${landmarks != null}',
      );
      return FaceWalkUpResult.none;
    }
    if (kDebugMode && !_debugAlignDumped) {
      _debugAlignDumped = true;
      unawaited(_dumpDebugAlignChip(built.chip));
    }
    final chip = FaceChipTensor(
      _preprocessor.buildInputTensorFromRgbChip(built.chip),
      built.align,
    );
    final probe = await _embedder.generateEmbedding(chip.tensor);
    if (probe.any((v) => v.isNaN || v.isInfinite)) {
      debugPrint('WalkUp: no_result reason=embed_nan');
      return FaceWalkUpResult.none;
    }

    final db = ProfilePhotoFaceDb.instance;
    // Candidates / exclusions cached per roster+template generation (not per frame).
    final roster = await db.walkUpRoster();
    if (roster.candidateIds.isEmpty) {
      debugPrint('WalkUp: no_result reason=no_candidates');
      return FaceWalkUpResult.none;
    }
    final cohort = await db.cohortCandidates(excludeEmployeeId: -1);
    final scores = <FaceWalkUpScore>[];
    for (final c in cohort) {
      final id = c.row.employeeId;
      final FaceWalkUpKind kind;
      if (roster.candidateIds.contains(id)) {
        kind = FaceWalkUpKind.candidate;
      } else if (roster.excludedTeamIds.contains(id)) {
        // Score look-alike Your Team so we can route to Pick labor.
        kind = FaceWalkUpKind.excludedTeam;
      } else if (c.lowRes) {
        // Project-labor LOW_RES stays out of the competitor pool.
        continue;
      } else {
        kind = FaceWalkUpKind.projectLabor;
      }
      scores.add(
        FaceWalkUpScore(
          employeeId: id,
          score: FaceVerifier.cosine(probe, c.row.embedding),
          kind: kind,
        ),
      );
    }
    for (final id in roster.candidateIds) {
      if (scores.any((s) => s.employeeId == id)) continue;
      final row = await db.templateFor(id);
      if (row == null) continue;
      scores.add(
        FaceWalkUpScore(
          employeeId: id,
          score: FaceVerifier.cosine(probe, row.embedding),
          kind: FaceWalkUpKind.candidate,
        ),
      );
    }

    final result = FaceWalkUp.decide(allScores: scores);
    if (!result.identified && result.winnerEmployeeId == null) {
      FaceWalkUpScore? best;
      for (final s in scores) {
        if (best == null || s.score > best.score) best = s;
      }
      final filter = best == null
          ? 'empty_scores'
          : 'winner_filtered(emp=${best.employeeId} '
              'score=${best.score.toStringAsFixed(3)} kind=${best.kind.name})';
      debugPrint('WalkUp: no_result reason=$filter');
    }
    debugPrint(
      'WalkUp: frame W=${result.winnerEmployeeId ?? '-'} '
      'score=${result.score?.toStringAsFixed(3) ?? '-'} '
      'lead=${result.lead?.toStringAsFixed(3) ?? '-'} '
      'second=${result.secondEmployeeId ?? '-'} '
      'second_score=${result.secondScore?.toStringAsFixed(3) ?? '-'} '
      'identified=${result.identified} outOfTeam=${result.outOfTeam} '
      'excludedTeam=${result.excludedTeamMember} '
      'face_px=${facePx.toStringAsFixed(0)} align=${chip.align.logName}',
    );
    return result;
  }

  /// Debug builds: first aligned 112×112 embedding input per camera open.
  static Future<void> _dumpDebugAlignChip(img.Image chip) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final path = '${dir.path}/debug_align_$ts.png';
      await File(path).writeAsBytes(img.encodePng(chip));
      debugPrint('WalkUp: debug_align saved $path');
    } catch (e) {
      debugPrint('WalkUp: debug_align save failed: $e');
    }
  }

  Future<FaceVerifyResult> _verify({
    required int targetEmployeeId,
    required double? faceWidthPx,
    required String imagePath,
    required Future<FaceChipTensor?> Function() buildTensor,
  }) async {
    final totalSw = Stopwatch()..start();
    var preprocessMs = 0;
    var embedMs = 0;
    var verifyMs = 0;
    FaceChipAlign? align;
    FaceVerifyResult result;
    try {
      if (!_syncReady) {
        result = FaceVerifyResult(
          outcome: FaceVerifyOutcome.error,
          targetEmployeeId: targetEmployeeId,
          faceWidthPx: faceWidthPx,
        );
      } else {
        final bars = FaceVerifyBars.current();
        final templates = await _verifyTemplates(targetEmployeeId);
        final early = FaceVerifier.precheck(
          targetEmployeeId: targetEmployeeId,
          hasTargetTemplate: templates.target.isNotEmpty,
          faceWidthPx: faceWidthPx,
          bars: bars,
        );
        if (early != null) {
          result = early;
        } else {
          final preprocessSw = Stopwatch()..start();
          final chip = await buildTensor();
          preprocessMs = preprocessSw.elapsedMilliseconds;
          if (chip == null) {
            debugPrint('FaceVerify: chip build failed path=$imagePath');
            result = FaceVerifyResult(
              outcome: FaceVerifyOutcome.error,
              targetEmployeeId: targetEmployeeId,
              faceWidthPx: faceWidthPx,
            );
          } else {
            align = chip.align;
            final embedSw = Stopwatch()..start();
            final probe = await _embedder.generateEmbedding(chip.tensor);
            embedMs = embedSw.elapsedMilliseconds;
            final verifySw = Stopwatch()..start();
            var t = -1.0;
            for (final e in templates.target) {
              t = math.max(t, FaceVerifier.cosine(probe, e));
            }
            result = FaceVerifier.decide(
              targetEmployeeId: targetEmployeeId,
              targetScore: t,
              cohort: [
                for (final c in templates.cohort)
                  FaceCohortScore(
                    employeeId: c.employeeId,
                    score: FaceVerifier.cosine(probe, c.embedding),
                    lowRes: c.lowRes,
                  ),
              ],
              bars: bars,
              faceWidthPx: faceWidthPx,
            );
            verifyMs = verifySw.elapsedMilliseconds;
          }
        }
      }
    } catch (e, st) {
      debugPrint('FaceRecognition.verify failed: $e\n$st');
      result = FaceVerifyResult(
        outcome: FaceVerifyOutcome.error,
        targetEmployeeId: targetEmployeeId,
        faceWidthPx: faceWidthPx,
      );
    }
    result = result.withTimings(
      preprocessMs: preprocessMs,
      embedMs: embedMs,
      verifyMs: verifyMs,
      totalMs: totalSw.elapsedMilliseconds,
    );
    _logVerify(result, imagePath, align);
    return result;
  }

  /// Target templates and cohort for a verify. Profile-photo mode: the
  /// roster's profile templates (cohort carries the LOW_RES flag). Enrollment
  /// mode: cached face DB rows, no LOW_RES flag.
  Future<
      ({
        List<List<double>> target,
        List<({int employeeId, List<double> embedding, bool lowRes})> cohort,
      })> _verifyTemplates(int targetEmployeeId) async {
    if (ProfilePhotoMatchTest.enabled) {
      final db = ProfilePhotoFaceDb.instance;
      final target = await db.templateFor(targetEmployeeId);
      final cohort =
          await db.cohortCandidates(excludeEmployeeId: targetEmployeeId);
      return (
        target: [if (target != null) target.embedding],
        cohort: [
          for (final c in cohort)
            (
              employeeId: c.row.employeeId,
              embedding: c.row.embedding,
              lowRes: c.lowRes,
            ),
        ],
      );
    }
    final rows = (await _repository.loadCached())
        .where((r) => r.embedding.length == FaceRecognitionModel.embeddingDim);
    return (
      target: [
        for (final r in rows)
          if (r.employeeId == targetEmployeeId) r.embedding,
      ],
      cohort: [
        for (final r in rows)
          if (r.employeeId != targetEmployeeId)
            (employeeId: r.employeeId, embedding: r.embedding, lowRes: false),
      ],
    );
  }

  void _logVerify(FaceVerifyResult r, String imagePath, FaceChipAlign? align) {
    String f(double? v) => v?.toStringAsFixed(4) ?? 'n/a';
    debugPrint(
      'FaceVerify: target=${r.targetEmployeeId} t=${f(r.targetScore)} '
      'cMax=${f(r.cohortMaxScore)} cMaxEmp=${r.cohortMaxEmployeeId} '
      'lead=${f(r.lead)} cohort=${r.cohortSize} '
      'noCohortBar=${r.usedNoCohortBar} facePx=${r.faceWidthPx?.round()} '
      'outcome=${r.outcome.name} align=${align?.logName ?? 'n/a'} '
      'timing=pre${r.preprocessMs}+emb${r.embedMs}+ver${r.verifyMs}'
      '=${r.totalMs}ms',
    );
    FacePilotLogStore.recordVerifyAttempt(
      targetEmployeeId: r.targetEmployeeId,
      outcome: r.outcome.name,
      targetScore: r.targetScore,
      cohortMaxScore: r.cohortMaxScore,
      cohortMaxEmployeeId: r.cohortMaxEmployeeId,
      lead: r.lead,
      cohortSize: r.cohortSize,
      usedNoCohortBar: r.usedNoCohortBar,
      faceWidthPx: r.faceWidthPx,
      preprocessMs: r.preprocessMs,
      embedMs: r.embedMs,
      verifyMs: r.verifyMs,
      totalMs: r.totalMs,
      imagePath: imagePath,
    );
  }

  /// Full re-download when [employeeId] (e.g. just enrolled) has no templates
  /// in the local cache yet. Returns true once templates are present.
  Future<bool> ensureTemplatesFor(int employeeId) async {
    if (ProfilePhotoMatchTest.enabled) {
      // Never wait for the photo build here: the capture screen loads its
      // project labour list only after this returns.
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
    return ProfilePhotoFaceDb.instance.rows();
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
      final chip = await _preprocessor.buildInputTensorFromCaptureAsync(
        imagePath: imagePath,
        faceBox: faceBox,
        landmarks: landmarks,
        crop: _rosterCrop,
      );
      final preprocessMs = preprocessSw.elapsedMilliseconds;
      if (chip == null) return null;
      final embedSw = Stopwatch()..start();
      final embedding = await _embedder.generateEmbedding(chip.tensor);
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
      debugPrint(
        'FaceRecognition: E.3 emp=$employeeId top=${top.toStringAsFixed(4)} '
        'pass=$passes align=${chip.align.logName}',
      );
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
        // Compared with server enrollment templates: legacy crop only.
        final chip = await _preprocessor.buildInputTensorFromCaptureAsync(
          imagePath: photo.imagePath,
          faceBox: photo.faceBox,
          landmarks: photo.landmarks,
          crop: FaceChipCrop.legacy,
        );
        if (chip == null) continue;
        embeddings[photo.key] =
            _unit(await _embedder.generateEmbedding(chip.tensor));
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
