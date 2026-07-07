import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Label / value row for request detail sections (SRD §3.3).
///
/// ```dart
/// HrDetailRow(label: 'From', value: '2026-01-10')
/// ```
class HrDetailRow extends StatelessWidget {
  const HrDetailRow({
    super.key,
    required this.label,
    this.value,
    this.valueWidget,
  }) : assert(
          valueWidget != null || value != null,
          'Provide value or valueWidget',
        );

  final String label;
  final String? value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    final display = valueWidget ??
        Text(
          (value == null || value!.isEmpty) ? '—' : value!,
          style: HrModuleTypography.body().copyWith(fontSize: 14.sp),
        );

    return Padding(
      padding: EdgeInsets.only(bottom: HrModuleLayout.formFieldSpacingV.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: HrModuleTypography.caption().copyWith(fontSize: 14.sp),
            ),
          ),
          SizedBox(width: HrModuleLayout.labelToInputGap.w),
          Expanded(
            flex: 3,
            child: display,
          ),
        ],
      ),
    );
  }
}
