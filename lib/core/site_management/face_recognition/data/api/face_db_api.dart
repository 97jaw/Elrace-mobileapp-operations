import 'package:dio/dio.dart';
import 'package:el_race/core/site_management/face_recognition/data/models/face_db_version_info.dart';
import 'package:el_race/core/site_management/face_recognition/data/models/face_embedding_record.dart';
import 'package:el_race/core/site_management/face_recognition/domain/embedding_codec.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_transport.dart';

class FaceDbApi {
  FaceDbApi({TimesheetOdooTransport? transport})
      : _transport = transport ?? TimesheetOdooTransport(dio: Dio());

  final TimesheetOdooTransport _transport;

  Future<FaceDbVersionInfo> fetchVersion() async {
    final body = await _transport.postJsonRpc(
      '/face_db/version',
      params: const {},
    );
    final data = _unwrap(body);
    return FaceDbVersionInfo.fromJson(data);
  }

  Future<FaceDbDownload> fetchEmbeddings() async {
    final body = await _transport.postJsonRpc(
      '/face_db/embeddings',
      params: const {},
    );
    final data = _unwrap(body);
    final version = FaceDbVersionInfo(
      version: _int(data['version']),
      modelVersion: data['model_version']?.toString() ?? 'mobilefacenet-v1',
      totalEmployees: _int(data['employee_count']),
    );
    final employees = data['employees'];
    final rows = <FaceEmbeddingRecord>[];
    if (employees is List) {
      for (final raw in employees) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        rows.addAll(_parseEmployeeRows(map));
      }
    }
    return FaceDbDownload(version: version, rows: rows);
  }

  List<FaceEmbeddingRecord> _parseEmployeeRows(Map<String, dynamic> map) {
    final employeeId = _int(map['employee_id'] ?? map['id']);
    if (employeeId <= 0) return const [];
    final inTeam = map['in_foreman_team'] == true;
    final base = {
      'employeeId': employeeId,
      'empCode': map['emp_code']?.toString() ?? '$employeeId',
      'name': map['name']?.toString() ?? '',
      'department': map['department']?.toString() ?? '',
      'jobTitle': map['job_title']?.toString() ?? '',
      'inForemanTeam': inTeam,
    };
    final out = <FaceEmbeddingRecord>[];
    final templates = map['templates'];
    if (templates is List && templates.isNotEmpty) {
      for (final t in templates) {
        if (t is! Map) continue;
        final tm = Map<String, dynamic>.from(t);
        final emb = tm['embedding']?.toString();
        if (emb == null || emb.isEmpty) continue;
        out.add(FaceEmbeddingRecord(
          employeeId: employeeId,
          empCode: base['empCode']! as String,
          name: base['name']! as String,
          department: base['department']! as String,
          jobTitle: base['jobTitle']! as String,
          inForemanTeam: inTeam,
          pose: tm['pose']?.toString(),
          faceImageId: _intOrNull(tm['face_image_id']),
          embedding: EmbeddingCodec.decodeBase64Embedding(emb),
        ));
      }
      return out;
    }
    final primary = map['embedding']?.toString();
    if (primary != null && primary.isNotEmpty) {
      out.add(FaceEmbeddingRecord(
        employeeId: employeeId,
        empCode: base['empCode']! as String,
        name: base['name']! as String,
        department: base['department']! as String,
        jobTitle: base['jobTitle']! as String,
        inForemanTeam: inTeam,
        embedding: EmbeddingCodec.decodeBase64Embedding(primary),
      ));
    }
    return out;
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic> body) {
    final result = _transport.parseResult(body, debugLabel: 'face_db');
    if (result is! Map) {
      throw TimesheetOdooException('face_db invalid response');
    }
    final outer = Map<String, dynamic>.from(result);
    if (outer['status']?.toString() == 'error') {
      throw TimesheetOdooException(
        outer['message']?.toString() ?? 'face_db error',
      );
    }
    if (outer['data'] is Map) {
      return Map<String, dynamic>.from(outer['data'] as Map);
    }
    return outer;
  }

  static int _int(Object? v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static int? _intOrNull(Object? v) {
    if (v == null) return null;
    final n = _int(v);
    return n > 0 ? n : null;
  }
}

class FaceDbDownload {
  const FaceDbDownload({required this.version, required this.rows});

  final FaceDbVersionInfo version;
  final List<FaceEmbeddingRecord> rows;
}
