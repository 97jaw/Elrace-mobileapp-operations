import 'package:el_race/core/performance/models/performance_evaluation.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Two-column metadata grid — first screenshot (Odoo real fields).
class EvaluationMetadataSection extends StatelessWidget {
  const EvaluationMetadataSection({
    super.key,
    required this.detail,
  });

  final PerformanceEvaluationDetail detail;

  static String _dashIfEmpty(String? v) =>
      (v == null || v.trim().isEmpty) ? '—' : v;

  @override
  Widget build(BuildContext context) {
    final left = <(String, String)>[
      ('Employee Name', detail.employeeName),
      ('Employee ID', detail.employeeId),
      ('Date Of Joining', detail.dateOfJoining),
      ('Nationality (Country)', detail.nationalityCountry),
      ('Manager', detail.managerName),
    ];
    final right = <(String, String)>[
      ('Job Position', detail.jobPosition),
      ('Length Of service', detail.lengthOfServiceLine),
      ('Visa Expire Date', _dashIfEmpty(detail.visaExpireDate)),
      ('Visa Days To Expire', _dashIfEmpty(detail.visaDaysToExpire)),
      ('Evaluation Date', detail.evaluationDateTime),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 520) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _ColumnPairs(pairs: left)),
              SizedBox(width: 16.w),
              Expanded(child: _ColumnPairs(pairs: right)),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ColumnPairs(pairs: left),
            SizedBox(height: 8.h),
            _ColumnPairs(pairs: right),
          ],
        );
      },
    );
  }
}

class _ColumnPairs extends StatelessWidget {
  const _ColumnPairs({required this.pairs});

  final List<(String, String)> pairs;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (label, value) in pairs)
          Padding(
            padding: EdgeInsets.only(bottom: 6.h),
            child: _MetaRow(label: label, value: value),
          ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            border: Border.all(color: HrModuleColors.border),
          ),
          child: Text(
            label,
            style: HrModuleTypography.caption().copyWith(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: HrModuleColors.text,
                ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: HrModuleColors.surface,
            border: Border(
              left: BorderSide(color: HrModuleColors.border),
              right: BorderSide(color: HrModuleColors.border),
              bottom: BorderSide(color: HrModuleColors.border),
            ),
          ),
          child: Text(
            value,
            style: HrModuleTypography.body().copyWith(fontSize: 13.sp),
          ),
        ),
      ],
    );
  }
}
