import 'package:el_race/core/recruitment/models/recruitment_entities.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Five tappable pipeline stage counts — SRD §3.2.2.
class RecruitmentPipelineSummary extends StatelessWidget {
  const RecruitmentPipelineSummary({
    super.key,
    required this.counts,
    this.selectedStage,
    this.onStageTap,
  });

  final RecruitmentPipelineCounts counts;
  final String? selectedStage;
  final ValueChanged<String>? onStageTap;

  static const _keys = ['APPLIED', 'SCREENING', 'INTERVIEW', 'OFFER', 'HIRED'];
  static const _labels = ['Applied', 'Screening', 'Interview', 'Offer', 'Hired'];

  @override
  Widget build(BuildContext context) {
    final values = [
      counts.applied,
      counts.screening,
      counts.interview,
      counts.offer,
      counts.hired,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pipeline summary',
          style: HrModuleTypography.sectionHeading().copyWith(fontSize: 14.sp),
        ),
        SizedBox(height: 8.h),
        Row(
          children: List.generate(5, (i) {
            final key = _keys[i];
            final selected = selectedStage == key;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < 4 ? 6.w : 0),
                child: Material(
                  color: selected
                      ? HrModuleColors.primary.withValues(alpha: 0.12)
                      : HrModuleColors.surface,
                  borderRadius: BorderRadius.circular(8.r),
                  child: InkWell(
                    onTap: onStageTap == null ? null : () => onStageTap!(key),
                    borderRadius: BorderRadius.circular(8.r),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 4.w),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: selected
                              ? HrModuleColors.primary
                              : HrModuleColors.border,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${values[i]}',
                            style: HrModuleTypography.counterNumber().copyWith(
                                  fontSize: 18.sp,
                                  color: HrModuleColors.primary,
                                ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            _labels[i],
                            style: HrModuleTypography.caption().copyWith(
                                  fontSize: 9.sp,
                                ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
