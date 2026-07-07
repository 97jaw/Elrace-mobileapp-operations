import 'dart:convert';
import 'dart:typed_data';

class TimesheetPrintReportResult {
  const TimesheetPrintReportResult({
    required this.fileName,
    required this.pdfBytes,
    required this.employeeCount,
  });

  final String fileName;
  final Uint8List pdfBytes;
  final int employeeCount;

  factory TimesheetPrintReportResult.fromApiData(Map<String, dynamic> data) {
    final b64 = (data['pdf_base64'] ?? '').toString();
    return TimesheetPrintReportResult(
      fileName: (data['file_name'] ?? 'timesheet_report.pdf').toString(),
      pdfBytes: base64Decode(b64),
      employeeCount: int.tryParse('${data['employee_count']}') ?? 0,
    );
  }
}
