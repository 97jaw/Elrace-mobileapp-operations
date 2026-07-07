import 'package:el_race/core/performance/providers/performance_providers.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/widgets/performance/performance_gradient_scaffold.dart';
import 'package:el_race/ui/presentation/performance/widgets/evaluation_employee_summary_card.dart';
import 'package:el_race/ui/presentation/performance/widgets/evaluation_pipeline_stepper.dart';
import 'package:el_race/ui/presentation/performance/widgets/personal_competencies_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Full evaluation form view for manager / HR.
class ManagerEvaluationDetailScreen extends ConsumerWidget {
  const ManagerEvaluationDetailScreen({
    super.key,
    required this.evaluationId,
  });

  final String evaluationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(performanceEvaluationDetailProvider(evaluationId));

    return PerformanceGradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: HrModuleColors.text,
        title: Text(
          'Evaluation',
          style: HrModuleTypography.pageTitle().copyWith(fontSize: 18.sp),
        ),
      ),
      body: async.when(
        data: (detail) {
          if (detail == null) {
            return Center(
              child: Text(
                'Evaluation not found.',
                style: HrModuleTypography.body(),
              ),
            );
          }
          return ListView(
            padding: EdgeInsets.fromLTRB(
              HrModuleLayout.screenPaddingH.w,
              12.h,
              HrModuleLayout.screenPaddingH.w,
              32.h,
            ),
            children: [
              Row(
                children: [
                  if (detail.uiStatus != 'DRAFT')
                    OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Reset to draft will be available when workflow API is enabled.',
                            ),
                          ),
                        );
                      },
                      child: const Text('RESET TO DRAFT'),
                    ),
                  const Spacer(),
                  if (detail.finalScorePercent > 0)
                    Text(
                      '${detail.finalScorePercent}%',
                      style: HrModuleTypography.sectionHeading().copyWith(
                            fontSize: 28.sp,
                            color: HrModuleColors.success,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                ],
              ),
              SizedBox(height: 12.h),
              EvaluationPipelineStepper(uiStatus: detail.uiStatus),
              SizedBox(height: 12.h),
              Text(
                detail.pepReference,
                style: HrModuleTypography.sectionHeading().copyWith(
                      fontSize: 14.sp,
                      color: HrModuleColors.danger,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              SizedBox(height: 14.h),
              EvaluationEmployeeSummaryCard(
                profile: detail.profile,
                detail: detail,
              ),
              SizedBox(height: 24.h),
              if (detail.competencies.isNotEmpty)
                PersonalCompetenciesSection(rows: detail.competencies),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Text(
              'Could not load evaluation.\n$e',
              textAlign: TextAlign.center,
              style: HrModuleTypography.body(),
            ),
          ),
        ),
      ),
    );
  }
}
