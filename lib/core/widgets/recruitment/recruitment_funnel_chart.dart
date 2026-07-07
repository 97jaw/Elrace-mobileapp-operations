import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Horizontal funnel — D1 (Module 2 F.2). Values should be non-negative.
class RecruitmentFunnelChart extends StatelessWidget {
  const RecruitmentFunnelChart({
    super.key,
    required this.stages,
    required this.counts,
    this.onStageTap,
    this.showTitle = true,
  });

  final List<String> stages;
  final List<int> counts;
  final ValueChanged<int>? onStageTap;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final max = counts.fold<int>(0, (a, b) => a > b ? a : b);
    final denom = max > 0 ? max : 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Text(
            'Pipeline funnel',
            style: HrModuleTypography.sectionHeading().copyWith(fontSize: 14.sp),
          ),
          SizedBox(height: 10.h),
        ],
        ...List.generate(stages.length, (i) {
          final w = (counts[i] / denom).clamp(0.2, 1.0);
          return Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      stages[i],
                      style: HrModuleTypography.body().copyWith(fontSize: 12.sp),
                    ),
                    Text(
                      '${counts[i]}',
                      style: HrModuleTypography.caption().copyWith(fontSize: 12.sp),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                LayoutBuilder(
                  builder: (context, c) {
                    return GestureDetector(
                      onTap: onStageTap == null ? null : () => onStageTap!(i),
                      child: Stack(
                        children: [
                          Container(
                            height: 22.h,
                            width: c.maxWidth,
                            decoration: BoxDecoration(
                              color: HrModuleColors.border.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                          ),
                          Container(
                            height: 22.h,
                            width: c.maxWidth * w,
                            decoration: BoxDecoration(
                              color: HrModuleColors.primary.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
