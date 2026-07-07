import 'dart:typed_data';

import 'package:el_race/core/payslip/models/payslip_models.dart';
import 'package:el_race/core/utils/pdf_watermark.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Payslip PDF aligned to Module 4 screenshots + watermark (emp id / ref).
abstract final class PayslipPdfBuilder {
  static String _fmtMoney(double v) =>
      '${NumberFormat('#,##0.00').format(v)} AED';

  static String _fmtDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  static Future<Uint8List> build({
    required PayslipRecord record,
    required String watermarkKey,
  }) async {
    final doc = pw.Document();
    final subtitle =
        'Salary Slip of ${record.summary.employeeName} for ${record.periodTitle}';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Stack(
            children: [
              pw.Positioned.fill(child: PdfWatermark.layer(watermarkKey)),
              pw.Padding(
                padding: const pw.EdgeInsets.all(36),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      record.companyName,
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                    pw.Text(
                      record.companyLocation,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.SizedBox(height: 16),
                    pw.Text(
                      'Pay Slip',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(subtitle, style: const pw.TextStyle(fontSize: 11)),
                    pw.SizedBox(height: 14),
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                      children: [
                        _kv('Name', record.summary.employeeName),
                        _kv('Designation', record.summary.designation),
                        _kv('Address / Phone',
                            '${record.addressLine} · ${record.phone}'),
                        _kv('Email', record.email),
                        _kv('Identification No', record.identificationNo),
                        _kv('Reference', record.reference),
                        _kv(
                          'Bank Account',
                          record.bankAccountMasked.isEmpty
                              ? '—'
                              : record.bankAccountMasked,
                        ),
                        _kv('Date From', _fmtDate(record.dateFrom)),
                        _kv('Date To', _fmtDate(record.dateTo)),
                      ],
                    ),
                    pw.SizedBox(height: 14),
                    pw.Text(
                      'Gross: ${_fmtMoney(record.grossAed)}   Net: ${_fmtMoney(record.netAed)}',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (record.amountInWords != null) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        record.amountInWords!,
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      ),
                    ],
                    pw.SizedBox(height: 10),
                    _linesTable(record),
                    if (record.otherDetails.isNotEmpty) ...[
                      pw.SizedBox(height: 12),
                      pw.Text(
                        'Other Details',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      _otherTable(record),
                    ],
                    pw.Spacer(),
                    pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text(
                        'Authorized signature',
                        style: const pw.TextStyle(fontSize: 10),
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

  static pw.TableRow _kv(String k, String v) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(k, style: const pw.TextStyle(fontSize: 9)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(v, style: const pw.TextStyle(fontSize: 9)),
        ),
      ],
    );
  }

  static pw.Widget _linesTable(PayslipRecord record) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.1),
        1: const pw.FlexColumnWidth(2.4),
        2: const pw.FlexColumnWidth(0.9),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(1.2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _th('Code'),
            _th('Name'),
            _th('Qty'),
            _th('Amount'),
            _th('Total'),
          ],
        ),
        for (final line in record.lines)
          pw.TableRow(
            children: [
              _td(line.code),
              _td(line.name),
              _td(NumberFormat('#0.00').format(line.quantity)),
              _td(_fmtMoney(line.amountAed)),
              _td(_fmtMoney(line.totalAed)),
            ],
          ),
      ],
    );
  }

  static pw.Widget _otherTable(PayslipRecord record) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _th('Name'),
            _th('Number of Hours'),
            _th('Amount'),
          ],
        ),
        for (final o in record.otherDetails)
          pw.TableRow(
            children: [
              _td(o.name),
              _td(o.hoursLabel),
              _td(o.amountAed),
            ],
          ),
      ],
    );
  }

  static pw.Widget _th(String t) => pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: pw.Text(
          t,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
      );

  static pw.Widget _td(String t) => pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: pw.Text(t, style: const pw.TextStyle(fontSize: 9)),
      );
}
