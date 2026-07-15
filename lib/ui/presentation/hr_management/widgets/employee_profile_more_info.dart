import 'package:el_race/ui/presentation/hr_management/data/employee_profile_models.dart';
import 'package:el_race/ui/presentation/hr_management/data/employees_profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

abstract final class _MoreInfoPalette {
  static const Color navy = Color(0xFF1A237E);
  static const Color headerBg = Color(0xFF1F3A6E);
  static const Color softHeader = Color(0xFFEEF1F8);
  static const Color border = Color(0xFFD5DCEC);
  static const Color ink = Color(0xFF1A237E);
  static const Color muted = Color(0xFF6B7794);
  static const Color panel = Color(0xFFF8FAFD);
}

enum _MoreInfoSection { contract, documents, fleet }

/// Opens the Request more info menu, then animates nested detail sheets.
Future<void> showEmployeeProfileMoreInfo({
  required BuildContext context,
  required int employeeId,
  required String employeeName,
}) {
  final hostContext = context;
  return showModalBottomSheet<void>(
    context: hostContext,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
    ),
    builder: (ctx) => _MoreInfoMenuSheet(
      hostContext: hostContext,
      employeeId: employeeId,
      employeeName: employeeName,
    ),
  );
}

class _MoreInfoMenuSheet extends StatelessWidget {
  const _MoreInfoMenuSheet({
    required this.hostContext,
    required this.employeeId,
    required this.employeeName,
  });

  final BuildContext hostContext;
  final int employeeId;
  final String employeeName;

  static const _items = <({
    String label,
    IconData icon,
    bool locked,
    _MoreInfoSection? section,
  })>[
    (
      label: 'Contract',
      icon: Icons.description_outlined,
      locked: false,
      section: _MoreInfoSection.contract,
    ),
    (
      label: 'Documents',
      icon: Icons.folder_open_rounded,
      locked: false,
      section: _MoreInfoSection.documents,
    ),
    (
      label: 'Assets',
      icon: Icons.inventory_2_outlined,
      locked: true,
      section: null,
    ),
    (
      label: 'IT Custody',
      icon: Icons.devices_other_outlined,
      locked: true,
      section: null,
    ),
    (
      label: 'Disciplinary actions',
      icon: Icons.gavel_outlined,
      locked: true,
      section: null,
    ),
    (
      label: 'Fleet',
      icon: Icons.directions_car_outlined,
      locked: false,
      section: _MoreInfoSection.fleet,
    ),
  ];

  Future<void> _openSection(
    BuildContext sheetContext,
    _MoreInfoSection section,
  ) async {
    Navigator.of(sheetContext).pop();
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!hostContext.mounted) return;
    await showModalBottomSheet<void>(
      context: hostContext,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) => _MoreInfoDetailSheet(
        hostContext: hostContext,
        employeeId: employeeId,
        employeeName: employeeName,
        section: section,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.58;
    return SafeArea(
      child: SizedBox(
        height: maxH,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
              child: Column(
                children: [
                  Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'Request more info',
                    style: GoogleFonts.poppins(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: _MoreInfoPalette.navy,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    employeeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      color: _MoreInfoPalette.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _MoreInfoPalette.border),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(8.w, 4.h, 8.w, 12.h),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  color: _MoreInfoPalette.border,
                ),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return ListTile(
                    enabled: !item.locked,
                    onTap: item.locked || item.section == null
                        ? null
                        : () => _openSection(context, item.section!),
                    leading: Icon(
                      item.locked
                          ? Icons.lock_outline_rounded
                          : item.icon,
                      color: item.locked
                          ? _MoreInfoPalette.muted.withValues(alpha: 0.7)
                          : _MoreInfoPalette.navy,
                      size: 20.sp,
                    ),
                    title: Text(
                      item.label,
                      style: GoogleFonts.poppins(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: item.locked
                            ? _MoreInfoPalette.muted
                            : _MoreInfoPalette.ink,
                      ),
                    ),
                    trailing: item.locked
                        ? Text(
                            'Soon',
                            style: GoogleFonts.poppins(
                              fontSize: 11.sp,
                              color: _MoreInfoPalette.muted,
                            ),
                          )
                        : Icon(
                            Icons.chevron_right_rounded,
                            color: _MoreInfoPalette.navy.withValues(alpha: 0.55),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreInfoDetailSheet extends StatefulWidget {
  const _MoreInfoDetailSheet({
    required this.hostContext,
    required this.employeeId,
    required this.employeeName,
    required this.section,
  });

  final BuildContext hostContext;
  final int employeeId;
  final String employeeName;
  final _MoreInfoSection section;

  @override
  State<_MoreInfoDetailSheet> createState() => _MoreInfoDetailSheetState();
}

class _MoreInfoDetailSheetState extends State<_MoreInfoDetailSheet> {
  final _repo = EmployeesProfileRepository();
  bool _loading = true;
  String? _error;
  EmployeeContractDetail? _contract;
  EmployeeDocumentsDetail? _documents;
  EmployeeFleetDetail? _fleet;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      switch (widget.section) {
        case _MoreInfoSection.contract:
          final data = await _repo.fetchContract(widget.employeeId);
          if (!mounted) return;
          setState(() {
            _contract = data;
            _loading = false;
          });
          return;
        case _MoreInfoSection.documents:
          final data = await _repo.fetchDocuments(widget.employeeId);
          if (!mounted) return;
          setState(() {
            _documents = data;
            _loading = false;
          });
          return;
        case _MoreInfoSection.fleet:
          final data = await _repo.fetchFleet(widget.employeeId);
          if (!mounted) return;
          setState(() {
            _fleet = data;
            _loading = false;
          });
          return;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e'.replaceFirst('Exception: ', '');
      });
    }
  }

  String get _title {
    switch (widget.section) {
      case _MoreInfoSection.contract:
        return 'Contract';
      case _MoreInfoSection.documents:
        return 'Documents';
      case _MoreInfoSection.fleet:
        return 'Fleet';
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.86;
    return SafeArea(
      child: SizedBox(
        height: maxH,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(8.w, 8.h, 12.w, 8.h),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () async {
                      final host = widget.hostContext;
                      Navigator.of(context).pop();
                      await Future<void>.delayed(
                        const Duration(milliseconds: 180),
                      );
                      if (!host.mounted) return;
                      await showEmployeeProfileMoreInfo(
                        context: host,
                        employeeId: widget.employeeId,
                        employeeName: widget.employeeName,
                      );
                    },
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: _MoreInfoPalette.navy,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title,
                          style: GoogleFonts.poppins(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            color: _MoreInfoPalette.navy,
                          ),
                        ),
                        Text(
                          widget.employeeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 11.5.sp,
                            color: _MoreInfoPalette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _MoreInfoPalette.border),
            Expanded(
              child: _loading
                  ? const _SheetSpinner()
                  : _error != null
                      ? _SheetError(message: _error!, onRetry: _load)
                      : switch (widget.section) {
                          _MoreInfoSection.contract => _ContractBody(
                              detail: _contract!,
                            ),
                          _MoreInfoSection.documents => _DocumentsBody(
                              detail: _documents!,
                            ),
                          _MoreInfoSection.fleet => _FleetBody(
                              detail: _fleet!,
                            ),
                        },
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetSpinner extends StatelessWidget {
  const _SheetSpinner();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28.w,
            height: 28.w,
            child: const CircularProgressIndicator(
              strokeWidth: 2.4,
              color: _MoreInfoPalette.navy,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            'Loading…',
            style: GoogleFonts.poppins(
              fontSize: 12.5.sp,
              color: _MoreInfoPalette.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetError extends StatelessWidget {
  const _SheetError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13.sp,
                color: _MoreInfoPalette.muted,
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Retry',
                style: GoogleFonts.poppins(
                  color: _MoreInfoPalette.navy,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmtMoney(num value) {
  return NumberFormat('#,##0.00').format(value);
}

String _fmtDateDmy(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '—';
  final text = raw.trim().split(' ').first.split('T').first;
  final parts = text.split('-');
  if (parts.length == 3) {
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }
  try {
    final d = DateTime.parse(raw);
    return DateFormat('dd/MM/yyyy').format(d);
  } catch (_) {
    return text;
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.darkHeader = false,
  });

  final String title;
  final Widget child;
  final bool darkHeader;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: _MoreInfoPalette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            color: darkHeader
                ? _MoreInfoPalette.headerBg
                : _MoreInfoPalette.softHeader,
            child: Text(
              title.toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: darkHeader ? Colors.white : _MoreInfoPalette.navy,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _ContractBody extends StatelessWidget {
  const _ContractBody({required this.detail});

  final EmployeeContractDetail detail;

  @override
  Widget build(BuildContext context) {
    final emp = detail.employee;
    final salary = detail.salary;
    final salaryRows = salary == null
        ? const <(String, double, String)>[]
        : <(String, double, String)>[
            ('Basic Salary', salary.basicSalary, '/ month'),
            ('Allowance Total', salary.allowanceTotal, '/ month'),
            ('Timesheet Cost', salary.timesheetCost, '/ per hour'),
            ('Benefits', salary.benefits, '/ year'),
            ('Total Salary', salary.totalSalary, '/ month'),
          ];

    return ListView(
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 16.h),
      children: [
        _MiniEmployeeCard(employee: emp),
        SizedBox(height: 10.h),
        _SectionCard(
          title: 'Salary Details',
          child: salaryRows.isEmpty
              ? _EmptyNote('No open contract salary found.')
              : Column(
                  children: [
                    for (var i = 0; i < salaryRows.length; i++) ...[
                      _SalaryRow(
                        label: salaryRows[i].$1,
                        amount: salaryRows[i].$2,
                        unit: salaryRows[i].$3,
                        emphasize: i == salaryRows.length - 1,
                      ),
                      if (i < salaryRows.length - 1)
                        const Divider(
                          height: 1,
                          color: _MoreInfoPalette.border,
                        ),
                    ],
                  ],
                ),
        ),
        SizedBox(height: 10.h),
        _SectionCard(
          title: 'Increment History',
          darkHeader: true,
          child: detail.incrementHistory.isEmpty
              ? _EmptyNote('No increment history.')
              : Column(
                  children: [
                    _HistoryHeader(columns: const ['DATE', 'AMOUNT']),
                    for (final row in detail.incrementHistory)
                      _HistoryDataRow(
                        left: _fmtDateDmy(row.date),
                        right: _fmtMoney(row.amount),
                      ),
                  ],
                ),
        ),
        SizedBox(height: 10.h),
        _SectionCard(
          title: 'Bonuses',
          darkHeader: true,
          child: detail.bonuses.isEmpty
              ? _EmptyNote('No bonuses.')
              : Column(
                  children: [
                    _HistoryHeader(columns: const ['AMOUNT', 'DATE']),
                    for (final row in detail.bonuses)
                      _HistoryDataRow(
                        left: _fmtMoney(row.amount),
                        right: _fmtDateDmy(row.date),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _MiniEmployeeCard extends StatelessWidget {
  const _MiniEmployeeCard({required this.employee});

  final EmployeeProfileMini employee;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if ((employee.empId).isNotEmpty) 'File ID ${employee.empId}',
      if ((employee.jobTitle ?? '').trim().isNotEmpty) employee.jobTitle!.trim(),
      if ((employee.department ?? '').trim().isNotEmpty)
        employee.department!.trim(),
      if ((employee.section ?? '').trim().isNotEmpty) employee.section!.trim(),
    ].join(' · ');

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: _MoreInfoPalette.panel,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: _MoreInfoPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            employee.name,
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: _MoreInfoPalette.navy,
            ),
          ),
          if (meta.isNotEmpty) ...[
            SizedBox(height: 4.h),
            Text(
              meta,
              style: GoogleFonts.poppins(
                fontSize: 11.5.sp,
                color: _MoreInfoPalette.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SalaryRow extends StatelessWidget {
  const _SalaryRow({
    required this.label,
    required this.amount,
    required this.unit,
    this.emphasize = false,
  });

  final String label;
  final double amount;
  final String unit;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: emphasize ? const Color(0xFFEEF3FF) : Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 11.h),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w700,
                color: _MoreInfoPalette.ink,
              ),
            ),
          ),
          Container(width: 1, height: 18.h, color: _MoreInfoPalette.border),
          Expanded(
            flex: 4,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              child: Text(
                _fmtMoney(amount),
                style: GoogleFonts.poppins(
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w700,
                  color: _MoreInfoPalette.ink,
                ),
              ),
            ),
          ),
          Container(width: 1, height: 18.h, color: _MoreInfoPalette.border),
          Expanded(
            flex: 3,
            child: Padding(
              padding: EdgeInsets.only(left: 10.w),
              child: Text(
                unit,
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                  color: _MoreInfoPalette.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({required this.columns});

  final List<String> columns;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _MoreInfoPalette.headerBg,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++)
            Expanded(
              child: Text(
                columns[i],
                textAlign: i == columns.length - 1
                    ? TextAlign.right
                    : TextAlign.left,
                style: GoogleFonts.poppins(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryDataRow extends StatelessWidget {
  const _HistoryDataRow({
    required this.left,
    required this.right,
    this.leftAlignRight = false,
  });

  final String left;
  final String right;
  final bool leftAlignRight;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _MoreInfoPalette.border),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              left,
              textAlign: leftAlignRight ? TextAlign.right : TextAlign.left,
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: _MoreInfoPalette.ink,
              ),
            ),
          ),
          Expanded(
            child: Text(
              right,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: _MoreInfoPalette.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 16.h),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 12.sp,
          color: _MoreInfoPalette.muted,
        ),
      ),
    );
  }
}

class _DocumentsBody extends StatelessWidget {
  const _DocumentsBody({required this.detail});

  final EmployeeDocumentsDetail detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 8.h),
          child: Row(
            children: [
              _SummaryChip(label: 'All', value: '${detail.total}'),
              SizedBox(width: 8.w),
              _SummaryChip(label: 'Family', value: '${detail.family}'),
              SizedBox(width: 8.w),
              _SummaryChip(label: 'Employee', value: '${detail.nonFamily}'),
            ],
          ),
        ),
        Expanded(
          child: detail.documents.isEmpty
              ? Center(
                  child: Text(
                    'No documents found.',
                    style: GoogleFonts.poppins(
                      fontSize: 13.sp,
                      color: _MoreInfoPalette.muted,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 16.h),
                  itemCount: detail.documents.length,
                  separatorBuilder: (_, __) => SizedBox(height: 8.h),
                  itemBuilder: (context, index) {
                    final doc = detail.documents[index];
                    return Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: _MoreInfoPalette.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  doc.name.isEmpty
                                      ? (doc.documentType ?? 'Document')
                                      : doc.name,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w700,
                                    color: _MoreInfoPalette.ink,
                                  ),
                                ),
                              ),
                              _DocStatusChip(status: doc.status),
                            ],
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            [
                              if ((doc.documentType ?? '').isNotEmpty)
                                doc.documentType!,
                              doc.isFamily ? 'Family' : 'Employee',
                              if ((doc.expiryDate ?? '').isNotEmpty)
                                'Exp ${_fmtDateDmy(doc.expiryDate)}',
                            ].join(' · '),
                            style: GoogleFonts.poppins(
                              fontSize: 11.5.sp,
                              color: _MoreInfoPalette.muted,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        decoration: BoxDecoration(
          color: _MoreInfoPalette.softHeader,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: _MoreInfoPalette.border),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: _MoreInfoPalette.navy,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10.5.sp,
                color: _MoreInfoPalette.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocStatusChip extends StatelessWidget {
  const _DocStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    switch (status) {
      case 'expired':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        label = 'Expired';
      case 'expiry_soon':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        label = 'Soon';
      default:
        bg = const Color(0xFFE0E7FF);
        fg = _MoreInfoPalette.navy;
        label = 'Valid';
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _FleetBody extends StatelessWidget {
  const _FleetBody({required this.detail});

  final EmployeeFleetDetail detail;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 16.h),
      children: [
        _MiniEmployeeCard(employee: detail.employee),
        SizedBox(height: 10.h),
        _SectionCard(
          title: 'Fleet Vehicles',
          darkHeader: true,
          child: detail.vehicles.isEmpty
              ? _EmptyNote('No fleet vehicles assigned.')
              : Column(
                  children: [
                    _HistoryHeader(columns: const ['MODEL', 'LICENSE PLATE']),
                    for (final v in detail.vehicles)
                      _HistoryDataRow(
                        left: (v.model ?? v.name ?? '—').trim().isEmpty
                            ? '—'
                            : (v.model ?? v.name)!,
                        right: (v.licensePlate ?? '').trim().isEmpty
                            ? '—'
                            : v.licensePlate!,
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
