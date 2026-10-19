import 'package:el_race/core/timesheet/models/timesheet_submit_request.dart';
import 'package:el_race/core/timesheet/services/capture_queue_service.dart';
import 'package:flutter_test/flutter_test.dart';

AttendanceCaptureDraft _draft() => AttendanceCaptureDraft(
      id: 'capture_1',
      projectId: '10',
      taskId: '20',
      event: 'checkIn',
      createdAt: DateTime(2026, 10, 15, 7),
      cropLocalPath: '/tmp/a.jpg',
      lat: 25.1,
      lon: 55.2,
      syncState: AttendanceCaptureSyncState.pending,
    );

TimesheetSubmitRequest _request(List<TimesheetSubmitFaceAudit> audits) =>
    TimesheetSubmitRequest(
      projectId: '10',
      taskId: '20',
      employeeIds: const [1, 2, 3, 4],
      employeeName: 'A, B, C, D',
      date: DateTime(2026, 10, 15),
      dateTime: DateTime(2026, 10, 15, 7),
      dateTimeEnd: DateTime(2026, 10, 15, 15),
      faceAudits: audits,
    );

void main() {
  group('AttendanceCaptureDraft face audit', () {
    test('round-trips through JSON', () {
      final d = _draft().withFaceAudit(
        verified: true,
        score: 0.4123,
        lead: 0.0841,
        cohortSize: 23,
        liveness: 'pass',
      );
      final back = AttendanceCaptureDraft.fromJson(d.toJson());
      expect(back.faceVerified, isTrue);
      expect(back.faceScore, 0.4123);
      expect(back.faceLead, 0.0841);
      expect(back.faceCohortSize, 23);
      expect(back.faceLiveness, 'pass');
    });

    test('drafts from an older build still load, without audit', () {
      final old = _draft().toJson()
        ..removeWhere((k, _) => k.startsWith('face_'));
      final back = AttendanceCaptureDraft.fromJson(old);
      expect(back.hasFaceAudit, isFalse);
      expect(TimesheetSubmitFaceAudit.fromDraft(1, back), isNull);
    });

    test('copyWith keeps the audit', () {
      final d = _draft()
          .withFaceAudit(verified: true, score: 0.5, liveness: 'pass')
          .copyWith(attempts: 2);
      expect(d.faceVerified, isTrue);
      expect(d.faceScore, 0.5);
    });
  });

  group('submit params', () {
    test('no audits → no face_verification key (old payload)', () {
      final params =
          _request(const []).toJsonRpcParams(appVersion: '1.0.35+103');
      expect(params.containsKey('face_verification'), isFalse);
    });

    test('3 verified + 1 manual → 3 audit entries', () {
      final verified = _draft().withFaceAudit(
        verified: true,
        score: 0.41,
        lead: 0.08,
        cohortSize: 23,
        liveness: 'pass',
      );
      final audits = [
        for (final id in [1, 2, 3])
          TimesheetSubmitFaceAudit.fromDraft(id, verified)!,
      ];
      expect(TimesheetSubmitFaceAudit.fromDraft(4, _draft()), isNull);
      final params = _request(audits).toJsonRpcParams(appVersion: '1.0.35+103');
      final fv = params['face_verification'] as Map;
      expect(fv.keys, ['1', '2', '3']);
      expect(fv['1'], {
        'verified': true,
        'score': 0.41,
        'lead': 0.08,
        'cohort_size': 23,
        'liveness': 'pass',
        'method': 'profile_1to1',
        'app_version': '1.0.35+103',
      });
    });

    test('small cohort: lead omitted', () {
      final d = _draft().withFaceAudit(
        verified: true,
        score: 0.45,
        cohortSize: 2,
        liveness: 'pass',
      );
      final params = _request([TimesheetSubmitFaceAudit.fromDraft(1, d)!])
          .toJsonRpcParams();
      final entry = (params['face_verification'] as Map)['1'] as Map;
      expect(entry.containsKey('lead'), isFalse);
      expect(entry.containsKey('app_version'), isFalse);
    });

    test('audit for an employee not in employee_ids is not sent', () {
      final d = _draft().withFaceAudit(verified: true, liveness: 'pass');
      final params = _request([TimesheetSubmitFaceAudit.fromDraft(99, d)!])
          .toJsonRpcParams();
      expect(params.containsKey('face_verification'), isFalse);
    });
  });
}
