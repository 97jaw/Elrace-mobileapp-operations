import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class FaceDbDatabase {
  FaceDbDatabase._();
  static final FaceDbDatabase instance = FaceDbDatabase._();

  static const _dbName = 'site_mgmt_face_db_v1';
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final base = await getDatabasesPath();
    _db = await openDatabase(
      p.join(base, _dbName),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE face_cache_rows (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            employee_id INTEGER NOT NULL,
            emp_code TEXT NOT NULL,
            name TEXT NOT NULL,
            department TEXT,
            job_title TEXT,
            in_foreman_team INTEGER NOT NULL DEFAULT 0,
            pose TEXT,
            face_image_id INTEGER,
            embedding BLOB NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_face_cache_emp ON face_cache_rows(employee_id)',
        );
        await db.execute('''
          CREATE TABLE face_db_meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }
}
