import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:el_race/core/site_management/face_recognition/data/models/face_enrollment_pose.dart';
import 'package:el_race/core/site_management/face_recognition/data/models/face_enrollment_result.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_transport.dart';
import 'package:flutter/foundation.dart';

/// Phase C — `POST /api/register_face_images` (multipart, ≥4 poses).
class FaceEnrollmentApi {
  FaceEnrollmentApi({TimesheetOdooTransport? transport})
      : _transport = transport ?? TimesheetOdooTransport(dio: Dio());

  final TimesheetOdooTransport _transport;

  Future<FaceEnrollmentResult> registerFaceImages({
    required int employeeId,
    required Map<FaceEnrollmentPose, String> imagePathsByPose,
    int? foremanEmployeeId,
  }) async {
    if (employeeId <= 0) {
      return FaceEnrollmentResult.failed(employeeId, 'Invalid employee_id');
    }
    if (imagePathsByPose.length < FaceEnrollmentPose.minimumRequired) {
      return FaceEnrollmentResult.failed(
        employeeId,
        'At least ${FaceEnrollmentPose.minimumRequired} pose images required',
      );
    }

    final formMap = <String, dynamic>{
      'employee_id': employeeId.toString(),
    };
    if (foremanEmployeeId != null && foremanEmployeeId > 0) {
      formMap['foreman_employee_id'] = foremanEmployeeId.toString();
    }
    for (final entry in imagePathsByPose.entries) {
      final path = entry.value;
      final file = File(path);
      if (!await file.exists()) {
        return FaceEnrollmentResult.failed(
          employeeId,
          'Missing file for ${entry.key.name}: $path',
        );
      }
      formMap[entry.key.multipartField] = await MultipartFile.fromFile(
        path,
        filename: '${entry.key.name}.jpg',
      );
    }

    try {
      final response = await _transport.dio.post<dynamic>(
        '${_transport.baseUrl}/register_face_images',
        data: FormData.fromMap(formMap),
        options: Options(
          headers: {
            'Accept': 'application/json',
            if (_transport.authToken != null &&
                _transport.authToken!.isNotEmpty)
              'Authorization': 'Bearer ${_transport.authToken}',
          },
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(seconds: 120),
          receiveTimeout: const Duration(seconds: 120),
        ),
      );
      return _parseResponse(employeeId, response.data);
    } on DioException catch (e) {
      final msg = e.response?.data?.toString() ?? e.message ?? 'Network error';
      debugPrint('FaceEnrollmentApi: Dio error $msg');
      return FaceEnrollmentResult.failed(employeeId, msg);
    } catch (e, st) {
      debugPrint('FaceEnrollmentApi: $e\n$st');
      return FaceEnrollmentResult.failed(employeeId, e.toString());
    }
  }

  FaceEnrollmentResult _parseResponse(int employeeId, dynamic raw) {
    Map<String, dynamic> body;
    if (raw is Map) {
      body = Map<String, dynamic>.from(raw);
    } else if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          body = Map<String, dynamic>.from(decoded);
        } else {
          return FaceEnrollmentResult.failed(employeeId, raw);
        }
      } catch (_) {
        return FaceEnrollmentResult.failed(employeeId, raw);
      }
    } else {
      return FaceEnrollmentResult.failed(employeeId, 'Empty response');
    }

    if (body['status']?.toString() == 'error') {
      return FaceEnrollmentResult.failed(
        employeeId,
        body['message']?.toString() ?? 'Enrollment failed',
      );
    }

    final data = body['data'];
    if (data is! Map) {
      return FaceEnrollmentResult(
        success: true,
        employeeId: employeeId,
        message: body['message']?.toString(),
      );
    }
    final map = Map<String, dynamic>.from(data);
    final linesRaw = map['lines'] ?? map['face_images'] ?? map['templates'];
    final lines = <FaceEnrollmentLineResult>[];
    if (linesRaw is List) {
      for (final item in linesRaw) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        final id = _int(m['face_image_id'] ?? m['id']);
        if (id <= 0) continue;
        lines.add(
          FaceEnrollmentLineResult(
            faceImageId: id,
            pose: m['pose']?.toString() ?? '',
            embeddingStatus: m['face_embedding_status']?.toString(),
            s3Key: m['s3_key']?.toString(),
          ),
        );
      }
    }
    return FaceEnrollmentResult(
      success: true,
      employeeId: employeeId,
      message: body['message']?.toString(),
      enrollmentStatus: map['face_enrollment_status']?.toString(),
      templateCount: _int(map['face_enrollment_ready_count'] ?? lines.length),
      lines: lines,
    );
  }

  static int _int(Object? v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}
