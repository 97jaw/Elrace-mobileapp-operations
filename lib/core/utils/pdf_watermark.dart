import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// PDF watermark per SRD §6.5.1 — reusable for E3, M3, M2 exports.
abstract final class PdfWatermark {
  static PdfColor get _watermarkColor =>
      PdfColor(197 / 255, 205 / 255, 214 / 255); // #C5CDD6

  /// Diagonal watermark behind content (single centered instance per page).
  static pw.Widget layer(String empId) {
    return pw.Opacity(
      opacity: 0.2,
      child: pw.Transform.rotate(
        angle: -0.78539816339, // -45°
        child: pw.Center(
          child: pw.Text(
            empId,
            style: pw.TextStyle(
              fontSize: 60,
              color: _watermarkColor,
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a minimal one-page PDF to verify watermark visibility (F.7).
  static Future<Uint8List> buildSamplePdf({required String empId}) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Stack(
            children: [
              pw.Positioned.fill(child: layer(empId)),
              pw.Padding(
                padding: const pw.EdgeInsets.all(40),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'HR Management — sample export',
                      style: pw.TextStyle(
                        fontSize: 18,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      'Watermark should match login emp_id: $empId',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
    return doc.save();
  }

  /// E3 / M3 — one-page summary with watermark (SRD §6.5).
  static Future<Uint8List> buildRequestDetailPdf({
    required String watermarkEmpId,
    required String heading,
    required String referenceLine,
    required String statusLine,
    required List<(String label, String value)> rows,
    required List<String> timelineLines,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Stack(
            children: [
              pw.Positioned.fill(child: layer(watermarkEmpId)),
              pw.Padding(
                padding: const pw.EdgeInsets.all(40),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      heading,
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(referenceLine, style: const pw.TextStyle(fontSize: 11)),
                    pw.Text(statusLine, style: const pw.TextStyle(fontSize: 11)),
                    pw.SizedBox(height: 16),
                    pw.Text(
                      'Details',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    ...rows.map(
                      (r) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 4),
                        child: pw.Text(
                          '${r.$1}: ${r.$2}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      'Timeline',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    ...timelineLines.map(
                      (t) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 3),
                        child: pw.Text('• $t', style: const pw.TextStyle(fontSize: 10)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
    return doc.save();
  }

  /// M2 — dashboard snapshot (charts as text lines until backend charts export).
  static Future<Uint8List> buildDashboardPdf({
    required String watermarkEmpId,
    required String periodLabel,
    required List<String> lines,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Stack(
            children: [
              pw.Positioned.fill(child: layer(watermarkEmpId)),
              pw.Padding(
                padding: const pw.EdgeInsets.all(40),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'HR Management — dashboard',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text('Period: $periodLabel', style: const pw.TextStyle(fontSize: 11)),
                    pw.SizedBox(height: 16),
                    ...lines.map(
                      (l) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 4),
                        child: pw.Text(l, style: const pw.TextStyle(fontSize: 10)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
    return doc.save();
  }
}
