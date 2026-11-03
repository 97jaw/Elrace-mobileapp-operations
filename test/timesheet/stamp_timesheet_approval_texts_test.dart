import 'dart:typed_data';
import 'dart:ui';

import 'package:el_race/core/timesheet/models/timesheet_approval.dart';
import 'package:el_race/ui/chat/stamp_signature_on_zone.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('draws approved text in the right cells and skips pending/rejected', () {
    final blank = _blankTwoPagePdf();
    final cells = [
      const TimesheetApprovalCell(
        page: 0,
        role: TimesheetApproverRole.siteEngineer,
        x: 0.1,
        y: 0.7,
        width: 0.35,
        height: 0.08,
      ),
      const TimesheetApprovalCell(
        page: 0,
        role: TimesheetApproverRole.projectsManager,
        x: 0.5,
        y: 0.7,
        width: 0.35,
        height: 0.08,
      ),
      const TimesheetApprovalCell(
        page: 1,
        role: TimesheetApproverRole.siteEngineer,
        x: 0.1,
        y: 0.7,
        width: 0.35,
        height: 0.08,
      ),
      const TimesheetApprovalCell(
        page: 1,
        role: TimesheetApproverRole.projectsManager,
        x: 0.5,
        y: 0.7,
        width: 0.35,
        height: 0.08,
      ),
    ];

    final stamped = stampTimesheetApprovalTexts(
      pdfBytes: blank,
      cells: cells,
      approvers: {
        'odoo_200': const TimesheetApproverEntry(
          role: TimesheetApproverRole.siteEngineer,
          name: 'Bob',
          status: TimesheetApproverStatus.approved,
        ),
        'odoo_300': const TimesheetApproverEntry(
          role: TimesheetApproverRole.projectsManager,
          name: 'Carol',
          status: TimesheetApproverStatus.pending,
        ),
      },
    );

    expect(
      identical(stamped, blank),
      isFalse,
      reason: 'original bytes must stay untouched',
    );
    expect(_pageText(stamped, 0), contains('Approved by Bob (Site Engineer)'));
    expect(_pageText(stamped, 1), contains('Approved by Bob (Site Engineer)'));
    expect(_pageText(stamped, 0), isNot(contains('Carol')));
    expect(_pageText(stamped, 0), isNot(contains('Projects Manager')));

    final both = stampTimesheetApprovalTexts(
      pdfBytes: blank,
      cells: cells,
      approvers: {
        'odoo_200': const TimesheetApproverEntry(
          role: TimesheetApproverRole.siteEngineer,
          name: 'Bob',
          status: TimesheetApproverStatus.approved,
        ),
        'odoo_300': const TimesheetApproverEntry(
          role: TimesheetApproverRole.projectsManager,
          name: 'Carol',
          status: TimesheetApproverStatus.approved,
        ),
      },
    );
    expect(_pageText(both, 0), contains('Approved by Bob (Site Engineer)'));
    expect(
      _pageText(both, 0),
      contains('Approved by Carol (Projects Manager)'),
    );

    final rejected = stampTimesheetApprovalTexts(
      pdfBytes: blank,
      cells: cells,
      approvers: {
        'odoo_200': const TimesheetApproverEntry(
          role: TimesheetApproverRole.siteEngineer,
          name: 'Bob',
          status: TimesheetApproverStatus.rejected,
        ),
      },
    );
    expect(_pageText(rejected, 0), isNot(contains('Approved by')));
  });

  test('approval text stays inside its cell bounds', () {
    final blank = _blankTwoPagePdf();
    const cell = TimesheetApprovalCell(
      page: 0,
      role: TimesheetApproverRole.siteEngineer,
      x: 0.1,
      y: 0.7,
      width: 0.35,
      height: 0.08,
    );
    final stamped = stampTimesheetApprovalTexts(
      pdfBytes: blank,
      cells: const [cell],
      approvers: {
        'odoo_200': const TimesheetApproverEntry(
          role: TimesheetApproverRole.siteEngineer,
          name: 'Bob Very Long Name For Shrink',
          status: TimesheetApproverStatus.approved,
        ),
      },
    );

    final doc = PdfDocument(inputBytes: stamped);
    final extractor = PdfTextExtractor(doc);
    final lines = extractor.extractTextLines(startPageIndex: 0, endPageIndex: 0);
    doc.dispose();

    final hit = lines.where(
      (line) => line.text.contains('Approved by Bob Very Long Name'),
    );
    expect(hit, isNotEmpty);
    final pageSize = const Size(595, 842);
    final box = Rect.fromLTWH(
      cell.x * pageSize.width,
      cell.y * pageSize.height,
      cell.width * pageSize.width,
      cell.height * pageSize.height,
    );
    for (final line in hit) {
      final bounds = line.bounds;
      expect(bounds.left, greaterThanOrEqualTo(box.left - 1));
      expect(bounds.top, greaterThanOrEqualTo(box.top - 1));
      expect(bounds.right, lessThanOrEqualTo(box.right + 1));
      expect(bounds.bottom, lessThanOrEqualTo(box.bottom + 1));
    }
  });
}

Uint8List _blankTwoPagePdf() {
  final doc = PdfDocument();
  doc.pages.add();
  doc.pages.add();
  final bytes = Uint8List.fromList(doc.saveSync());
  doc.dispose();
  return bytes;
}

String _pageText(Uint8List bytes, int page) {
  final doc = PdfDocument(inputBytes: bytes);
  final text = PdfTextExtractor(doc).extractText(
    startPageIndex: page,
    endPageIndex: page,
  );
  doc.dispose();
  return text;
}
