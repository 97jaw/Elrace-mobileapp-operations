import 'package:el_race/core/utils/responsive_breakpoints.dart';
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
          style: HrModuleTypography.sectionHeading().copyWith(fontSize: 18.tsp),
        ),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: HrModuleLayout.screenPaddingH.tw),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.construction_outlined,
                size: 64.tsp,
                color: HrModuleColors.secondary,
              ),
              SizedBox(height: 20.th),
              Text(
                'Under Planning',
                textAlign: TextAlign.center,
                style: HrModuleTypography.pageTitle().copyWith(
                  fontSize: 22.tsp,
                  color: HrModuleColors.primary,
                ),
              ),
              SizedBox(height: 12.th),
              Text(
                'This request type will be available in a future update.',
                textAlign: TextAlign.center,
                style: HrModuleTypography.body().copyWith(
                  fontSize: 14.tsp,
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

