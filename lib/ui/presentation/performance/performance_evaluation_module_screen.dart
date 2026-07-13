import 'package:el_race/core/performance/models/performance_evaluation.dart';
import 'package:el_race/core/performance/providers/performance_providers.dart';
import 'package:el_race/core/theme/hr_badge_kind.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/widgets/hr_management/hr_status_badge.dart';
import 'package:el_race/core/widgets/hr_management/hr_module_glass_header.dart';
import 'package:el_race/core/widgets/performance/performance_gradient_scaffold.dart';
import 'package:el_race/ui/presentation/performance/manager_evaluation_detail_screen.dart';
import 'package:el_race/ui/presentation/performance/widgets/personal_competencies_section.dart';
import 'package:el_race/ui/presentation/performance/widgets/performance_themed_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

List<int> _evaluationYears() =>
    List.generate(6, (i) => DateTime.now().year - i);

/// Module 3 entry — employee competencies; manager/HR team list.
class PerformanceEvaluationModuleScreen extends ConsumerWidget {
  const PerformanceEvaluationModuleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isManager = ref.watch(performanceManagerModeProvider);

    if (!isManager) {
      return const _EmployeeCompetenciesOnlyScaffold();
    }
    return const _ManagerEvaluationListScaffold();
  }
}

class _EmployeeCompetenciesOnlyScaffold extends ConsumerWidget {
  const _EmployeeCompetenciesOnlyScaffold();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(employeePerformanceYearProvider);
    final async = ref.watch(myPerformanceEvaluationProvider(year));
    final years = _evaluationYears();

    return PerformanceGradientScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HrModuleGlassHeader(
            title: 'Performance',
            accentTint: HrModuleHeaderTints.performance,
          ),
          Expanded(
            child: async.when(
        data: (detail) {
          return ListView(
            padding: EdgeInsets.fromLTRB(
              HrModuleLayout.screenPaddingH.w,
              16.h,
              HrModuleLayout.screenPaddingH.w,
              32.h,
            ),
            children: [
              Text(
                'Evaluation year',
                style: HrModuleTypography.caption().copyWith(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              SizedBox(height: 6.h),
              PerformanceThemedDropdown<int>(
                value: year,
                items: years
                    .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                    .toList(),
                onChanged: (y) {
                  if (y != null) {
                    ref.read(employeePerformanceYearProvider.notifier).setYear(y);
                  }
                },
              ),
              SizedBox(height: 20.h),
              if (detail == null)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 32.h),
                  child: Center(
                    child: Text(
                      'No evaluation on file for $year.',
                      textAlign: TextAlign.center,
                      style: HrModuleTypography.body().copyWith(fontSize: 14.sp),
                    ),
                  ),
                )
              else
                PersonalCompetenciesSection(rows: detail.competencies),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Could not load evaluation',
                  style: HrModuleTypography.sectionHeading(),
                ),
                SizedBox(height: 8.h),
                Text('$e', textAlign: TextAlign.center),
                SizedBox(height: 16.h),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(myPerformanceEvaluationProvider(year)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagerEvaluationListScaffold extends ConsumerWidget {
  const _ManagerEvaluationListScaffold();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(performanceEvaluationListProvider);

    return PerformanceGradientScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HrModuleGlassHeader(
            title: 'Performance',
            accentTint: HrModuleHeaderTints.performance,
          ),
          Expanded(child: async.when(
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Text(
                'No evaluations yet.',
                style: HrModuleTypography.body(),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(performanceEvaluationListProvider.notifier).refresh();
            },
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(
                HrModuleLayout.screenPaddingH.w,
                12.h,
                HrModuleLayout.screenPaddingH.w,
                100.h,
              ),
              itemCount: list.length,
              separatorBuilder: (_, __) => SizedBox(height: 10.h),
              itemBuilder: (context, i) {
                final s = list[i];
                return _EvaluationListTile(
                  summary: s,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ManagerEvaluationDetailScreen(
                          evaluationId: s.id,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Could not load list',
                  style: HrModuleTypography.sectionHeading(),
                ),
                SizedBox(height: 8.h),
                Text('$e', textAlign: TextAlign.center),
                SizedBox(height: 16.h),
                FilledButton(
                  onPressed: () => ref
                      .read(performanceEvaluationListProvider.notifier)
                      .refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
          )),
        ],
      ),
    );
  }
}

class _EvaluationListTile extends StatelessWidget {
  const _EvaluationListTile({
    required this.summary,
    required this.onTap,
  });

  final PerformanceEvaluationSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HrModuleColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: HrModuleColors.border),
            boxShadow: HrModuleColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      summary.pepReference,
                      style: HrModuleTypography.sectionHeading().copyWith(
                            fontSize: 13.sp,
                            color: HrModuleColors.danger,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9ECEF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${summary.evaluationYear}',
                      style: HrModuleTypography.caption().copyWith(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  HrStatusBadge(
                    uiStatus: summary.uiStatus,
                    kind: HrBadgeKind.performanceEvaluation,
                    labelOverride: summary.uiStatusLabel,
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                summary.employeeName,
                style: HrModuleTypography.body().copyWith(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              SizedBox(height: 4.h),
              Text(
                '${summary.jobPosition} · ID ${summary.employeeId}',
                style: HrModuleTypography.caption().copyWith(fontSize: 12.sp),
              ),
              if (summary.finalScorePercent > 0) ...[
                SizedBox(height: 8.h),
                Text(
                  '${summary.finalScorePercent}%',
                  style: HrModuleTypography.sectionHeading().copyWith(
                        fontSize: 22.sp,
                        color: HrModuleColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
