import 'package:el_race/core/services/approval_count_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    ApprovalCountService.invalidateCache();
    ApprovalCountService.clearSignDocumentPart();
  });

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

  test('cached total = Odoo + SD; flag OFF uses Odoo only', () {
    ApprovalCountService.updateCachedCount(10);
    ApprovalCountService.updateSignDocumentCount(4, flagOn: true);
    expect(ApprovalCountService.cachedCountOrZero, 14);

    ApprovalCountService.updateSignDocumentCount(4, flagOn: false);
    expect(ApprovalCountService.cachedCountOrZero, 10);
  });

  test('SD update does not clear the Odoo cache', () {
    ApprovalCountService.updateCachedCount(7);
    expect(ApprovalCountService.cachedCount, 7);

    ApprovalCountService.updateSignDocumentCount(3, flagOn: true);
    expect(ApprovalCountService.cachedCount, 10);

    ApprovalCountService.invalidateCache();
    // Odoo invalidated; SD part still present for instant paint before refetch.
    expect(ApprovalCountService.cachedCount, isNull);
    expect(ApprovalCountService.cachedCountOrZero, 3);
  });

  test('combineCachedParts matches sum rules', () {
    expect(
      ApprovalCountService.combineCachedParts(
        odooCount: 8,
        timesheetApprovalEnabled: true,
        signDocumentCount: 2,
      ),
      10,
    );
    expect(
      ApprovalCountService.combineCachedParts(
        odooCount: 8,
        timesheetApprovalEnabled: false,
        signDocumentCount: 2,
      ),
      8,
    );
  });
}
