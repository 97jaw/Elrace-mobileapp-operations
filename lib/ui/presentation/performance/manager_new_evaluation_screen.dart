import 'package:el_race/core/performance/models/performance_employee_option.dart';
import 'package:el_race/core/performance/models/performance_evaluation.dart';
import 'package:el_race/core/performance/providers/performance_providers.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/widgets/performance/performance_gradient_scaffold.dart';
import 'package:el_race/ui/presentation/performance/manager_evaluation_detail_screen.dart';
import 'package:el_race/ui/presentation/performance/widgets/evaluation_employee_summary_card.dart';
import 'package:el_race/ui/presentation/performance/widgets/evaluation_pipeline_stepper.dart';
import 'package:el_race/ui/presentation/performance/widgets/personal_competencies_section.dart';
import 'package:el_race/ui/presentation/performance/widgets/performance_themed_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Manager creates / scores a personal competencies evaluation.
class ManagerNewEvaluationScreen extends ConsumerStatefulWidget {
  const ManagerNewEvaluationScreen({super.key});

  @override
  ConsumerState<ManagerNewEvaluationScreen> createState() =>
      _ManagerNewEvaluationScreenState();
}

class _ManagerNewEvaluationScreenState
    extends ConsumerState<ManagerNewEvaluationScreen> {
  PerformanceEmployeeOption? _employee;
  late int _year;
  String? _evaluationId;
  List<int> _scores = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
  }

  Future<void> _prepareDraft() async {
    final emp = _employee;
    if (emp == null) {
      _snack('Select an employee first.');
      return;
    }
    setState(() => _busy = true);
    try {
      final client = ref.read(performanceApiClientProvider);
      final env = await client.createEvaluation(
        employeeId: int.parse(emp.id),
        year: _year,
      );
      if (!env.success || env.data == null) {
        _snack(env.error ?? 'Could not create evaluation');
        return;
      }
      final id = env.data!['id']?.toString();
      if (id == null || id.isEmpty) {
        _snack('Invalid response from server');
        return;
      }
      setState(() => _evaluationId = id);
      ref.invalidate(performanceEvaluationDetailProvider(id));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(PerformanceEvaluationDetail detail) async {
    final id = _evaluationId;
    if (id == null) {
      _snack('Prepare the draft first.');
      return;
    }
    final rows = detail.competencies;
    if (_scores.length != rows.length) {
      _scores = rows.map((r) => r.userScore).toList();
    }
    for (var i = 0; i < rows.length; i++) {
      final max = rows[i].maxScore;
      if (_scores[i] < 0 || _scores[i] > max) {
        _snack('Row ${i + 1}: score must be between 0 and $max.');
        return;
      }
    }
    setState(() => _busy = true);
    try {
      final client = ref.read(performanceApiClientProvider);
      final lines = [
        for (var i = 0; i < rows.length; i++)
          {
            'line_id': int.tryParse(rows[i].lineId) ?? rows[i].lineId,
            'user_score': _scores[i],
          },
      ];
      final env = await client.saveEvaluation(id: id, lines: lines);
      if (!env.success) {
        _snack(env.error ?? 'Save failed');
        return;
      }
      ref.invalidate(performanceEvaluationListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evaluation saved')),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ManagerEvaluationDetailScreen(evaluationId: id),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _onEmployeeChanged(PerformanceEmployeeOption? v) {
    setState(() => _employee = v);
  }

  void _noopEmployee(PerformanceEmployeeOption? _) {}

  void _onYearChanged(int? v) {
    if (v != null) setState(() => _year = v);
  }

  void _noopYear(int? _) {}

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(performanceEmployeeOptionsProvider);
    final detailAsync = _evaluationId == null
        ? null
        : ref.watch(performanceEvaluationDetailProvider(_evaluationId!));

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
      body: employeesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (employees) {
          _employee ??= employees.isNotEmpty ? employees.first : null;
          final years = List.generate(5, (i) => DateTime.now().year - i);

          return ListView(
            padding: EdgeInsets.fromLTRB(
              HrModuleLayout.screenPaddingH.w,
              12.h,
              HrModuleLayout.screenPaddingH.w,
              32.h,
            ),
            children: [
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Employee & period',
                      style: HrModuleTypography.sectionHeading()
                          .copyWith(fontSize: 15.sp),
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'Employee',
                      style: HrModuleTypography.caption().copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    SizedBox(height: 6.h),
                    PerformanceThemedDropdown<PerformanceEmployeeOption>(
                      value: _employee,
                      items: employees
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text(
                                '${e.employeeName} · ${e.employeeNumber}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged:
                          _evaluationId == null ? _onEmployeeChanged : _noopEmployee,
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'Evaluation year',
                      style: HrModuleTypography.caption().copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    SizedBox(height: 6.h),
                    PerformanceThemedDropdown<int>(
                      value: _year,
                      items: years
                          .map((y) => DropdownMenuItem(
                                value: y,
                                child: Text('$y'),
                              ))
                          .toList(),
                      onChanged:
                          _evaluationId == null ? _onYearChanged : _noopYear,
                    ),
                    if (_evaluationId == null) ...[
                      SizedBox(height: 16.h),
                      FilledButton(
                        onPressed: _busy ? null : _prepareDraft,
                        style: FilledButton.styleFrom(
                          backgroundColor: HrModuleColors.primary,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                        ),
                        child: _busy
                            ? SizedBox(
                                height: 20.h,
                                width: 20.h,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Prepare draft'),
                      ),
                    ],
                  ],
                ),
              ),
              if (detailAsync != null) ...[
                SizedBox(height: 14.h),
                detailAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text('$e'),
                  data: (detail) {
                    if (detail == null) {
                      return const Text('Evaluation not found.');
                    }
                    if (_scores.length != detail.competencies.length) {
                      _scores = detail.competencies.map((r) => r.userScore).toList();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _sectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                detail.pepReference,
                                style: HrModuleTypography.sectionHeading()
                                    .copyWith(
                                      fontSize: 14.sp,
                                      color: HrModuleColors.danger,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              SizedBox(height: 8.h),
                              EvaluationPipelineStepper(
                                uiStatus: detail.uiStatus,
                              ),
                              SizedBox(height: 14.h),
                              EvaluationEmployeeSummaryCard(
                                profile: detail.profile,
                                detail: detail,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16.h),
                        _sectionCard(
                          child: PersonalCompetenciesScoreEditor(
                            key: ValueKey(_evaluationId),
                            templateRows: detail.competencies,
                            onScoresChanged: (s) => setState(() => _scores = s),
                          ),
                        ),
                        SizedBox(height: 16.h),
                        FilledButton(
                          onPressed: _busy ? null : () => _save(detail),
                          style: FilledButton.styleFrom(
                            backgroundColor: HrModuleColors.success,
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                          ),
                          child: Text(
                            'Save evaluation',
                            style: HrModuleTypography.sectionHeading().copyWith(
                                  fontSize: 15.sp,
                                  color: Colors.white,
                                ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Material(
      color: HrModuleColors.surface,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: HrModuleColors.border),
          boxShadow: HrModuleColors.cardShadow,
        ),
        child: child,
      ),
    );
  }
}
