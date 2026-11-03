import 'dart:typed_data';

import 'package:el_race/core/timesheet/timesheet_acknowledgment_zones.dart';
import 'package:el_race/ui/chat/stamp_signature_on_zone.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

void main() {
  test('3-labour print places 12 owned cells and keeps the page count', () async {
    final bytes = await _threeLabourPdf();
    final before = _pageCount(bytes);
    final cells = findTimesheetAcknowledgmentCells(bytes);

    expect(cells, hasLength(12));
    expect(cells.where((c) => c.zone.signerSlot == 0), hasLength(6));
    expect(cells.where((c) => c.zone.signerSlot == 1), hasLength(3));
    expect(cells.where((c) => c.zone.signerSlot == 2), hasLength(3));
    expect(
      cells.map((c) => c.role).toSet(),
      {'employee', 'supervisor', 'site_engineer', 'projects_manager'},
    );

    for (final cell in cells.where((c) => c.role == 'employee')) {
      final site = cells.firstWhere(
        (c) =>
            c.role == 'site_engineer' &&
            c.page == cell.page &&
            c.tableIndex == cell.tableIndex,
      );
      expect(cell.zone.y, lessThan(site.zone.y));
      expect(cell.zone.signerSlot, 0);
      expect(site.zone.signerSlot, 1);
    }

    final stamped = stampSignatureOntoZone(
      pdfBytes: bytes,
      zone: cells.first.zone,
      signaturePng: _png,
    );
    expect(_pageCount(stamped), before);
  });

}

Future<Uint8List> _threeLabourPdf() async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        for (var labour = 0; labour < 3; labour++) ...[
          pw.Text('Employee Name: Labour ${labour + 1} with a long name'),
          pw.SizedBox(height: 6),
          for (var line = 0; line < (labour == 2 ? 36 : 6); line++)
            pw.Text('Daily work line $line for labour $labour'),
          pw.SizedBox(height: 8),
          pw.Text('Approval and Acknowledgment'),
          pw.Table(
            border: pw.TableBorder.all(width: 0.4),
            columnWidths: {
              0: const pw.FlexColumnWidth(),
              1: const pw.FlexColumnWidth(),
            },
            children: [
              pw.TableRow(
                children: [
                  _cell('Employee:'),
                  _cell('Supervisor/Foreman:'),
                ],
              ),
              pw.TableRow(
                children: [
                  _cell('Site Engineer:'),
                  _cell('Projects Manager:'),
                ],
              ),
            ],
          ),
          if (labour < 2) pw.NewPage(),
        ],
      ],
    ),
  );
  return doc.save();
}

pw.Widget _cell(String label) {
  return pw.Padding(
    padding: const pw.EdgeInsets.fromLTRB(6, 4, 6, 46),
    child: pw.Text(label),
  );
}

int _pageCount(Uint8List bytes) {
  final doc = sf.PdfDocument(inputBytes: bytes);
  final count = doc.pages.count;
  doc.dispose();
  return count;
}

/// 1x1 transparent PNG.
final Uint8List _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);
