import 'package:el_race/core/site_management/face_recognition/data/api/face_db_api.dart';
import 'package:flutter/foundation.dart';
import 'package:el_race/core/site_management/face_recognition/data/local/face_db_dao.dart';
import 'package:el_race/core/site_management/face_recognition/data/local/face_db_database.dart';
import 'package:el_race/core/site_management/face_recognition/data/models/face_embedding_record.dart';

enum FaceSyncStatus { upToDate, synced, failed, empty }

class FaceSyncResult {
  const FaceSyncResult._(this.status, {this.count = 0, this.message});

  final FaceSyncStatus status;
  final int count;
  final String? message;

  factory FaceSyncResult.upToDate({int count = 0}) =>
      FaceSyncResult._(FaceSyncStatus.upToDate, count: count);

  factory FaceSyncResult.synced(int count) =>
      FaceSyncResult._(FaceSyncStatus.synced, count: count);

  factory FaceSyncResult.failed(String message, {int count = 0}) =>
      FaceSyncResult._(FaceSyncStatus.failed, message: message, count: count);

  factory FaceSyncResult.empty() =>
      const FaceSyncResult._(FaceSyncStatus.empty);
}

class FaceDbRepository {
  FaceDbRepository({
    FaceDbApi? api,
    FaceDbDao? dao,
  })  : _api = api ?? FaceDbApi(),
        _dao = dao ?? const FaceDbDao();

  final FaceDbApi _api;
  final FaceDbDao _dao;

  static const _kVersion = 'cached_version';
  static const _kModelVersion = 'cached_model_version';
  /// Bump when embedding blob codec changes (forces re-download).
  static const _kCodecRev = 'embedding_codec_v2';

  Future<FaceSyncResult> syncIfNeeded() async {
    try {
      final server = await _api.fetchVersion();
      final db = await FaceDbDatabase.instance.database;
      final cachedVer = await _dao.getMeta(db, _kVersion);
      final cachedModel = await _dao.getMeta(db, _kModelVersion);
      final cachedCodec = await _dao.getMeta(db, _kCodecRev);
      final sameVersion = cachedVer != null &&
          int.tryParse(cachedVer) == server.version;
      final sameModel = cachedModel != null &&
          cachedModel == server.modelVersion;
      final sameCodec = cachedCodec == _kCodecRev;
      if (sameVersion && sameModel && sameCodec) {
        final rows = await _dao.loadAll(db);
        if (rows.isEmpty) {
          debugPrint('FaceDb: cache empty — full refresh');
          return await _fullRefresh(db, server.version, server.modelVersion);
        }
        debugPrint('FaceDb: up to date (${rows.length} templates)');
        return FaceSyncResult.upToDate(count: rows.length);
      }
      debugPrint(
        'FaceDb: version mismatch cached=$cachedVer model=$cachedModel '
        'server=${server.version}/${server.modelVersion}',
      );
      return await _fullRefresh(db, server.version, server.modelVersion);
    } catch (e, st) {
      debugPrint('FaceDb: sync error: $e\n$st');
      final db = await FaceDbDatabase.instance.database;
      final rows = await _dao.loadAll(db);
      if (rows.isNotEmpty) {
        debugPrint('FaceDb: using offline cache (${rows.length} templates)');
        return FaceSyncResult.failed('offline_cache: $e', count: rows.length);
      }
      return FaceSyncResult.failed(e.toString());
    }
  }

  Future<FaceSyncResult> _fullRefresh(
    dynamic db,
    int version,
    String modelVersion,
  ) async {
    final download = await _api.fetchEmbeddings();
    await _dao.clearAll(db);
    if (download.rows.isEmpty) {
      await _dao.setMeta(db, _kVersion, '$version');
      await _dao.setMeta(db, _kModelVersion, modelVersion);
      await _dao.setMeta(db, _kCodecRev, _kCodecRev);
      debugPrint('FaceDb: server returned 0 embeddings');
      return FaceSyncResult.empty();
    }
    await _dao.insertBatch(db, download.rows);
    await _dao.setMeta(db, _kVersion, '${download.version.version}');
    await _dao.setMeta(db, _kModelVersion, download.version.modelVersion);
    await _dao.setMeta(db, _kCodecRev, _kCodecRev);
    debugPrint('FaceDb: synced ${download.rows.length} templates');
    return FaceSyncResult.synced(download.rows.length);
  }

  Future<List<FaceEmbeddingRecord>> loadCached() async {
    final db = await FaceDbDatabase.instance.database;
    return _dao.loadAll(db);
  }

  /// Phase C — after enrollment upload, bypass version cache.
  Future<FaceSyncResult> forceRefresh() async {
    final db = await FaceDbDatabase.instance.database;
    await _dao.setMeta(db, _kVersion, '');
    debugPrint('FaceDb: force refresh after enrollment');
    return syncIfNeeded();
  }
}
