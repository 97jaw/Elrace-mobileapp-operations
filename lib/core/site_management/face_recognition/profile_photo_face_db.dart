import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:el_race/core/site_management/face_recognition/data/models/face_embedding_record.dart';
import 'package:el_race/core/site_management/face_recognition/domain/face_embedder.dart';
import 'package:el_race/core/site_management/face_recognition/domain/face_preprocessor.dart';
import 'package:el_race/core/timesheet/models/timesheet_team_member.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';
import 'package:el_race/core/timesheet/services/face_capture_service.dart';
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
  static const String _pipelineVersion = 'mobilefacenet512-profile-v2';
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

  /// Capture screens: project labour narrowed to Your Team. Kept as-is when
  /// the full team is already loaded, so the sheet underneath keeps its icon
  /// states.
  void setLabour(List<TimesheetOdooEmployee> labour) {
    _setRoster(keepIfCovered: true, [
      for (final e in labour)
        if (e.canUseFaceMatch)
          _Member(
            id: e.employeeId,
            name: e.name,
            fileId: e.displayFileId,
            department: e.department ?? '',
            jobTitle: e.jobPosition ?? '',
            url: e.faceMatchImageUrl!,
          ),
    ]);
  }

  /// Dashboard / Your Team sheet.
  void setTeam(List<TimesheetTeamMember> team) {
    _setRoster([
      for (final m in team)
        _Member(
          id: m.employeeId,
          name: m.name,
          fileId: m.fileId,
          department: '',
          jobTitle: m.subtitle ?? '',
          url: '$kTimesheetErpPublicBase/public/employee/image/${m.employeeId}',
        ),
    ]);
  }

  void _setRoster(List<_Member> members, {bool keepIfCovered = false}) {
    final covered = members.every((m) => _members.containsKey(m.id));
    if (covered && (keepIfCovered || members.length == _members.length)) {
      return;
    }
    _members
      ..clear()
      ..addEntries(members.map((m) => MapEntry(m.id, m)));
    debugPrint(
      'ProfilePhotoMatch: labour roster set ${_members.length} employees',
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

  /// Ready templates for the current roster. Never waits for the build: a
  /// labour without a template yet simply can't be matched.
  Future<List<FaceEmbeddingRecord>> rows() async {
    await _ensureCacheLoaded();
    if (_members.isEmpty) {
      debugPrint('ProfilePhotoMatch: no labour roster yet — 0 templates');
      return const [];
    }
    return [
      for (final m in _members.values)
        if (_templates[m.id]?.embedding != null)
          FaceEmbeddingRecord(
            employeeId: m.id,
            empCode: m.fileId,
            name: m.name,
            department: m.department,
            jobTitle: m.jobTitle,
            inForemanTeam: true,
            pose: 'profile_photo',
            embedding: _templates[m.id]!.embedding!,
          ),
    ];
  }

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

  void _publish() {
    states.value = {
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
    var noFace = 0;
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
        for (var i = 0; i < batch.length; i++) {
          final member = batch[i];
          final bytes = photos[i];
          _Template template;
          if (bytes == null) {
            template = _Template.failed('noPhoto');
            noPhoto++;
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
          _inFlight.remove(member.id);
          built.add(member.id);
          debugPrint(
            'ProfilePhotoMatch: emp=${member.id} ${member.name} '
            '${template.status}',
          );
          _publish();
        }
        await _save();
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
      'ok=$ok noPhoto=$noPhoto noFace=$noFace in ${sw.elapsedMilliseconds}ms',
    );
    _logQualityReport(built);
    if (_queue.isNotEmpty) unawaited(_run());
  }

  Future<Uint8List?> _download(_Member member) async {
    try {
      final response = await http
          .get(Uri.parse(member.url))
          .timeout(const Duration(seconds: 15));
      final type = response.headers['content-type'] ?? '';
      if (response.statusCode != 200 ||
          response.bodyBytes.isEmpty ||
          !type.startsWith('image/') ||
          type.contains('svg')) {
        return null;
      }
      return response.bodyBytes;
    } catch (e) {
      debugPrint('ProfilePhotoMatch: emp=${member.id} download failed: $e');
      return null;
    }
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
      final tensor = await _preprocessor.buildInputTensorFromCaptureAsync(
        imagePath: file.path,
        faceBox: face.boundingBox,
        landmarks: face,
      );
      if (tensor == null) {
        debugPrint(
          'ProfilePhotoMatch: emp=$employeeId crop failed '
          'box=${face.boundingBox} eyes=${face.leftEye}/${face.rightEye} '
          'faces=${detection.faceCount}',
        );
        return null;
      }
      return _Template(
        embedding: _unit(await _embedder.generateEmbedding(tensor)),
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
        debugPrint('ProfilePhotoMatch: saved templates outdated — rebuilding');
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
    required this.url,
  });

  final int id;
  final String name;
  final String fileId;
  final String department;
  final String jobTitle;
  final String url;
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

  /// ok | noPhoto | noFace
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

typedef _PreparedPhoto = ({
  Uint8List jpg,
  int sourceWidth,
  int sourceHeight,
  double scale,
});
