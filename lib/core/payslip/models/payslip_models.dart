library payslip_models;

/// Single salary line — Odoo-style (Code, Name, Quantity/rate, Amount, Total).
class PayslipLine {
  const PayslipLine({
    required this.code,
    required this.name,
    required this.quantity,
    required this.amountAed,
    required this.totalAed,
  });

  final String code;
  final String name;
  final double quantity;
  final double amountAed;
  final double totalAed;
}

/// Optional "Other details" table row.
class PayslipOtherDetailRow {
  const PayslipOtherDetailRow({
    required this.name,
    required this.hoursLabel,
    required this.amountAed,
  });

  final String name;
  final String hoursLabel;
  final String amountAed;
}

/// List card — employee history or manager pending queue.
class PayslipSummary {
  const PayslipSummary({
    required this.id,
    required this.reference,
    required this.periodTitle,
    required this.year,
    required this.month,
    required this.employeeName,
    required this.designation,
    this.netSalaryAed,
    this.isPending = false,
  });

  final String id;
  final String reference;
  /// e.g. "December-2025"
  final String periodTitle;
  final int year;
  final int month;
  final String employeeName;
  final String designation;
  final double? netSalaryAed;
  final bool isPending;
}

/// Full payslip document (view / PDF).
class PayslipRecord {
  const PayslipRecord({
    required this.summary,
    required this.companyName,
    required this.companyLocation,
    required this.addressLine,
    required this.phone,
    required this.email,
    required this.identificationNo,
    required this.bankAccountMasked,
    required this.dateFrom,
    required this.dateTo,
    required this.lines,
    required this.otherDetails,
    required this.grossAed,
    required this.netAed,
    this.amountInWords,
  });

  final PayslipSummary summary;
  final String companyName;
  final String companyLocation;
  final String addressLine;
  final String phone;
  final String email;
  final String identificationNo;
  /// Masked per TASKS — empty string if none.
  final String bankAccountMasked;
  final DateTime dateFrom;
  final DateTime dateTo;
  final List<PayslipLine> lines;
  final List<PayslipOtherDetailRow> otherDetails;
  final double grossAed;
  final double netAed;
  final String? amountInWords;

  String get id => summary.id;
  String get reference => summary.reference;
  String get periodTitle => summary.periodTitle;
}
