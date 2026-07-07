import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/widgets/hr_management/hr_requests_gradient_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Placeholder for asset request forms (car rent, SIM, car allowance) until APIs are ready.
class HrAssetUnderPlanningScreen extends StatelessWidget {
  const HrAssetUnderPlanningScreen({
    super.key,
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return HrRequestsGradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: HrModuleColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          title,
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
                'This request type will be available in a future update.',
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

