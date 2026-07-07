import 'package:el_race/core/performance/models/performance_evaluation.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/widgets/hr_management/hr_employee_info_card.dart';
import 'package:el_race/ui/presentation/performance/widgets/performance_employee_profile_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Compact employee card with key fields + full profile action.
class EvaluationEmployeeSummaryCard extends StatelessWidget {
  const EvaluationEmployeeSummaryCard({
    super.key,
    required this.profile,
    this.detail,
  });

  final PerformanceEmployeeProfile profile;
  final PerformanceEvaluationDetail? detail;

  @override
  Widget build(BuildContext context) {
    final d = detail;
    final rows = <(String, String)>[
      ('Employee', profile.employeeName),
      ('ID', profile.employeeId),
      ('Position', profile.jobPosition),
      ('Department', profile.department),
      if (profile.managerName.isNotEmpty) ('Manager', profile.managerName),
      if (profile.dateOfJoining.isNotEmpty)
        ('Joined', profile.dateOfJoining),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: HrModuleColors.surface,
        borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius.r),
        border: Border.all(color: HrModuleColors.border),
        boxShadow: HrModuleColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26.r,
                backgroundColor: HrModuleColors.primary.withValues(alpha: 0.1),
                child: Text(
                  HrEmployeeInfoCard.initialsFromName(profile.employeeName),
                  style: HrModuleTypography.cardTitle().copyWith(
                        fontSize: 15.sp,
                        color: HrModuleColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Employee information',
                      style: HrModuleTypography.caption().copyWith(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: HrModuleColors.mutedText,
                          ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      profile.employeeName,
                      style: HrModuleTypography.sectionHeading().copyWith(
                            fontSize: 16.sp,
                          ),
                    ),
                    Text(
                      '${profile.jobPosition} · ${profile.employeeId}',
                      style: HrModuleTypography.caption().copyWith(fontSize: 12.sp),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          for (final (label, value) in rows.take(4))
            Padding(
              padding: EdgeInsets.only(bottom: 6.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 88.w,
                    child: Text(
                      label,
                      style: HrModuleTypography.caption().copyWith(
                            fontSize: 11.sp,
                            color: HrModuleColors.mutedText,
                          ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value.isEmpty ? '—' : value,
                      style: HrModuleTypography.body().copyWith(fontSize: 13.sp),
                    ),
                  ),
                ],
              ),
            ),
          if (d != null && d.visaExpireDate != null && d.visaExpireDate!.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 6.h),
              child: Row(
                children: [
                  SizedBox(
                    width: 88.w,
                    child: Text(
                      'Visa expiry',
                      style: HrModuleTypography.caption().copyWith(
                            fontSize: 11.sp,
                            color: HrModuleColors.mutedText,
                          ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${d.visaExpireDate} (${d.visaDaysToExpire ?? "—"} days)',
                      style: HrModuleTypography.body().copyWith(fontSize: 13.sp),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: 8.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                showPerformanceEmployeeProfileDialog(
                  context,
                  profile: profile,
                  detail: d,
                );
              },
              icon: Icon(Icons.person_outline, size: 18.sp),
              label: const Text('View full profile'),
              style: OutlinedButton.styleFrom(
                foregroundColor: HrModuleColors.primary,
                side: BorderSide(
                  color: HrModuleColors.primary.withValues(alpha: 0.45),
                ),
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
