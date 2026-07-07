import 'package:el_race/core/payslip/models/payslip_models.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Competency-style card for payslip list rows.
class PayslipRecordCard extends StatelessWidget {
  const PayslipRecordCard({
    super.key,
    required this.summary,
    required this.onTap,
    this.compact = false,
  });

  final PayslipSummary summary;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.all(compact ? 12.w : 14.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFF3F8FC),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5C7A9A).withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4.w,
                  decoration: BoxDecoration(
                    color: summary.isPending
                        ? HrModuleColors.warning
                        : HrModuleColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              summary.reference,
                              style: HrModuleTypography.sectionHeading()
                                  .copyWith(
                                    fontSize: compact ? 12.sp : 13.sp,
                                    color: HrModuleColors.danger,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          if (summary.isPending)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF4D6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Pending',
                                style: HrModuleTypography.caption().copyWith(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w700,
                                      color: HrModuleColors.warning,
                                    ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        summary.periodTitle,
                        style: HrModuleTypography.body().copyWith(
                              fontSize: compact ? 14.sp : 15.sp,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '${summary.employeeName} · ${summary.designation}',
                        style: HrModuleTypography.caption()
                            .copyWith(fontSize: 12.sp, height: 1.3),
                      ),
                      if (summary.netSalaryAed != null) ...[
                        SizedBox(height: 8.h),
                        Text(
                          'Net ${_fmt(summary.netSalaryAed!)} AED',
                          style: HrModuleTypography.sectionHeading().copyWith(
                                fontSize: compact ? 16.sp : 18.sp,
                                color: HrModuleColors.success,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _fmt(double v) {
    return v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);
  }
}
