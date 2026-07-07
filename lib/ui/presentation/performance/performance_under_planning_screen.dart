import 'package:el_race/core/performance/providers/performance_providers.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/widgets/performance/performance_gradient_scaffold.dart';
import 'package:el_race/ui/presentation/performance/manager_new_evaluation_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

/// Shown when manager taps New — cycle launch is next month.
class PerformanceUnderPlanningScreen extends ConsumerWidget {
  const PerformanceUnderPlanningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planningAsync = ref.watch(performancePlanningProvider);

    return PerformanceGradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: HrModuleColors.text,
        title: Text(
          'New evaluation',
          style: HrModuleTypography.pageTitle().copyWith(fontSize: 18.sp),
        ),
      ),
      body: planningAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Body(
          title: 'Under planning',
          launchLabel: _fallbackLaunchLabel(),
          message:
              'The evaluation cycle opens next month. You can prepare a draft when the cycle is active.',
          onContinue: () => _openForm(context),
        ),
        data: (info) => _Body(
          title: info.title,
          launchLabel: info.launchDateLabel,
          message: info.message,
          onContinue: () => _openForm(context),
        ),
      ),
    );
  }

  static String _fallbackLaunchLabel() {
    final now = DateTime.now();
    final next = now.month == 12
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);
    return DateFormat('dd MMMM yyyy').format(next);
  }

  void _openForm(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ManagerNewEvaluationScreen(),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.title,
    required this.launchLabel,
    required this.message,
    required this.onContinue,
  });

  final String title;
  final String launchLabel;
  final String message;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: HrModuleLayout.screenPaddingH.w),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(
            color: HrModuleColors.surface,
            borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius.r),
            border: Border.all(color: HrModuleColors.border),
            boxShadow: HrModuleColors.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.event_outlined,
                size: 56.sp,
                color: HrModuleColors.secondary,
              ),
              SizedBox(height: 16.h),
              Text(
                title,
                textAlign: TextAlign.center,
                style: HrModuleTypography.pageTitle().copyWith(
                      fontSize: 22.sp,
                      color: HrModuleColors.primary,
                    ),
              ),
              SizedBox(height: 12.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F5),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: HrModuleColors.border),
                ),
                child: Column(
                  children: [
                    Text(
                      'Launch date',
                      style: HrModuleTypography.caption().copyWith(
                            fontSize: 11.sp,
                            color: HrModuleColors.mutedText,
                          ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      launchLabel,
                      textAlign: TextAlign.center,
                      style: HrModuleTypography.sectionHeading().copyWith(
                            fontSize: 18.sp,
                            color: HrModuleColors.primary,
                          ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 14.h),
              Text(
                message,
                textAlign: TextAlign.center,
                style: HrModuleTypography.body().copyWith(
                      fontSize: 14.sp,
                      color: HrModuleColors.mutedText,
                      height: 1.45,
                    ),
              ),
              SizedBox(height: 24.h),
              FilledButton(
                onPressed: onContinue,
                style: FilledButton.styleFrom(
                  backgroundColor: HrModuleColors.primary,
                  minimumSize: Size(double.infinity, 48.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                child: Text(
                  'Prepare evaluation',
                  style: HrModuleTypography.sectionHeading().copyWith(
                        fontSize: 15.sp,
                        color: Colors.white,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
