import 'package:el_race/core/recruitment/models/recruitment_entities.dart';
import 'package:el_race/core/theme/hr_badge_kind.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/widgets/hr_management/hr_employee_info_card.dart';
import 'package:el_race/core/widgets/hr_management/hr_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// List row for C1 / R2 — SRD §4.1 / §3.2.2.
class RecruitmentCandidateTile extends StatelessWidget {
  const RecruitmentCandidateTile({
    super.key,
    required this.candidate,
    required this.onTap,
    this.showRequisitionLink = false,
  });

  final RecruitmentCandidate candidate;
  final VoidCallback onTap;
  final bool showRequisitionLink;

  @override
  Widget build(BuildContext context) {
    final c = candidate;
    final initials = HrEmployeeInfoCard.initialsFromName(c.fullName);
    final applied =
        '${c.appliedAt.day}/${c.appliedAt.month}/${c.appliedAt.year}';
    final scoreLine = c.avgScore != null
        ? 'Applied $applied · Avg ${c.avgScore!.toStringAsFixed(1)} / 5'
        : 'Applied $applied';
    return Material(
      color: HrModuleColors.surface,
      borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius.r),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius.r),
            border: Border.all(color: HrModuleColors.border),
            boxShadow: HrModuleColors.cardShadow,
          ),
          padding: EdgeInsets.all(12.r),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22.r,
                backgroundColor: HrModuleColors.primary.withValues(alpha: 0.12),
                child: Text(
                  initials,
                  style: HrModuleTypography.caption().copyWith(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: HrModuleColors.primary,
                      ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.fullName,
                            style: HrModuleTypography.cardTitle()
                                .copyWith(fontSize: 15.sp),
                          ),
                        ),
                        HrStatusBadge(
                          uiStatus: c.stage,
                          kind: HrBadgeKind.candidate,
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      c.email,
                      style: HrModuleTypography.caption().copyWith(fontSize: 12.sp),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      scoreLine,
                      style: HrModuleTypography.body().copyWith(fontSize: 12.sp),
                    ),
                    if (showRequisitionLink) ...[
                      SizedBox(height: 4.h),
                      Text(
                        '${c.jobTitle} · ${c.requisitionRef}',
                        style: HrModuleTypography.caption().copyWith(
                              fontSize: 11.sp,
                              color: HrModuleColors.secondary,
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
    );
  }
}
