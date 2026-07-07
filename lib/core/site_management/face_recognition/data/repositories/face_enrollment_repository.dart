import 'package:el_race/core/site_management/face_recognition/data/api/face_enrollment_api.dart';
import 'package:el_race/core/site_management/face_recognition/data/local/face_db_database.dart';
import 'package:el_race/core/site_management/face_recognition/data/local/face_db_dao.dart';
import 'package:el_race/core/site_management/face_recognition/data/models/face_enrollment_poll_result.dart';
import 'package:el_race/core/site_management/face_recognition/data/models/face_enrollment_pose.dart';
import 'package:el_race/core/site_management/face_recognition/data/models/face_enrollment_result.dart';
import 'package:el_race/core/site_management/face_recognition/data/repositories/face_db_repository.dart';
import 'package:flutter/foundation.dart';

/// Phase C — upload poses → Lambda embeddings → refresh local face DB.
class FaceEnrollmentRepository {
  FaceEnrollmentRepository({
    FaceEnrollmentApi? api,
    FaceDbRepository? faceDbRepository,
    FaceDbDao? dao,
  })  : _api = api ?? FaceEnrollmentApi(),
        _faceDb = faceDbRepository ?? FaceDbRepository(),
        _dao = dao ?? const FaceDbDao();

  final FaceEnrollmentApi _api;
  final FaceDbRepository _faceDb;
  final FaceDbDao _dao;

  static const _pollInterval = Duration(seconds: 5);
  static const _pollTimeout = Duration(seconds: 45);

  Future<FaceEnrollmentResult> enrollEmployee({
    required int employeeId,
    required Map<FaceEnrollmentPose, String> imagePathsByPose,
    int? foremanEmployeeId,
    bool refreshFaceDbAfterUpload = true,
    bool waitForTemplatesInFaceDb = true,
  }) async {
    final upload = await _api.registerFaceImages(
      employeeId: employeeId,
      imagePathsByPose: imagePathsByPose,
      foremanEmployeeId: foremanEmployeeId,
    );
    if (!upload.success) {
      final recovered = await _tryRecoverFromServerSideSuccess(
        employeeId: employeeId,
        uploadError: upload.message,
      );
      if (recovered != null) {
        return _finalizeAfterUpload(
          recovered,
          employeeId: employeeId,
          refreshFaceDbAfterUpload: refreshFaceDbAfterUpload,
          waitForTemplatesInFaceDb: waitForTemplatesInFaceDb,
        );
      }
      return upload;
    }

    debugPrint(
      'FaceEnrollment: registered emp=$employeeId '
      'status=${upload.enrollmentStatus} lines=${upload.lines.length}',
    );

    return _finalizeAfterUpload(
      upload,
      employeeId: employeeId,
      refreshFaceDbAfterUpload: refreshFaceDbAfterUpload,
      waitForTemplatesInFaceDb: waitForTemplatesInFaceDb,
    );
  }

  Future<FaceEnrollmentResult> _finalizeAfterUpload(
    FaceEnrollmentResult upload, {
    required int employeeId,
    required bool refreshFaceDbAfterUpload,
    required bool waitForTemplatesInFaceDb,
  }) async {
    if (!refreshFaceDbAfterUpload) return upload;

    var templateCount = upload.templateCount;
    if (waitForTemplatesInFaceDb) {
      final poll = await pollUntilEmployeeTemplatesReady(employeeId);
      templateCount = poll.templateCount;
      if (!poll.ready) {
        debugPrint(
          'FaceEnrollment: poll timeout emp=$employeeId count=$templateCount',
        );
      }
    } else {
      try {
        await _faceDb.forceRefresh();
      } catch (e) {
        debugPrint('FaceEnrollment: post-upload sync failed (non-fatal): $e');
      }
    }

    return FaceEnrollmentResult(
      success: true,
      employeeId: employeeId,
      message: upload.message,
      enrollmentStatus: upload.enrollmentStatus,
      templateCount: templateCount,
      lines: upload.lines,
    );
  }

  /// Poll server face DB version until ≥ [minimum] templates cached for [employeeId].
  Future<FaceEnrollmentPollResult> pollUntilEmployeeTemplatesReady(
    int employeeId, {
    int minimum = FaceEnrollmentPose.minimumRequired,
    Duration interval = _pollInterval,
    Duration timeout = _pollTimeout,
  }) async {
    if (employeeId <= 0) {
      return const FaceEnrollmentPollResult(
        templateCount: 0,
        ready: false,
        timedOut: true,
      );
    }

    await _faceDb.forceRefresh();
    var count = await _countCachedTemplates(employeeId);
    if (count >= minimum) {
      return FaceEnrollmentPollResult(
        templateCount: count,
        ready: true,
        timedOut: false,
      );
    }

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(interval);
      await _faceDb.syncIfNeeded();
      count = await _countCachedTemplates(employeeId);
      debugPrint(
        'FaceEnrollment: poll emp=$employeeId templates=$count (need $minimum)',
      );
      if (count >= minimum) {
        return FaceEnrollmentPollResult(
          templateCount: count,
          ready: true,
          timedOut: false,
        );
      }
    }

    return FaceEnrollmentPollResult(
      templateCount: count,
      ready: count >= minimum,
      timedOut: count < minimum,
    );
  }

  Future<int> _countCachedTemplates(int employeeId) async {
    final db = await FaceDbDatabase.instance.database;
    return _dao.countTemplatesForEmployee(db, employeeId);
  }

  /// Odoo may save S3 templates + queue Lambda then return HTTP 500 (race on commit).
  Future<FaceEnrollmentResult?> _tryRecoverFromServerSideSuccess({
    required int employeeId,
    String? uploadError,
  }) async {
    final err = uploadError?.toLowerCase() ?? '';
    final looksLikeServer500 = err.contains('500') ||
        err.contains('internal server error') ||
        err.contains('<!doctype html');
    if (!looksLikeServer500) return null;

    debugPrint(
      'FaceEnrollment: upload returned server error — checking Odoo cache…',
    );
    await Future<void>.delayed(const Duration(seconds: 4));
    try {
      final poll = await pollUntilEmployeeTemplatesReady(employeeId);
      if (poll.ready) {
        debugPrint(
          'FaceEnrollment: recovered emp=$employeeId templates=${poll.templateCount}',
        );
        return FaceEnrollmentResult(
          success: true,
          employeeId: employeeId,
          message: 'Enrollment saved on server; face data synced.',
          templateCount: poll.templateCount,
        );
      }
    } catch (e) {
      debugPrint('FaceEnrollment: recovery sync failed: $e');
    }
    return null;
  }
}
