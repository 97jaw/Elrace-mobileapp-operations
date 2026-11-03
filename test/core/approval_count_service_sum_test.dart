import 'package:el_race/core/services/approval_count_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('badge sum is Odoo only when timesheet approval flag is off', () {
    expect(
      ApprovalCountService.sumApprovalCounts(
        hr: 1,
        rfq: 2,
        invoice: 3,
        pettyCash: 4,
        timesheetApprovalEnabled: false,
        signDocumentCount: 9,
      ),
      10,
    );
  });

  test('badge sum includes Sign Document when flag is on', () {
    expect(
      ApprovalCountService.sumApprovalCounts(
        hr: 1,
        rfq: 2,
        invoice: 3,
        pettyCash: 4,
        timesheetApprovalEnabled: true,
        signDocumentCount: 5,
      ),
      15,
    );
  });

  test('negative Sign Document count is treated as zero', () {
    expect(
      ApprovalCountService.sumApprovalCounts(
        hr: 1,
        rfq: 0,
        invoice: 0,
        pettyCash: 0,
        timesheetApprovalEnabled: true,
        signDocumentCount: -3,
      ),
      1,
    );
  });
}
