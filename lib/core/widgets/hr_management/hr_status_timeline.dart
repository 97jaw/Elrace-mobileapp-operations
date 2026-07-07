import 'package:el_race/core/hr_management/models/hr_request_detail.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Vertical timeline — SRD §3.3 (filled / hollow circles).
class HrStatusTimeline extends StatelessWidget {
  const HrStatusTimeline({super.key, required this.steps});

  final List<HrTimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return Text(
        'No timeline entries',
        style: HrModuleTypography.caption().copyWith(fontSize: 13.sp),
      );
    }

    return Column(
      children: List.generate(steps.length, (i) {
        final s = steps[i];
        final last = i == steps.length - 1;
        final dot = _TimelineDot(state: s.state);
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 28.w,
                child: Column(
                  children: [
                    dot,
                    if (!last)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: HrModuleColors.border,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: last ? 0 : 14.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.title,
                        style: HrModuleTypography.body()
                            .copyWith(fontSize: 14.sp, fontWeight: FontWeight.w600),
                      ),
                      if (s.subtitle != null && s.subtitle!.isNotEmpty) ...[
                        SizedBox(height: 2.h),
                        Text(
                          s.subtitle!,
                          style: HrModuleTypography.caption().copyWith(fontSize: 12.sp),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _TimelineDot extends StatelessWidget {
  const _TimelineDot({required this.state});

  final HrTimelineStepState state;

  @override
  Widget build(BuildContext context) {
    final size = 14.0;
    switch (state) {
      case HrTimelineStepState.completed:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: HrModuleColors.primary,
            shape: BoxShape.circle,
          ),
        );
      case HrTimelineStepState.current:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: HrModuleColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: HrModuleColors.primary, width: 3),
          ),
        );
      case HrTimelineStepState.pending:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: HrModuleColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: HrModuleColors.border, width: 2),
          ),
        );
    }
  }
}
