import 'package:el_race/core/performance/models/performance_evaluation.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

Future<void> showPerformanceEmployeeProfileDialog(
  BuildContext context, {
  required PerformanceEmployeeProfile profile,
  PerformanceEvaluationDetail? detail,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _PerformanceEmployeeProfileDialog(
      profile: profile,
      detail: detail,
    ),
  );
}

class _PerformanceEmployeeProfileDialog extends StatelessWidget {
  const _PerformanceEmployeeProfileDialog({
    required this.profile,
    this.detail,
  });

  final PerformanceEmployeeProfile profile;
  final PerformanceEvaluationDetail? detail;

  @override
  Widget build(BuildContext context) {
    final d = detail;
    final fields = <(String, String)>[
      ('Employee name', profile.employeeName),
      ('Employee ID', profile.employeeId),
      ('Job position', profile.jobPosition),
      ('Department', profile.department),
      ('Manager', profile.managerName),
      ('Date of joining', profile.dateOfJoining),
      ('Nationality', profile.nationalityCountry),
      ('Date of birth', profile.dateOfBirth),
      ('Visa expire', profile.visaExpireDate),
      ('Visa days to expire', profile.visaDaysToExpire),
      ('Length of service', profile.lengthOfServiceLine),
      ('Work location', profile.workLocation),
      ('Email', profile.email),
      ('Phone', profile.phone),
      if (d != null) ('Evaluation date', d.evaluationDateTime),
      if (d != null) ('PEP reference', d.pepReference),
    ];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              HrModuleColors.performanceGradientTop,
              HrModuleColors.performanceGradientBottom,
            ],
          ),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Container(
          constraints: BoxConstraints(maxHeight: 520.h),
          decoration: BoxDecoration(
            color: HrModuleColors.surface,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: HrModuleColors.border),
            boxShadow: HrModuleColors.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 16.h, 8.w, 8.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Employee profile',
                        style: HrModuleTypography.sectionHeading().copyWith(
                              fontSize: 17.sp,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                  children: [
                    for (final (label, value) in fields)
                      if (value.trim().isNotEmpty)
                        _ProfileRow(label: label, value: value),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: HrModuleTypography.caption().copyWith(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: HrModuleColors.mutedText,
                ),
          ),
          SizedBox(height: 4.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: HrModuleColors.border),
            ),
            child: Text(
              value,
              style: HrModuleTypography.body().copyWith(fontSize: 13.sp),
            ),
          ),
        ],
      ),
    );
  }
}
