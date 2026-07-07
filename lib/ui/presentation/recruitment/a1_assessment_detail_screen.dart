import 'package:el_race/core/recruitment/providers/requisition_providers.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/widgets/hr_management/hr_detail_row.dart';
import 'package:el_race/core/widgets/recruitment/recruitment_gradient_scaffold.dart';
import 'package:el_race/core/widgets/recruitment/recruitment_star_rating.dart';
import 'package:el_race/ui/presentation/recruitment/a2_assessment_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

/// A1 — Assessment detail (SRD §4.3).
class A1AssessmentDetailScreen extends ConsumerWidget {
  const A1AssessmentDetailScreen({super.key, required this.assessmentId});

  final String assessmentId;

  Color _recColor(String r) {
    switch (r) {
      case 'Strong Hire':
        return HrModuleColors.success;
      case 'Hire':
        return const Color(0xFF2E7D5B);
      case 'No Hire':
        return HrModuleColors.warning;
      case 'Strong No Hire':
        return HrModuleColors.danger;
      default:
        return HrModuleColors.mutedText;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recruitmentAssessmentDetailProvider(assessmentId));

    return async.when(
      loading: () => RecruitmentGradientScaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Assessment'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => RecruitmentGradientScaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Assessment'),
        ),
        body: Center(child: Text('$e')),
      ),
      data: (a) {
        final avg = (a.technical +
                a.problemSolving +
                a.communication +
                a.culturalFit) /
            4.0;
        final canEdit = a.isDraft &&
            a.interviewerEmpId == a.currentUserEmpId;

        return RecruitmentGradientScaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            foregroundColor: HrModuleColors.text,
            title: Text(
              a.roundName,
              style: HrModuleTypography.sectionHeading().copyWith(fontSize: 18.sp),
            ),
            actions: [
              if (canEdit)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => A2AssessmentFormScreen(
                          candidateId: a.candidateId,
                          existingAssessmentId: a.id,
                        ),
                      ),
                    );
                  },
                  child: const Text('Edit'),
                ),
            ],
          ),
          body: ListView(
            padding: EdgeInsets.all(HrModuleLayout.screenPaddingH.w),
            children: [
              Text(
                a.candidateName,
                style: HrModuleTypography.cardTitle().copyWith(fontSize: 17.sp),
              ),
              Text(
                '${a.interviewer} · ${DateFormat('dd MMM yyyy').format(a.interviewDate)}',
                style: HrModuleTypography.caption(),
              ),
              SizedBox(height: 8.h),
              Text(
                'Overall (avg): ${avg.toStringAsFixed(1)} / 5',
                style: HrModuleTypography.body(),
              ),
              RecruitmentStarDisplay(value: avg),
              SizedBox(height: 20.h),
              Text(
                'Criteria',
                style: HrModuleTypography.sectionHeading().copyWith(fontSize: 14.sp),
              ),
              HrDetailRow(
                label: 'Technical knowledge',
                value: '${a.technical} / 5',
              ),
              HrDetailRow(
                label: 'Problem solving',
                value: '${a.problemSolving} / 5',
              ),
              HrDetailRow(
                label: 'Communication',
                value: '${a.communication} / 5',
              ),
              HrDetailRow(
                label: 'Cultural fit',
                value: '${a.culturalFit} / 5',
              ),
              SizedBox(height: 12.h),
              Text(
                'Strengths',
                style: HrModuleTypography.sectionHeading().copyWith(fontSize: 14.sp),
              ),
              Text(a.strengths, style: HrModuleTypography.body()),
              SizedBox(height: 12.h),
              Text(
                'Concerns',
                style: HrModuleTypography.sectionHeading().copyWith(fontSize: 14.sp),
              ),
              Text(a.concerns, style: HrModuleTypography.body()),
              SizedBox(height: 12.h),
              Text(
                'Recommendation',
                style: HrModuleTypography.sectionHeading().copyWith(fontSize: 14.sp),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: _recColor(a.recommendation).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  a.recommendation,
                  style: TextStyle(
                    color: _recColor(a.recommendation),
                    fontWeight: FontWeight.w600,
                    fontSize: 13.sp,
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                'Comments',
                style: HrModuleTypography.sectionHeading().copyWith(fontSize: 14.sp),
              ),
              Text(a.comments, style: HrModuleTypography.body()),
            ],
          ),
        );
      },
    );
  }
}
