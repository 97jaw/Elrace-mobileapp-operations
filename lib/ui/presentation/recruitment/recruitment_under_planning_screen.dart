import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/widgets/recruitment/recruitment_gradient_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Placeholder for R3 create requisition until mobile submit API is live.
class RecruitmentUnderPlanningScreen extends StatelessWidget {
  const RecruitmentUnderPlanningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RecruitmentGradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: HrModuleColors.text,
        title: Text(
          'New requisition',
          style: HrModuleTypography.sectionHeading().copyWith(fontSize: 18.sp),
        ),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: HrModuleLayout.screenPaddingH.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.construction_outlined,
                size: 64.sp,
                color: HrModuleColors.secondary,
              ),
              SizedBox(height: 20.h),
              Text(
                'Under Planning',
                textAlign: TextAlign.center,
                style: HrModuleTypography.pageTitle().copyWith(
                  fontSize: 22.sp,
                  color: HrModuleColors.primary,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                'Creating recruitment requests from the app will be available in a future update. Please use Odoo for now.',
                textAlign: TextAlign.center,
                style: HrModuleTypography.body().copyWith(
                  fontSize: 14.sp,
                  color: HrModuleColors.mutedText,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
