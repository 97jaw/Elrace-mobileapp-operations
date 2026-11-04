import 'package:el_race/core/notifications/push_only_approval.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isPushOnlyApproval', () {
    test('v1 waiting and progress are push-only', () {
      expect(
        isPushOnlyApproval({
          'nv': '1',
          'type': 'approval.waiting',
          'category': 'waiting',
          'model': 'account.move',
          'res_id': '42',
        }),
        isTrue,
      );
      expect(
        isPushOnlyApproval({
          'nv': '1',
          'type': 'approval.progress',
          'category': 'waiting',
          'model': 'purchase.order',
          'res_id': '7',
        }),
        isTrue,
      );
    });

    test('legacy waiting / per-level / fully-approved are push-only', () {
      expect(
        isPushOnlyApproval({
          'model': 'account.move',
          'record_id': '10',
          'status': 'pending',
          'category': 'waiting',
          'click_action': 'OPEN_RECORD',
        }),
        isTrue,
      );
      expect(
        isPushOnlyApproval({
          'model': 'hr.expense.sheet',
          'record_id': '11',
          'status': 'approved',
        }),
        isTrue,
      );
      expect(
        isPushOnlyApproval({
          'model': 'purchase.order',
          'record_id': '12',
          'status': 'approved_final',
        }),
        isTrue,
      );
      expect(
        isPushOnlyApproval({
          'model': 'it.hardware.request',
          'record_id': '13',
          'status': 'approved',
        }),
        isTrue,
      );
      expect(
        isPushOnlyApproval({
          'model': 'employee.requests',
          'request_id': '14',
          'status': 'approved',
        }),
        isTrue,
      );
    });

    test('legacy rejected stays stored', () {
      expect(
        isPushOnlyApproval({
          'model': 'account.move',
          'record_id': '20',
          'status': 'rejected',
        }),
        isFalse,
      );
      expect(
        isPushOnlyApproval({
          'model': 'employee.requests',
          'request_id': '21',
          'status': 'rejected',
        }),
        isFalse,
      );
    });

    test('matrix-stored types are not push-only', () {
      expect(
        isPushOnlyApproval({
          'nv': '1',
          'type': 'hr.request.approved',
          'category': 'hr',
          'model': 'employee.requests',
          'res_id': '30',
        }),
        isFalse,
      );
      expect(
        isPushOnlyApproval({
          'nv': '1',
          'type': 'circular.published',
          'category': 'circular',
          'action': 'open_screen',
          'screen': 'circulars',
        }),
        isFalse,
      );
      expect(
        isPushOnlyApproval({
          'category': 'chat',
          'chat_id': 'c1',
          'type': 'chat.direct',
        }),
        isFalse,
      );
      expect(
        isPushOnlyApproval({
          'nv': '1',
          'type': 'purchase.lpo.issued',
          'category': 'purchase',
        }),
        isFalse,
      );
      expect(
        isPushOnlyApproval({
          'nv': '1',
          'type': 'timesheet_approval.result',
          'category': 'timesheet_approval',
        }),
        isFalse,
      );
    });

    test('empty or unrelated payloads are not push-only', () {
      expect(isPushOnlyApproval(null), isFalse);
      expect(isPushOnlyApproval({}), isFalse);
      expect(
        isPushOnlyApproval({'model': 'project.project', 'status': 'approved'}),
        isFalse,
      );
      expect(
        isPushOnlyApproval({'model': 'account.move', 'status': 'paid'}),
        isFalse,
      );
    });
  });
}
