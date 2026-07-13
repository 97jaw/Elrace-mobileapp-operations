import 'package:el_race/core/payslip/models/payslip_models.dart';
import 'package:el_race/core/payslip/providers/payslip_providers.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/widgets/hr_management/hr_module_glass_header.dart';
import 'package:el_race/core/widgets/payslip/payslip_gradient_scaffold.dart';
import 'package:el_race/ui/presentation/payslip/widgets/payslip_record_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

/// P1 — employee payslips: month filter, selected period, last five (card list).
class EmployeePayslipModuleScreen extends ConsumerWidget {
  const EmployeePayslipModuleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterMonth = ref.watch(payslipEmployeeFilterMonthProvider);
    final monthAsync = ref.watch(payslipEmployeeMonthProvider);
    final recentAsync = ref.watch(payslipEmployeeRecentProvider);
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final monthChoices = payslipMonthFilterOptions();

    return PayslipGradientScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HrModuleGlassHeader(
            title: 'Payslips',
            accentTint: HrModuleHeaderTints.payslip,
          ),
          Expanded(
            child: ListView(
          padding: EdgeInsets.fromLTRB(
            HrModuleLayout.screenPaddingH.w,
            16.h,
            HrModuleLayout.screenPaddingH.w,
            32.h,
          ),
          children: [
          Text(
            'Filters',
            style: HrModuleTypography.sectionHeading().copyWith(fontSize: 15.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            'Month',
            style: HrModuleTypography.caption().copyWith(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
          ),
          SizedBox(height: 6.h),
          InputDecorator(
            decoration: InputDecoration(
              filled: true,
              fillColor: HrModuleColors.surface,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: HrModuleColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: HrModuleColors.border),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<DateTime>(
                isExpanded: true,
                value: _coerceFilterValue(monthChoices, filterMonth),
                items: monthChoices
                    .map(
                      (d) => DropdownMenuItem(
                        value: d,
                        child: Text(DateFormat('MMMM yyyy').format(d)),
                      ),
                    )
                    .toList(),
                onChanged: (d) {
                  if (d != null) {
                    ref.read(payslipEmployeeFilterMonthProvider.notifier).setMonth(d);
                  }
                },
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                ref
                    .read(payslipEmployeeFilterMonthProvider.notifier)
                    .setMonth(currentMonthStart);
              },
              icon: const Icon(Icons.today_outlined, size: 20),
              label: const Text('Jump to current month'),
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            'Payslip for selected month',
            style: HrModuleTypography.sectionHeading().copyWith(fontSize: 15.sp),
          ),
          SizedBox(height: 10.h),
          monthAsync.when(
            data: (list) {
              final PayslipSummary? selected =
                  list.isNotEmpty ? list.first : null;
              if (selected == null) {
                return Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    color: HrModuleColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: HrModuleColors.border),
                  ),
                  child: Text(
                    'No payslip for ${DateFormat('MMMM yyyy').format(filterMonth)}.',
                    style: HrModuleTypography.body().copyWith(fontSize: 14.sp),
                  ),
                );
              }
              return PayslipRecordCard(
                summary: selected,
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Error: $e'),
          ),
          SizedBox(height: 28.h),
          Text(
            'Recent payslips',
            style: HrModuleTypography.sectionHeading().copyWith(fontSize: 15.sp),
          ),
          SizedBox(height: 6.h),
          Text(
            'Last five pay periods',
            style: HrModuleTypography.caption().copyWith(fontSize: 12.sp),
          ),
          SizedBox(height: 12.h),
          recentAsync.when(
            data: (list) {
              final selectedId = monthAsync.maybeWhen(
                data: (m) => m.isNotEmpty ? m.first.id : null,
                orElse: () => null,
              );
              final deduped = selectedId == null
                  ? list
                  : list.where((s) => s.id != selectedId).toList();
              if (deduped.isEmpty) {
                return Text(
                  'No history yet.',
                  style: HrModuleTypography.body(),
                );
              }
              return Column(
                children: [
                  for (final s in deduped) ...[
                    PayslipRecordCard(
                      summary: s,
                      compact: true,
                    ),
                    SizedBox(height: 10.h),
                  ],
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text(
              'Could not load list: $e',
              style: HrModuleTypography.body(),
            ),
          ),
        ],
            ),
          ),
        ],
      ),
    );
  }

  /// Keeps dropdown valid if month list and filter get out of sync.
  DateTime _coerceFilterValue(List<DateTime> choices, DateTime filter) {
    for (final d in choices) {
      if (d.year == filter.year && d.month == filter.month) return d;
    }
    return choices.isEmpty ? filter : choices.first;
  }
}
