import 'dart:typed_data';

import 'package:el_race/core/site_management/face_recognition/data/models/face_embedding_record.dart';
import 'package:el_race/core/site_management/face_recognition/domain/embedding_codec.dart';
import 'package:sqflite/sqflite.dart';

class FaceDbDao {
  const FaceDbDao();

  Future<void> clearAll(Database db) async {
    await db.delete('face_cache_rows');
  }

  Future<void> insertBatch(Database db, List<FaceEmbeddingRecord> rows) async {
    final batch = db.batch();
    for (final row in rows) {
      batch.insert('face_cache_rows', {
        'employee_id': row.employeeId,
        'emp_code': row.empCode,
        'name': row.name,
        'department': row.department,
        'job_title': row.jobTitle,
        'in_foreman_team': row.inForemanTeam ? 1 : 0,
        'pose': row.pose,
        'face_image_id': row.faceImageId,
        'embedding': EmbeddingCodec.encodeToBlob(row.embedding),
      });
    }
    await batch.commit(noResult: true);
  }

  /// Fast enrollment probe — no full table scan in callers.
  Future<int> countTemplatesForEmployee(Database db, int employeeId) async {
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM face_cache_rows WHERE employee_id = ?',
      [employeeId],
    );
    if (rows.isEmpty) return 0;
    final value = rows.first['c'];
    if (value is int) return value;
    return int.tryParse('$value') ?? 0;
  }

  Future<List<FaceEmbeddingRecord>> loadAll(Database db) async {
    final maps = await db.query('face_cache_rows');
    return maps.map((m) {
      return FaceEmbeddingRecord(
        employeeId: m['employee_id'] as int,
        empCode: m['emp_code'] as String,
        name: m['name'] as String,
        department: (m['department'] as String?) ?? '',
        jobTitle: (m['job_title'] as String?) ?? '',
        inForemanTeam: (m['in_foreman_team'] as int) == 1,
        pose: m['pose'] as String?,
        faceImageId: m['face_image_id'] as int?,
        embedding: EmbeddingCodec.decodeBlob(m['embedding'] as Uint8List),
      );
    }).toList();
  }

  Future<String?> getMeta(Database db, String key) async {
    final rows = await db.query(
      'face_db_meta',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setMeta(Database db, String key, String value) async {
    await db.insert(
      'face_db_meta',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
