import 'package:el_race/core/payslip/models/payslip_models.dart';

PayslipSummary summaryFromJson(Map<String, dynamic> json) {
  return PayslipSummary(
    id: json['id']?.toString() ?? '',
    reference: json['reference']?.toString() ?? '',
    periodTitle: json['period_title']?.toString() ?? '',
    year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
    month: (json['month'] as num?)?.toInt() ?? DateTime.now().month,
    employeeName: json['employee_name']?.toString() ?? '',
    designation: json['designation']?.toString() ?? '',
    netSalaryAed: (json['net_salary_aed'] as num?)?.toDouble(),
    isPending: json['is_pending'] == true,
  );
}

PayslipLine lineFromJson(Map<String, dynamic> json) {
  return PayslipLine(
    code: json['code']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
    amountAed: (json['amount_aed'] as num?)?.toDouble() ?? 0,
    totalAed: (json['total_aed'] as num?)?.toDouble() ?? 0,
  );
}

PayslipRecord recordFromJson(Map<String, dynamic> json) {
  final summaryJson = json['summary'] as Map<String, dynamic>? ?? json;
  final summary = summaryFromJson(summaryJson);
  final lines = (json['lines'] as List? ?? [])
      .whereType<Map>()
      .map((e) => lineFromJson(Map<String, dynamic>.from(e)))
      .toList();

  DateTime parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return DateTime.now();
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return DateTime.now();
    }
  }

  final profile = json['profile'] as Map<String, dynamic>?;
  return PayslipRecord(
    summary: summary,
    companyName: json['company_name']?.toString() ?? '',
    companyLocation: json['company_location']?.toString() ?? '',
    addressLine: json['address_line']?.toString() ?? summary.employeeName,
    phone: json['phone']?.toString() ?? profile?['phone']?.toString() ?? '',
    email: json['email']?.toString() ?? profile?['email']?.toString() ?? '',
    identificationNo: json['identification_no']?.toString() ?? '',
    bankAccountMasked: json['bank_account_masked']?.toString() ?? '',
    dateFrom: parseDate(json['date_from']?.toString()),
    dateTo: parseDate(json['date_to']?.toString()),
    lines: lines,
    otherDetails: const [],
    grossAed: (json['gross_aed'] as num?)?.toDouble() ?? 0,
    netAed: (json['net_aed'] as num?)?.toDouble() ?? 0,
    amountInWords: json['amount_in_words']?.toString(),
  );
}
