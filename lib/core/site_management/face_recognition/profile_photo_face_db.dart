import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:el_race/core/site_management/face_recognition/data/models/face_embedding_record.dart';
import 'package:el_race/core/site_management/face_recognition/domain/face_embedder.dart';
import 'package:el_race/core/site_management/face_recognition/domain/face_preprocessor.dart';
import 'package:el_race/core/site_management/face_recognition/face_recognition_config.dart';
import 'package:el_race/core/timesheet/models/timesheet_team_member.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';
import 'package:el_race/core/timesheet/services/face_capture_service.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// TEST ONLY (feature/profile-photo-matching): attendance ignores the
/// enrollment face DB (0 templates used) and matches against one template per
/// Your Team labour built on device from the Odoo profile photo. Thresholds
/// and screens unchanged. `--dart-define=PROFILE_PHOTO_MATCH=false` restores
/// the enrollment behaviour.
abstract final class ProfilePhotoMatchTest {
  static const bool enabled =
      bool.fromEnvironment('PROFILE_PHOTO_MATCH', defaultValue: true);
}

/// Per-labour template availability, drives the Your Team capture icons.
enum ProfileTemplateState { pending, ready, failed }

/// Profile-photo templates for the current roster. Built in the background
/// (one queue, Your Team order, tapped labour jumps the queue) and saved on
/// the phone so later app starts only rebuild new or stale entries.
class ProfilePhotoFaceDb {
  ProfilePhotoFaceDb._();

  static final ProfilePhotoFaceDb instance = ProfilePhotoFaceDb._();

  static const int _parallelDownloads = 4;

  /// Bump when the build pipeline changes so old saved templates are rebuilt.
  /// v2.1: every template records its source face width (LOW_RES flag).
  /// v3: 5-point ArcFace aligned crop (`useFivePointAlignment`).
  static const String _pipelineVersion =
      FaceRecognitionPreprocess.useFivePointAlignment
          ? 'mobilefacenet512-profile-v3'
          : 'mobilefacenet512-profile-v2.1';

  /// Most members (targets + cohort) held for one capture screen.
  static const int maxMembers = 80;
  static const String _cacheFileName = 'profile_photo_templates.json';

  /// The photo URL has no change marker, so saved templates are refreshed
  /// periodically to pick up replaced photos.
  static const Duration _templateMaxAge = Duration(days: 7);
  static const Duration _failedRetryAfter = Duration(days: 1);

  static const int _maxPhotoLongSidePx = 800;
  static const int _minPhotoShortSidePx = 480;

  final FacePreprocessor _preprocessor = const FacePreprocessor();
  final FaceEmbedder _embedder = FaceEmbedder.instance;

  /// Current roster in display order.
  final Map<int, _Member> _members = {};
  final Map<int, _Template> _templates = {};
  final List<int> _queue = [];
  final Set<int> _inFlight = {};

  bool _running = false;
  Future<void>? _cacheLoad;

  final ValueNotifier<Map<int, ProfileTemplateState>> states =
      ValueNotifier(const {});

  /// Employee ids of the last [setTeam] (dashboard / Your Team sheet).
  Set<int> _teamIds = const {};

  /// Capture screens. [targetIds] are the labours that can be verified or
  /// matched (Your Team); the rest of [labour] is cohort only (never matched
  /// or named). Null [targetIds] = every labour is a target. Team members
  /// already loaded by [setTeam] stay as targets, so the sheet underneath
  /// keeps its icon states. Targets are built first; the total is capped at
  /// [maxMembers] (targets always kept). Kept as-is when the current roster
  /// already covers it with the same roles.
  void setLabour(List<TimesheetOdooEmployee> labour, {Set<int>? targetIds}) {
    bool isTarget(TimesheetOdooEmployee e) =>
        targetIds == null || targetIds.contains(e.employeeId);
    final usable = [
      for (final e in labour)
        if (e.canUseFaceMatch) e
    ];
    final labourIds = {for (final e in usable) e.employeeId};
    final targets = [
      for (final e in usable)
        if (isTarget(e)) e
    ];
    final cohort = [
      for (final e in usable)
        if (!isTarget(e)) e
    ];
    final keptTeam = [
      for (final m in _members.values)
        if (m.target && _teamIds.contains(m.id) && !labourIds.contains(m.id)) m,
    ];
    final room = math.max(0, maxMembers - targets.length - keptTeam.length);
    _setRoster(keepIfCovered: true, [
      for (final e in targets) _Member.fromEmployee(e, target: true),
      ...keptTeam,
      for (final e in cohort.take(room)) _Member.fromEmployee(e, target: false),
    ]);
  }

  /// Dashboard / Your Team sheet. No-op while the roster already holds this
  /// team as targets (a capture screen's cohort is kept).
  void setTeam(List<TimesheetTeamMember> team) {
    _teamIds = {for (final m in team) m.employeeId};
    _setRoster([
      for (final m in team)
        _Member(
          id: m.employeeId,
          name: m.name,
          fileId: m.fileId,
          department: '',
          jobTitle: m.subtitle ?? '',
          target: true,
        ),
    ]);
  }

  void _setRoster(List<_Member> members, {bool keepIfCovered = false}) {
    final covered = members.every((m) => _members[m.id]?.target == m.target);
    final currentTargets = _members.values.where((m) => m.target).length;
    if (covered && (keepIfCovered || members.length == currentTargets)) {
      return;
    }
    _members
      ..clear()
      ..addEntries(members.map((m) => MapEntry(m.id, m)));
    _invalidateWalkUpRoster();
    final targets = _members.values.where((m) => m.target).length;
    debugPrint(
      'ProfilePhotoMatch: labour roster set ${_members.length} employees '
      '(targets=$targets cohort=${_members.length - targets})',
    );
    unawaited(_refresh(retryFailed: false));
  }

  /// Your Team reload: also retries labours whose photo failed (HR may have
  /// replaced it).
  Future<void> retryFailed() => _refresh(retryFailed: true);

  /// Tapped labour whose template is still pending goes next.
  void prioritize(int employeeId) {
    if (!_queue.remove(employeeId)) return;
    _queue.insert(0, employeeId);
    debugPrint('ProfilePhotoMatch: emp=$employeeId moved to front');
  }

  ProfileTemplateState stateOf(int employeeId) =>
      states.value[employeeId] ?? ProfileTemplateState.pending;

  bool hasTemplateFor(int employeeId) =>
      _templates[employeeId]?.embedding != null;

  /// LOW_RES: face narrower than [_lowResFacePx] in the source photo. An
  /// unknown width (0, templates saved before v2.1) also counts as low-res.
  bool isLowRes(int employeeId) {
    final t = _templates[employeeId];
    return t != null && _isLowRes(t);
  }

  static bool _isLowRes(_Template t) => t.faceSourcePx < _lowResFacePx;

  /// Look-alike: cosine ≥ [_lookAlikeCosine] to another ready template.
  bool isLookAlike(int employeeId) {
    final emb = _templates[employeeId]?.embedding;
    if (emb == null) return false;
    for (final other in _templates.entries) {
      if (other.key == employeeId || other.value.embedding == null) continue;
      if (_dot(emb, other.value.embedding!) >= _lookAlikeCosine) return true;
    }
    return false;
  }

  /// Cached once per roster/template generation for walk-up frames (TASK 10).
  WalkUpRosterSnapshot? _walkUpRoster;

  void _invalidateWalkUpRoster() => _walkUpRoster = null;

  /// Candidates + excluded ids for the current roster/templates. Logs once
  /// per rebuild: `WalkUp: candidates=… excluded_low_res=… excluded_lookalike=…`.
  Future<WalkUpRosterSnapshot> walkUpRoster() async {
    await _ensureCacheLoaded();
    final cached = _walkUpRoster;
    if (cached != null) return cached;

    final candidates = <int>[];
    final lowRes = <int>[];
    final lookAlike = <int>[];
    for (final m in _members.values) {
      if (!m.target || _templates[m.id]?.embedding == null) continue;
      final t = _templates[m.id]!;
      final isLow = _isLowRes(t);
      final isAlike = isLookAlike(m.id);
      if (isLow) lowRes.add(m.id);
      if (isAlike) lookAlike.add(m.id);
      if (!isLow && !isAlike) candidates.add(m.id);
    }
    final snap = WalkUpRosterSnapshot(
      candidateIds: candidates.toSet(),
      excludedLowRes: lowRes.toSet(),
      excludedLookAlike: lookAlike.toSet(),
    );
    _walkUpRoster = snap;
    debugPrint(
      'WalkUp: candidates=$candidates '
      'excluded_low_res=$lowRes '
      'excluded_lookalike=$lookAlike',
    );
    return snap;
  }

  /// Your Team targets with a ready template that are neither LOW_RES nor
  /// look-alike — walk-up auto-id candidates (TASK 10 §3).
  Future<List<int>> walkUpCandidateIds() async =>
      (await walkUpRoster()).candidateIds.toList(growable: false);

  Future<({List<int> lowRes, List<int> lookAlike})> walkUpExcludedIds() async {
    final r = await walkUpRoster();
    return (
      lowRes: r.excludedLowRes.toList(growable: false),
      lookAlike: r.excludedLookAlike.toList(growable: false),
    );
  }

  /// Ready templates of the verification targets (Your Team) only — the 1:N
  /// matcher never sees cohort-only members. Never waits for the build: a
  /// labour without a template yet simply can't be matched.
  Future<List<FaceEmbeddingRecord>> rows() async {
    await _ensureCacheLoaded();
    if (_members.isEmpty) {
      debugPrint('ProfilePhotoMatch: no labour roster yet — 0 templates');
      return const [];
    }
    return [
      for (final m in _members.values)
        if (m.target && _templates[m.id]?.embedding != null) _record(m),
    ];
  }

  /// Template of one roster member (target or cohort), or null when none is
  /// ready. LOW_RES templates are still returned: they stay usable as the
  /// verification target.
  Future<FaceEmbeddingRecord?> templateFor(int employeeId) async {
    await _ensureCacheLoaded();
    final m = _members[employeeId];
    if (m == null || _templates[m.id]?.embedding == null) return null;
    return _record(m);
  }

  /// Every other roster member with a ready template (targets and cohort),
  /// each with its LOW_RES flag. [excludeEmployeeId] is never included.
  Future<List<({FaceEmbeddingRecord row, bool lowRes})>> cohortCandidates({
    required int excludeEmployeeId,
  }) async {
    await _ensureCacheLoaded();
    return [
      for (final m in _members.values)
        if (m.id != excludeEmployeeId && _templates[m.id]?.embedding != null)
          (row: _record(m), lowRes: _isLowRes(_templates[m.id]!)),
    ];
  }

  FaceEmbeddingRecord _record(_Member m) => FaceEmbeddingRecord(
        employeeId: m.id,
        empCode: m.fileId,
        name: m.name,
        department: m.department,
        jobTitle: m.jobTitle,
        inForemanTeam: m.target,
        pose: 'profile_photo',
        embedding: _templates[m.id]!.embedding!,
      );

  /// Project labour narrowed to the foreman's assigned labour (Your Team).
  /// Falls back to the whole project list when the login has no team (PM).
  static List<TimesheetOdooEmployee> yourTeamOnly(
    List<TimesheetOdooEmployee> projectLabour,
    List<TimesheetTeamMember> team,
  ) {
    if (team.isEmpty) {
      debugPrint(
        'ProfilePhotoMatch: no Your Team list — using all '
        '${projectLabour.length} project labour',
      );
      return projectLabour;
    }
    final teamIds = {for (final m in team) m.employeeId};
    final mine =
        projectLabour.where((e) => teamIds.contains(e.employeeId)).toList();
    debugPrint(
      'ProfilePhotoMatch: Your Team ${team.length} → ${mine.length} of '
      '${projectLabour.length} project labour used',
    );
    return mine;
  }

  Future<void> _refresh({required bool retryFailed}) async {
    await _ensureCacheLoaded();
    final now = DateTime.now();
    var cached = 0;
    for (final m in _members.values) {
      if (_queue.contains(m.id) || _inFlight.contains(m.id)) continue;
      final t = _templates[m.id];
      final stale = t == null ||
          (t.embedding != null &&
              now.difference(t.builtAt) > _templateMaxAge) ||
          (t.embedding == null &&
              (retryFailed || now.difference(t.builtAt) > _failedRetryAfter));
      if (stale) {
        _queue.add(m.id);
      } else {
        cached++;
      }
    }
    debugPrint(
      'ProfilePhotoMatch: ${_members.length} employees — saved=$cached '
      'to build=${_queue.length}',
    );
    _publish();
    unawaited(_run());
  }

  /// Roster members plus any other saved template (e.g. Your Team labours not
  /// on the current project), so the team sheet keeps its icons.
  void _publish() {
    states.value = {
      for (final e in _templates.entries)
        e.key: e.value.embedding != null
            ? ProfileTemplateState.ready
            : ProfileTemplateState.failed,
      for (final m in _members.values)
        m.id: _templates[m.id]?.embedding != null
            ? ProfileTemplateState.ready
            : _templates[m.id] != null &&
                    !_queue.contains(m.id) &&
                    !_inFlight.contains(m.id)
                ? ProfileTemplateState.failed
                : ProfileTemplateState.pending,
    };
  }

  Future<void> _run() async {
    if (_running || _queue.isEmpty) return;
    _running = true;
    final sw = Stopwatch()..start();
    final capture = TimesheetFaceCaptureService();
    final dir = await getTemporaryDirectory();
    final built = <int>[];
    var ok = 0;
    var noPhoto = 0;
    var noAccess = 0;
    var noFace = 0;
    debugPrint('ProfilePhotoMatch: photos via ${_Member.faceImagePath}<id>');
    try {
      await _embedder.ensureLoaded();
      while (_queue.isNotEmpty) {
        final batch = <_Member>[];
        while (batch.length < _parallelDownloads && _queue.isNotEmpty) {
          final member = _members[_queue.removeAt(0)];
          if (member != null) batch.add(member);
        }
        _inFlight.addAll(batch.map((m) => m.id));
        final photos = await Future.wait(batch.map(_download));
        var unauthorized = false;
        for (var i = 0; i < batch.length; i++) {
          final member = batch[i];
          final photo = photos[i];
          final bytes = photo.bytes;
          if (photo.status == _unauthorized) {
            // No template written: the labour stays pending, not failed.
            _inFlight.remove(member.id);
            unauthorized = true;
            continue;
          }
          _Template template;
          if (bytes == null) {
            template = _Template.failed(photo.status);
            photo.status == 'noAccess' ? noAccess++ : noPhoto++;
          } else {
            template = await _embed(member.id, bytes, dir, capture) ??
                _Template.failed('noFace');
            template.embedding == null ? noFace++ : ok++;
          }
          final previous = _templates[member.id];
          // A refresh that fails keeps a still-usable older template.
          _templates[member.id] =
              template.embedding == null && previous?.embedding != null
                  ? previous!.touched()
                  : template;
          _invalidateWalkUpRoster();
          _inFlight.remove(member.id);
          built.add(member.id);
          debugPrint(
            'ProfilePhotoMatch: emp=${member.id} ${member.name} '
            '${member.target ? 'target' : 'cohort'} ${template.status}',
          );
          _publish();
        }
        await _save();
        if (unauthorized) {
          debugPrint(
            'ProfilePhotoMatch: photo route 401 after retry — build stopped, '
            '${_queue.length} more left pending',
          );
          _queue.clear();
          break;
        }
      }
    } catch (e) {
      debugPrint('ProfilePhotoMatch: build stopped: $e');
    } finally {
      _inFlight.clear();
      _running = false;
      _publish();
      await capture.dispose();
    }
    debugPrint(
      'ProfilePhotoMatch: built ${built.length} employees '
      'ok=$ok noPhoto=$noPhoto noAccess=$noAccess noFace=$noFace '
      'in ${sw.elapsedMilliseconds}ms',
    );
    _logQualityReport(built);
    if (_queue.isNotEmpty) unawaited(_run());
  }

  static const String _unauthorized = 'unauthorized';

  /// Photo bytes with status `ok`, or null bytes with `noPhoto` (404 /
  /// unusable / network), `noAccess` (403) or [_unauthorized] (401 twice).
  Future<({Uint8List? bytes, String status})> _download(_Member member) async {
    try {
      var response = await _getPhoto(member);
      if (response.statusCode == 401) {
        debugPrint(
          'ProfilePhotoMatch: emp=${member.id} 401 — retrying with stored token',
        );
        response = await _getPhoto(member);
      }
      switch (response.statusCode) {
        case 401:
          return (bytes: null, status: _unauthorized);
        case 403:
          debugPrint('ProfilePhotoMatch: emp=${member.id} no access (403)');
          return (bytes: null, status: 'noAccess');
        case 404:
          return (bytes: null, status: 'noPhoto');
      }
      final type = response.headers['content-type'] ?? '';
      if (response.statusCode != 200 ||
          response.bodyBytes.isEmpty ||
          !type.startsWith('image/') ||
          type.contains('svg')) {
        return (bytes: null, status: 'noPhoto');
      }
      return (bytes: response.bodyBytes, status: 'ok');
    } catch (e) {
      debugPrint('ProfilePhotoMatch: emp=${member.id} download failed: $e');
      return (bytes: null, status: 'noPhoto');
    }
  }

  /// Token is read from login storage on every call, so a retry picks up a
  /// token replaced by a re-login.
  Future<http.Response> _getPhoto(_Member member) {
    final token = SharedPref.getLoginData().result?.token;
    return http.get(
      Uri.parse(member.url),
      headers: {
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 15));
  }

  Future<_Template?> _embed(
    int employeeId,
    Uint8List bytes,
    Directory dir,
    TimesheetFaceCaptureService capture,
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
        alreadyNormalized: true,
      );
      final face = detection.primaryFace;
      if (face == null) {
        debugPrint(
          'ProfilePhotoMatch: emp=$employeeId detector found no face '
          'faces=${detection.faceCount}',
        );
        return null;
      }
      final chip = await _preprocessor.buildInputTensorFromCaptureAsync(
        imagePath: file.path,
        faceBox: face.boundingBox,
        landmarks: face,
        crop: FaceChipCrop.fivePoint,
      );
      if (chip == null) {
        debugPrint(
          'ProfilePhotoMatch: emp=$employeeId crop failed '
          'box=${face.boundingBox} eyes=${face.leftEye}/${face.rightEye} '
          'faces=${detection.faceCount}',
        );
        return null;
      }
      debugPrint(
        'ProfilePhotoMatch: emp=$employeeId template built '
        'align=${chip.align.logName} version=$_pipelineVersion',
      );
      return _Template(
        embedding: _unit(await _embedder.generateEmbedding(chip.tensor)),
        builtAt: DateTime.now(),
        status: 'ok',
        sourceWidth: prepared.sourceWidth,
        sourceHeight: prepared.sourceHeight,
        faceSourcePx: (face.boundingBox.width / prepared.scale).round(),
      );
    } catch (e) {
      debugPrint('ProfilePhotoMatch: emp=$employeeId embed failed: $e');
      return null;
    }
  }

  Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_cacheFileName');
  }

  Future<void> _ensureCacheLoaded() => _cacheLoad ??= _loadCache();

  Future<void> _loadCache() async {
    try {
      final file = await _cacheFile();
      if (!await file.exists()) return;
      final json = jsonDecode(await file.readAsString());
      if (json is! Map || json['version'] != _pipelineVersion) {
        debugPrint(
          'ProfilePhotoMatch: saved templates outdated '
          '(${json is Map ? json['version'] : 'n/a'} → $_pipelineVersion) '
          '— rebuilding',
        );
        return;
      }
      final entries = json['templates'];
      if (entries is! Map) return;
      for (final entry in entries.entries) {
        final id = int.tryParse('${entry.key}');
        final t = _Template.fromJson(entry.value);
        if (id != null && t != null) _templates[id] = t;
      }
      debugPrint(
        'ProfilePhotoMatch: loaded ${_templates.length} saved templates',
      );
    } catch (e) {
      debugPrint('ProfilePhotoMatch: saved templates unreadable: $e');
    }
  }

  Future<void> _save() async {
    try {
      final file = await _cacheFile();
      await file.writeAsString(jsonEncode({
        'version': _pipelineVersion,
        'templates': {
          for (final e in _templates.entries) '${e.key}': e.value.toJson(),
        },
      }));
    } catch (e) {
      debugPrint('ProfilePhotoMatch: saving templates failed: $e');
    }
  }

  /// HR photos are often 128 px thumbnails or transparent PNGs cropped tight
  /// to the head; the detector needs a mid-size, opaque image with margin.
  static _PreparedPhoto? _prepareProfilePhoto(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    var photo = img.bakeOrientation(decoded);
    final sourceWidth = photo.width;
    final sourceHeight = photo.height;
    var scale = 1.0;
    final longSide = math.max(photo.width, photo.height);
    final shortSide = math.min(photo.width, photo.height);
    if (longSide > _maxPhotoLongSidePx) {
      scale = _maxPhotoLongSidePx / longSide;
    } else if (shortSide < _minPhotoShortSidePx) {
      scale = _minPhotoShortSidePx / shortSide;
    }
    if (scale != 1.0) {
      photo = img.copyResize(
        photo,
        width: (photo.width * scale).round(),
        height: (photo.height * scale).round(),
        interpolation:
            scale > 1 ? img.Interpolation.cubic : img.Interpolation.average,
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

  /// Face narrower than this in the original upload is upscaled guesswork.
  static const int _lowResFacePx = 90;

  /// Two different employees' photos closer than this are easily confused.
  static const double _lookAlikeCosine = 0.45;

  /// One line per newly built template, worst first, so HR knows which
  /// photos to replace.
  void _logQualityReport(List<int> builtIds) {
    final ready = [
      for (final m in _members.values)
        if (_templates[m.id]?.embedding != null) m.id,
    ];
    final lines = <({int rank, String text})>[];
    var good = 0;
    var lowRes = 0;
    var lookAlike = 0;
    for (final id in builtIds) {
      final t = _templates[id];
      final emb = t?.embedding;
      if (t == null || emb == null) continue;
      var closestId = -1;
      var closest = -1.0;
      for (final other in ready) {
        if (other == id) continue;
        final score = _dot(emb, _templates[other]!.embedding!);
        if (score > closest) {
          closest = score;
          closestId = other;
        }
      }
      final isLowRes = t.faceSourcePx < _lowResFacePx;
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
        text: 'ProfilePhotoQuality: $grade emp=$id ${_members[id]?.name ?? ''} '
            'photo=${t.sourceWidth}x${t.sourceHeight} '
            'face=${t.faceSourcePx}px closest=emp $closestId '
            '${_members[closestId]?.name ?? ''} ${closest.toStringAsFixed(3)}',
      ));
    }
    if (lines.isEmpty) return;
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

class _Member {
  const _Member({
    required this.id,
    required this.name,
    required this.fileId,
    required this.department,
    required this.jobTitle,
    required this.target,
  });

  _Member.fromEmployee(TimesheetOdooEmployee e, {required this.target})
      : id = e.employeeId,
        name = e.name,
        fileId = e.displayFileId,
        department = e.department ?? '',
        jobTitle = e.jobPosition ?? '';

  final int id;
  final String name;
  final String fileId;
  final String department;
  final String jobTitle;

  /// Authenticated face-matching photo route (avatars keep the public one).
  String get url => '$kTimesheetErpPublicBase$faceImagePath$id';

  static const String faceImagePath = '/api/v2/employee/face_image/';

  /// Verification / match target (Your Team); false = cohort only.
  final bool target;
}

class _Template {
  const _Template({
    required this.embedding,
    required this.builtAt,
    required this.status,
    this.sourceWidth = 0,
    this.sourceHeight = 0,
    this.faceSourcePx = 0,
  });

  _Template.failed(this.status)
      : embedding = null,
        builtAt = DateTime.now(),
        sourceWidth = 0,
        sourceHeight = 0,
        faceSourcePx = 0;

  final List<double>? embedding;
  final DateTime builtAt;

  /// ok | noPhoto | noAccess | noFace
  final String status;
  final int sourceWidth;
  final int sourceHeight;
  final int faceSourcePx;

  _Template touched() => _Template(
        embedding: embedding,
        builtAt: DateTime.now(),
        status: status,
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        faceSourcePx: faceSourcePx,
      );

  Map<String, Object?> toJson() => {
        'e': embedding == null
            ? null
            : base64Encode(
                Float32List.fromList(embedding!).buffer.asUint8List(),
              ),
        't': builtAt.millisecondsSinceEpoch,
        's': status,
        'w': sourceWidth,
        'h': sourceHeight,
        'f': faceSourcePx,
      };

  static _Template? fromJson(Object? json) {
    if (json is! Map) return null;
    final t = json['t'];
    if (t is! int) return null;
    final e = json['e'];
    List<double>? embedding;
    if (e is String) {
      final bytes = base64Decode(e);
      embedding = Float32List.view(
        bytes.buffer,
        bytes.offsetInBytes,
        bytes.lengthInBytes ~/ 4,
      ).toList();
    }
    return _Template(
      embedding: embedding,
      builtAt: DateTime.fromMillisecondsSinceEpoch(t),
      status: '${json['s'] ?? (embedding == null ? 'noFace' : 'ok')}',
      sourceWidth: (json['w'] as num?)?.toInt() ?? 0,
      sourceHeight: (json['h'] as num?)?.toInt() ?? 0,
      faceSourcePx: (json['f'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Walk-up candidate / exclusion sets for one roster+template generation.
class WalkUpRosterSnapshot {
  const WalkUpRosterSnapshot({
    required this.candidateIds,
    required this.excludedLowRes,
    required this.excludedLookAlike,
  });

  final Set<int> candidateIds;
  final Set<int> excludedLowRes;
  final Set<int> excludedLookAlike;

  Set<int> get excludedTeamIds => {...excludedLowRes, ...excludedLookAlike};
}

typedef _PreparedPhoto = ({
  Uint8List jpg,
  int sourceWidth,
  int sourceHeight,
  double scale,
});
