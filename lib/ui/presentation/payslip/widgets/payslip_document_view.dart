import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/core/payslip/models/payslip_models.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

/// On-screen payslip layout (reference screenshots).
class PayslipDocumentView extends StatelessWidget {
  const PayslipDocumentView({super.key, required this.record});

  final PayslipRecord record;

  static String _money(double v) =>
      '${NumberFormat('#,##0.00').format(v)} AED';

  static String _date(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.tw),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFF2F7FC),
            Color(0xFFE8F0F8),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.95),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: HrModuleColors.primary.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44.tw,
                height: 44.tw,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: HrModuleColors.primary, width: 2),
                  color: const Color(0xFFE8EEF5),
                ),
                alignment: Alignment.center,
                child: Text(
                  'RCC',
                  style: HrModuleTypography.caption().copyWith(
                        fontSize: 10.tsp,
                        fontWeight: FontWeight.w800,
                        color: HrModuleColors.primary,
                      ),
                ),
              ),
              SizedBox(width: 12.tw),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.companyName,
                      style: HrModuleTypography.sectionHeading()
                          .copyWith(fontSize: 14.tsp, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      record.companyLocation,
                      style: HrModuleTypography.caption().copyWith(fontSize: 12.tsp),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Divider(height: 24.th, color: HrModuleColors.border),
          Text(
            'Pay Slip',
            style: HrModuleTypography.pageTitle().copyWith(fontSize: 22.tsp),
          ),
          SizedBox(height: 4.th),
          Text(
            'Salary Slip of ${record.summary.employeeName} for ${record.periodTitle}',
            style: HrModuleTypography.body().copyWith(fontSize: 13.tsp, height: 1.35),
          ),
          SizedBox(height: 16.th),
          _metaGrid(),
          SizedBox(height: 18.th),
          _linesTable(),
          if (record.otherDetails.isNotEmpty) ...[
            SizedBox(height: 18.th),
            Text(
              'Other Details',
              style: HrModuleTypography.sectionHeading().copyWith(fontSize: 15.tsp),
            ),
            SizedBox(height: 8.th),
            _otherTable(),
          ],
          SizedBox(height: 20.th),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.tw),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  HrModuleColors.primary.withValues(alpha: 0.12),
                  HrModuleColors.success.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Net salary',
                  style: HrModuleTypography.caption().copyWith(fontSize: 12.tsp),
                ),
                Text(
                  _money(record.netAed),
                  style: HrModuleTypography.sectionHeading().copyWith(
                        fontSize: 28.tsp,
                        fontWeight: FontWeight.w800,
                        color: HrModuleColors.primary,
                      ),
                ),
                if (record.amountInWords != null) ...[
                  SizedBox(height: 6.th),
                  Text(
                    record.amountInWords!,
                    style: HrModuleTypography.caption().copyWith(
                          fontSize: 13.tsp,
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 16.th),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Authorized signature',
              style: HrModuleTypography.caption().copyWith(fontSize: 12.tsp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaGrid() {
    final rows = <(String, String)>[
      ('Name', record.summary.employeeName),
      ('Designation', record.summary.designation),
      ('Address', '${record.addressLine}  📞 ${record.phone}'),
      ('Email', record.email),
      ('Identification No', record.identificationNo),
      ('Reference', record.reference),
      (
        'Bank Account',
        record.bankAccountMasked.isEmpty ? '—' : record.bankAccountMasked,
      ),
      ('Date From', _date(record.dateFrom)),
      ('Date To', _date(record.dateTo)),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth > 520;
        if (wide) {
          final half = (rows.length / 2).ceil();
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _metaColumn(rows.sublist(0, half))),
              SizedBox(width: 12.tw),
              Expanded(child: _metaColumn(rows.sublist(half))),
            ],
          );
        }
        return _metaColumn(rows);
      },
    );
  }

  Widget _metaColumn(List<(String, String)> pairs) {
    return Column(
      children: [
        for (var i = 0; i < pairs.length; i++) ...[
          _metaPair(pairs[i].$1, pairs[i].$2, i),
          SizedBox(height: 8.th),
        ],
      ],
    );
  }

  static const _labelBandColors = [
    Color(0xFF1F3A5F),
    Color(0xFF2E7D5B),
    Color(0xFF1565C0),
    Color(0xFF6A1B9A),
    Color(0xFFC77700),
  ];

  Widget _metaPair(String label, String value, int index) {
    final band = _labelBandColors[index % _labelBandColors.length];
    final fill = band.withValues(alpha: 0.1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 8.th),
          decoration: BoxDecoration(
            color: band,
            borderRadius: BorderRadius.vertical(top: Radius.circular(8.tr)),
          ),
          child: Text(
            label,
            style: HrModuleTypography.caption().copyWith(
                  fontSize: 11.tsp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 10.th),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(8.tr)),
          ),
          child: Text(
            value,
            style: HrModuleTypography.body().copyWith(fontSize: 12.tsp, height: 1.35),
          ),
        ),
      ],
    );
  }

  Widget _linesTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor:
            WidgetStateProperty.all(HrModuleColors.primary.withValues(alpha: 0.15)),
        border: TableBorder.all(
          color: HrModuleColors.primary.withValues(alpha: 0.25),
        ),
        columns: const [
          DataColumn(label: Text('Code')),
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Qty')),
          DataColumn(label: Text('Amount')),
          DataColumn(label: Text('Total')),
        ],
        rows: [
          for (final line in record.lines)
            DataRow(
              cells: [
                DataCell(Text(line.code)),
                DataCell(SizedBox(width: 180.tw, child: Text(line.name))),
                DataCell(Text(NumberFormat('#0.00').format(line.quantity))),
                DataCell(Text(_money(line.amountAed))),
                DataCell(Text(_money(line.totalAed))),
              ],
            ),
        ],
      ),
    );
  }

  Widget _otherTable() {
    return DataTable(
      headingRowColor:
          WidgetStateProperty.all(HrModuleColors.success.withValues(alpha: 0.2)),
      border: TableBorder.all(
        color: HrModuleColors.success.withValues(alpha: 0.35),
      ),
      columns: const [
        DataColumn(label: Text('Name')),
        DataColumn(label: Text('Number of Hours')),
        DataColumn(label: Text('Amount')),
      ],
      rows: [
        for (final o in record.otherDetails)
          DataRow(
            cells: [
              DataCell(Text(o.name)),
              DataCell(Text(o.hoursLabel)),
              DataCell(Text(o.amountAed)),
            ],
          ),
      ],
    );
  }
}
