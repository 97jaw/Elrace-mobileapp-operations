import 'package:el_race/core/payslip/models/payslip_models.dart';

const _companyName = 'Elrace Cos. & Gen. Cont. CO.';
const _companyLocation = 'United Arab Emirates';

/// In-memory payslip store — // TODO(backend): Odoo payslip API.
final Map<String, PayslipRecord> _records = {
  for (final r in _allMockRecords()) r.id: r,
};

List<PayslipRecord> _allMockRecords() {
  return [
    _recordIsmaeelMay2026(),
    _recordIsmaeelDec2025(),
    _recordIsmaeelNov2025(),
    _recordIsmaeelOct2025(),
    _recordIsmaeelSep2025(),
    _recordIsmaeelAug2025(),
    _recordPendingAli(),
    _recordPendingSara(),
    _recordPendingKhalid(),
    _recordPendingLayla(),
    _recordPendingOmar(),
    ..._generateExtraPending(),
  ];
}

PayslipRecord _recordIsmaeelDec2025() {
  const s = PayslipSummary(
    id: 'slip-70436',
    reference: 'SLIP/70436',
    periodTitle: 'December-2025',
    year: 2025,
    month: 12,
    employeeName: 'Ismaeel Al Mahmoud',
    designation: 'Operations Manager',
    netSalaryAed: 10000,
    isPending: false,
  );
  return PayslipRecord(
    summary: s,
    companyName: _companyName,
    companyLocation: _companyLocation,
    addressLine: 'Ismaeel Al Mahmoud',
    phone: '508209107',
    email: 'ismaeel@elrace.ae',
    identificationNo: '784197590420242',
    bankAccountMasked: '',
    dateFrom: DateTime(2025, 12, 21),
    dateTo: DateTime(2026, 1, 20),
    grossAed: 10000,
    netAed: 10000,
    amountInWords: 'Ten thousand UAE dirhams only',
    lines: const [
      PayslipLine(
          code: 'Meal', name: 'Meal Allowance', quantity: 1, amountAed: 0, totalAed: 0),
      PayslipLine(
          code: 'Medical',
          name: 'Medical Allowance',
          quantity: 1,
          amountAed: 0,
          totalAed: 0),
      PayslipLine(
          code: 'BASIC',
          name: 'Basic Salary',
          quantity: 1,
          amountAed: 10000,
          totalAed: 10000),
      PayslipLine(
          code: 'HRA',
          name: 'House Rent Allowance',
          quantity: 1,
          amountAed: 0,
          totalAed: 0),
      PayslipLine(
          code: 'DA',
          name: 'Dearness Allowance',
          quantity: 1,
          amountAed: 0,
          totalAed: 0),
      PayslipLine(
          code: 'Travel',
          name: 'Travel Allowance',
          quantity: 1,
          amountAed: 0,
          totalAed: 0),
    ],
    otherDetails: const [],
  );
}

PayslipRecord _recordIsmaeelNov2025() {
  const s = PayslipSummary(
    id: 'slip-70210',
    reference: 'SLIP/70210',
    periodTitle: 'November-2025',
    year: 2025,
    month: 11,
    employeeName: 'Ismaeel Al Mahmoud',
    designation: 'Operations Manager',
    netSalaryAed: 40000,
    isPending: false,
  );
  return PayslipRecord(
    summary: s,
    companyName: _companyName,
    companyLocation: _companyLocation,
    addressLine: 'Ismaeel Al Mahmoud',
    phone: '508209107',
    email: 'ismaeel@elrace.ae',
    identificationNo: '784197590420242',
    bankAccountMasked: '****4242',
    dateFrom: DateTime(2025, 11, 21),
    dateTo: DateTime(2025, 12, 20),
    grossAed: 40000,
    netAed: 40000,
    amountInWords: 'Forty thousand UAE dirhams only',
    lines: const [
      PayslipLine(
          code: 'HRA',
          name: 'House Rent Allowance',
          quantity: 1,
          amountAed: 0,
          totalAed: 0),
      PayslipLine(
          code: 'DA',
          name: 'Dearness Allowance',
          quantity: 1,
          amountAed: 0,
          totalAed: 0),
      PayslipLine(
          code: 'Travel',
          name: 'Travel Allowance',
          quantity: 1,
          amountAed: 0,
          totalAed: 0),
      PayslipLine(
          code: 'Other',
          name: 'Other Allowance',
          quantity: 1,
          amountAed: 30000,
          totalAed: 30000),
      PayslipLine(
          code: 'Paid',
          name: 'LS Paid Leave',
          quantity: 1,
          amountAed: 0,
          totalAed: 0),
      PayslipLine(
          code: 'INCREMENT',
          name: 'PREVIOUS INCREMENT',
          quantity: 1,
          amountAed: 0,
          totalAed: 0),
      PayslipLine(
          code: 'EARLY', name: 'Early Leave', quantity: 1, amountAed: 0, totalAed: 0),
      PayslipLine(
          code: 'ABSENCE', name: 'Absence', quantity: 1, amountAed: 0, totalAed: 0),
      PayslipLine(
          code: 'ADJ',
          name: 'Salary Adjustment',
          quantity: 1,
          amountAed: 0,
          totalAed: 0),
      PayslipLine(
          code: 'UNEMPLOYMENT',
          name: 'Unemployment Insurance',
          quantity: 1,
          amountAed: 0,
          totalAed: 0),
      PayslipLine(
          code: 'LS', name: 'Leave Salary', quantity: 1, amountAed: 0, totalAed: 0),
      PayslipLine(
          code: '1DAY',
          name: '1 Day Deduction',
          quantity: 1,
          amountAed: 0,
          totalAed: 0),
      PayslipLine(
          code: 'ANNUAL',
          name: 'Annual Leave Days',
          quantity: 1,
          amountAed: 0,
          totalAed: 0),
      PayslipLine(
          code: 'ML', name: 'Maternity Leave', quantity: 1, amountAed: 0, totalAed: 0),
      PayslipLine(
          code: 'Fines',
          name: 'Fines & Violations [Staff]',
          quantity: 1,
          amountAed: 0,
          totalAed: 0),
    ],
    otherDetails: const [],
  );
}

PayslipRecord _recordIsmaeelMay2026() {
  return _variantMonth(
    year: 2026,
    id: 'slip-71000',
    reference: 'SLIP/71000',
    month: 5,
    title: 'May-2026',
    net: 10000,
  );
}

PayslipRecord _recordIsmaeelOct2025() {
  return _variantMonth(
    year: 2025,
    id: 'slip-70001',
    reference: 'SLIP/70001',
    month: 10,
    title: 'October-2025',
    net: 9500,
  );
}

PayslipRecord _recordIsmaeelSep2025() {
  return _variantMonth(
    year: 2025,
    id: 'slip-69820',
    reference: 'SLIP/69820',
    month: 9,
    title: 'September-2025',
    net: 9500,
  );
}

PayslipRecord _recordIsmaeelAug2025() {
  return _variantMonth(
    year: 2025,
    id: 'slip-69600',
    reference: 'SLIP/69600',
    month: 8,
    title: 'August-2025',
    net: 9500,
  );
}

DateTime _periodEndDate(int year, int month) {
  if (month == 12) return DateTime(year + 1, 1, 20);
  return DateTime(year, month + 1, 20);
}

PayslipRecord _variantMonth({
  required int year,
  required String id,
  required String reference,
  required int month,
  required String title,
  required double net,
}) {
  final s = PayslipSummary(
    id: id,
    reference: reference,
    periodTitle: title,
    year: year,
    month: month,
    employeeName: 'Ismaeel Al Mahmoud',
    designation: 'Operations Manager',
    netSalaryAed: net,
    isPending: false,
  );
  return PayslipRecord(
    summary: s,
    companyName: _companyName,
    companyLocation: _companyLocation,
    addressLine: 'Ismaeel Al Mahmoud',
    phone: '508209107',
    email: 'ismaeel@elrace.ae',
    identificationNo: '784197590420242',
    bankAccountMasked: '****4242',
    dateFrom: DateTime(year, month, 21),
    dateTo: _periodEndDate(year, month),
    grossAed: net,
    netAed: net,
    lines: [
      const PayslipLine(
          code: 'BASIC',
          name: 'Basic Salary',
          quantity: 1,
          amountAed: 8000,
          totalAed: 8000),
      PayslipLine(
          code: 'Other',
          name: 'Other Allowance',
          quantity: 1,
          amountAed: net - 8000,
          totalAed: net - 8000),
    ],
    otherDetails: const [],
  );
}

PayslipRecord _recordPendingAli() {
  const s = PayslipSummary(
    id: 'slip-pend-01',
    reference: 'SLIP/PEND-901',
    periodTitle: 'January-2026',
    year: 2026,
    month: 1,
    employeeName: 'Ahmed Hassan Ali',
    designation: 'Site Engineer',
    netSalaryAed: null,
    isPending: true,
  );
  return PayslipRecord(
    summary: s,
    companyName: _companyName,
    companyLocation: _companyLocation,
    addressLine: 'Ahmed Hassan Ali',
    phone: '501234567',
    email: 'ahmed.h@elrace.ae',
    identificationNo: '784-XXXX-XXXXXXX-1',
    bankAccountMasked: '****8899',
    dateFrom: DateTime(2026, 1, 1),
    dateTo: DateTime(2026, 1, 31),
    grossAed: 0,
    netAed: 0,
    lines: const [
      PayslipLine(
          code: 'LATE', name: 'Late', quantity: 1, amountAed: 0, totalAed: 0),
      PayslipLine(
          code: 'PENSION',
          name: 'Emiratis Pension',
          quantity: 1,
          amountAed: 0,
          totalAed: 0),
      PayslipLine(
          code: 'UNPAID',
          name: 'Unpaid Days',
          quantity: 1,
          amountAed: 0,
          totalAed: 0),
      PayslipLine(
          code: 'LO', name: 'Loan', quantity: 1, amountAed: 0, totalAed: 0),
      PayslipLine(
          code: 'SAR',
          name: 'Advance Salary[Staff]',
          quantity: 1,
          amountAed: 0,
          totalAed: 0),
      PayslipLine(
          code: 'GROSS',
          name: 'Gross Employees',
          quantity: 1,
          amountAed: 40000,
          totalAed: 40000),
      PayslipLine(
          code: 'NET',
          name: 'Net Salary',
          quantity: 1,
          amountAed: 40000,
          totalAed: 40000),
    ],
    otherDetails: const [],
  );
}

PayslipRecord _recordPendingSara() {
  final r = _recordPendingAli();
  final s = PayslipSummary(
    id: 'slip-pend-02',
    reference: 'SLIP/PEND-902',
    periodTitle: 'January-2026',
    year: 2026,
    month: 1,
    employeeName: 'Sara Mohammed',
    designation: 'QS Engineer',
    netSalaryAed: null,
    isPending: true,
  );
  return PayslipRecord(
    summary: s,
    companyName: r.companyName,
    companyLocation: r.companyLocation,
    addressLine: 'Sara Mohammed',
    phone: '507777888',
    email: 'sara.m@elrace.ae',
    identificationNo: '784-XXXX-XXXXXXX-2',
    bankAccountMasked: '',
    dateFrom: DateTime(2026, 1, 1),
    dateTo: DateTime(2026, 1, 31),
    grossAed: 28000,
    netAed: 26500,
    lines: r.lines,
    otherDetails: const [],
  );
}

PayslipRecord _recordPendingKhalid() {
  return _pendingShort(
    id: 'slip-pend-03',
    ref: 'SLIP/PEND-903',
    name: 'Khalid Omar',
    role: 'Foreman',
  );
}

PayslipRecord _recordPendingLayla() {
  return _pendingShort(
    id: 'slip-pend-04',
    ref: 'SLIP/PEND-904',
    name: 'Layla Ibrahim',
    role: 'HR Officer',
  );
}

PayslipRecord _recordPendingOmar() {
  return _pendingShort(
    id: 'slip-pend-05',
    ref: 'SLIP/PEND-905',
    name: 'Omar Faisal',
    role: 'Driver',
  );
}

PayslipRecord _pendingShort({
  required String id,
  required String ref,
  required String name,
  required String role,
}) {
  final s = PayslipSummary(
    id: id,
    reference: ref,
    periodTitle: 'December-2025',
    year: 2025,
    month: 12,
    employeeName: name,
    designation: role,
    netSalaryAed: null,
    isPending: true,
  );
  return PayslipRecord(
    summary: s,
    companyName: _companyName,
    companyLocation: _companyLocation,
    addressLine: name,
    phone: '500000000',
    email: 'employee@elrace.ae',
    identificationNo: '784-XXXX-XXXXXXX-X',
    bankAccountMasked: '****0001',
    dateFrom: DateTime(2025, 12, 1),
    dateTo: DateTime(2025, 12, 31),
    grossAed: 15000,
    netAed: 14200,
    lines: const [
      PayslipLine(
          code: 'BASIC',
          name: 'Basic Salary',
          quantity: 1,
          amountAed: 12000,
          totalAed: 12000),
      PayslipLine(
          code: 'Travel',
          name: 'Travel Allowance',
          quantity: 1,
          amountAed: 3000,
          totalAed: 3000),
    ],
    otherDetails: const [],
  );
}

List<PayslipRecord> _generateExtraPending() {
  final out = <PayslipRecord>[];
  for (var i = 6; i <= 23; i++) {
    out.add(_pendingShort(
      id: 'slip-pend-extra-$i',
      ref: 'SLIP/PEND-${910 + i}',
      name: 'Pending Employee $i',
      role: 'Staff',
    ));
  }
  return out;
}

PayslipRecord? payslipRecordById(String id) => _records[id];

/// Employee (mock: Ismaeel) — published slips only, newest first.
List<PayslipSummary> payslipEmployeeRecentSummaries({int limit = 5}) {
  final mine = _records.values
      .where((r) =>
          r.summary.employeeName == 'Ismaeel Al Mahmoud' &&
          !r.summary.isPending)
      .toList();
  mine.sort((a, b) {
    final da = DateTime(a.summary.year, a.summary.month);
    final db = DateTime(b.summary.year, b.summary.month);
    return db.compareTo(da);
  });
  return mine.take(limit).map((r) => r.summary).toList();
}

PayslipRecord? payslipEmployeeForMonth(int year, int month) {
  try {
    return _records.values.firstWhere(
      (r) =>
          r.summary.employeeName == 'Ismaeel Al Mahmoud' &&
          !r.summary.isPending &&
          r.summary.year == year &&
          r.summary.month == month,
    );
  } catch (_) {
    return null;
  }
}

/// Pending queue for manager / HR review.
List<PayslipSummary> payslipPendingSummaries() {
  final p = _records.values.where((r) => r.summary.isPending).toList();
  p.sort((a, b) => a.summary.reference.compareTo(b.summary.reference));
  return p.map((r) => r.summary).toList();
}

int payslipPendingCount() => payslipPendingSummaries().length;

List<PayslipSummary> payslipPendingPage({required int page, int pageSize = 10}) {
  final all = payslipPendingSummaries();
  final start = page * pageSize;
  if (start >= all.length) return [];
  return all.sublist(start, (start + pageSize).clamp(0, all.length));
}

bool payslipPendingHasMore({required int page, int pageSize = 10}) {
  return (page + 1) * pageSize < payslipPendingCount();
}

/// Month options for employee filter: last 24 months (first day of each month).
List<DateTime> payslipMonthFilterOptions() {
  final now = DateTime.now();
  return [
    for (var i = 0; i < 24; i++) DateTime(now.year, now.month - i, 1),
  ];
}
