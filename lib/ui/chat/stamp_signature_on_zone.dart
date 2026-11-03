import 'dart:typed_data';
import 'dart:ui';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../chat/models/message.dart';

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
