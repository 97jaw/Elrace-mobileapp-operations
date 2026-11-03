import 'dart:typed_data';
import 'dart:ui';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../chat/models/message.dart';
import '../../core/timesheet/models/timesheet_approval.dart';

/// Draws [signaturePng] inside [zone], contained and centered. Never stretches.
Uint8List stampSignatureOntoZone({
  required Uint8List pdfBytes,
  required SignZone zone,
  required Uint8List signaturePng,
}) {
  final doc = PdfDocument(inputBytes: pdfBytes);
  if (zone.page < doc.pages.count) {
    final page = doc.pages[zone.page];
    final ps = page.getClientSize();
    final boxX = zone.x * ps.width;
    final boxY = zone.y * ps.height;
    final boxW = zone.width * ps.width;
    final boxH = zone.height * ps.height;

    final bitmap = PdfBitmap(signaturePng);
    final imgW = bitmap.width.toDouble();
    final imgH = bitmap.height.toDouble();

    late final double drawW;
    late final double drawH;
    if (imgW <= 0 || imgH <= 0) {
      drawW = boxW;
      drawH = boxH;
    } else if (imgW / imgH > boxW / boxH) {
      drawW = boxW;
      drawH = boxW * imgH / imgW;
    } else {
      drawH = boxH;
      drawW = boxH * imgW / imgH;
    }
    final drawX = boxX + (boxW - drawW) / 2;
    final drawY = boxY + (boxH - drawH) / 2;

    page.graphics.drawImage(
      bitmap,
      Rect.fromLTWH(drawX, drawY, drawW, drawH),
    );
  }
  final bytes = doc.saveSync();
  doc.dispose();
  return Uint8List.fromList(bytes);
}

/// Draws "Approved by …" text into every SE/PM cell for approved approvers.
///
/// Original [pdfBytes] are left untouched; returns a new buffer. Pending and
/// rejected approvers draw nothing.
Uint8List stampTimesheetApprovalTexts({
  required Uint8List pdfBytes,
  required List<TimesheetApprovalCell> cells,
  required Map<String, TimesheetApproverEntry> approvers,
}) {
  final approvedByRole = <TimesheetApproverRole, TimesheetApproverEntry>{};
  for (final entry in approvers.values) {
    if (entry.status != TimesheetApproverStatus.approved) continue;
    approvedByRole[entry.role] = entry;
  }
  if (approvedByRole.isEmpty) {
    return Uint8List.fromList(pdfBytes);
  }

  final doc = PdfDocument(inputBytes: pdfBytes);
  try {
    final brush = PdfSolidBrush(PdfColor(20, 20, 20));
    for (final cell in cells) {
      final approver = approvedByRole[cell.role];
      if (approver == null) continue;
      if (cell.page < 0 || cell.page >= doc.pages.count) continue;

      final page = doc.pages[cell.page];
      final ps = page.getClientSize();
      final box = Rect.fromLTWH(
        cell.x * ps.width,
        cell.y * ps.height,
        cell.width * ps.width,
        cell.height * ps.height,
      );
      if (box.width <= 1 || box.height <= 1) continue;

      final label =
          'Approved by ${approver.name} (${cell.role.displayLabel})';
      final font = _fitApprovalFont(label, box);
      final size = font.measureString(label);
      final drawX = box.left + (box.width - size.width) / 2;
      final drawY = box.top + (box.height - size.height) / 2;
      page.graphics.drawString(
        label,
        font,
        brush: brush,
        bounds: Rect.fromLTWH(drawX, drawY, size.width, size.height),
      );
    }
    return Uint8List.fromList(doc.saveSync());
  } finally {
    doc.dispose();
  }
}

PdfFont _fitApprovalFont(String text, Rect box) {
  var size = (box.height * 0.55).clamp(5.0, 14.0);
  for (var i = 0; i < 24; i++) {
    final font = PdfStandardFont(PdfFontFamily.helvetica, size);
    final measured = font.measureString(text);
    if (measured.width <= box.width && measured.height <= box.height) {
      return font;
    }
    size = (size * 0.88).clamp(4.0, 14.0);
    if (size <= 4.0) {
      return PdfStandardFont(PdfFontFamily.helvetica, 4);
    }
  }
  return PdfStandardFont(PdfFontFamily.helvetica, 4);
}
