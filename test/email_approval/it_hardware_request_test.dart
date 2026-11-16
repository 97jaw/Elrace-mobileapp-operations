import 'package:el_race/ui/presentation/Email%20Approval/models/it_hardware_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ItHardwareRequest', () {
    test('parses the confirmed hardware request fields', () {
      final request = ItHardwareRequest.fromMap({
        'id': 14665,
        'name': 'REQ/2026/14665',
        'request_type': 'IT Hardware Request',
        'request_date': '16/11/2026',
        'requester_name': 'Qossay Naji Ali Bahlool',
        'requester_department': 'IT',
        'hardware_user': [3377, 'Qossay Naji Ali Bahlool'],
        'employee_id': 3377,
        'department': 'IT',
        'current_approver': [12, 'IT Manager'],
        'project': [50, 'Head Office'],
        'project_manager': {'name': 'Mohammed Jawad'},
      });

      expect(request.id, '14665');
      expect(request.requestNumber, 'REQ/2026/14665');
      expect(request.requestType, 'IT Hardware Request');
      expect(request.requester, 'Qossay Naji Ali Bahlool');
      expect(request.hardwareUser, 'Qossay Naji Ali Bahlool');
      expect(request.employeeId, '3377');
      expect(request.currentApprover, 'IT Manager');
      expect(request.project, 'Head Office');
      expect(request.projectManager, 'Mohammed Jawad');
    });

    test('keeps unavailable optional fields empty', () {
      final request = ItHardwareRequest.fromMap({
        'id': 'LOCAL_FAKE_IT_1',
        'request_no': 'REQ/2026/1',
        'hardware_user_name': 'Test User',
        'project': false,
        'project_manager': null,
      });

      expect(request.currentApprover, isEmpty);
      expect(request.project, isEmpty);
      expect(request.projectManager, isEmpty);
      expect(request.isDebug, isTrue);
    });
  });
}
