import 'package:el_race/core/site_management/face_recognition/face_min_device_check.dart';
import 'package:el_race/core/site_management/face_recognition/profile_photo_face_db.dart';
import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:flutter/foundation.dart';

enum SelfFaceTemplateStatus { pending, ready, failed }

/// Builds / caches the logged-in employee's profile-photo template on
/// [ProfilePhotoFaceDb.self] — never touches [ProfilePhotoFaceDb.instance].
class SelfFaceTemplateService {
  SelfFaceTemplateService._();
  static final SelfFaceTemplateService instance = SelfFaceTemplateService._();

  SelfFaceTemplateStatus _status = SelfFaceTemplateStatus.pending;
  String? _reason;
  int? _employeeId;

  SelfFaceTemplateStatus get status => _status;
  String? get reason => _reason;
  int? get employeeId => _employeeId;

  static const noPhotoMessage =
      "Your profile photo can't be used for face check. Please contact HR.";
  static const deviceMessage =
      "This phone can't run face verification. Please contact your admin.";

  /// Warm in the background when check-in context says face is required.
  Future<void> warm({required String? profilePhotoUrl}) async {
    _status = SelfFaceTemplateStatus.pending;
    _reason = null;

    final data = SharedPref.getLoginData().result?.data;
    final empId = data?.employee_id ??
        int.tryParse(data?.emp_id ?? '') ??
        int.tryParse(data?.emp_profile_id ?? '') ??
        0;
    _employeeId = empId > 0 ? empId : null;
    if (_employeeId == null) {
      _fail(noPhotoMessage);
      return;
    }

    final url = (profilePhotoUrl ?? '').trim();
    if (url.isEmpty) {
      _fail(noPhotoMessage);
      return;
    }

    final device = await FaceMinDeviceCheck.evaluate();
    if (!device.passed) {
      _fail(deviceMessage);
      return;
    }

    final me = TimesheetOdooEmployee(
      id: _employeeId!,
      employeeId: _employeeId!,
      name: data?.name ?? 'Me',
      image: url,
      hasProfileImage: true,
    );

    final db = ProfilePhotoFaceDb.self;
    db.setLabour([me], targetIds: {_employeeId!}, force: true);

    for (var i = 0; i < 60; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final state = db.stateOf(_employeeId!);
      if (state == ProfileTemplateState.ready &&
          db.hasTemplateFor(_employeeId!)) {
        _status = SelfFaceTemplateStatus.ready;
        _reason = null;
        debugPrint('SelfFaceTemplate: ready emp=$_employeeId');
        return;
      }
      if (state == ProfileTemplateState.failed) break;
    }

    _fail(noPhotoMessage);
    debugPrint('SelfFaceTemplate: failed emp=$_employeeId');
  }

  void _fail(String message) {
    _status = SelfFaceTemplateStatus.failed;
    _reason = message;
  }

  /// Tests: self template DB is not the foreman roster singleton.
  ProfilePhotoFaceDb templateDb() => ProfilePhotoFaceDb.self;
}
