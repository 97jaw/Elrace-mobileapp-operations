import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Themed dropdown for Performance module forms.
class PerformanceThemedDropdown<T> extends StatelessWidget {
  const PerformanceThemedDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: HrModuleColors.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: HrModuleColors.border,
        ),
        boxShadow: HrModuleColors.cardShadow,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          // ignore: deprecated_member_use
          value: value,
          hint: hint != null
              ? Text(
                  hint!,
                  style: HrModuleTypography.caption().copyWith(fontSize: 13.sp),
                )
              : null,
          dropdownColor: HrModuleColors.surface,
          borderRadius: BorderRadius.circular(12.r),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: HrModuleColors.secondary,
            size: 24.sp,
          ),
          style: HrModuleTypography.body().copyWith(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: HrModuleColors.text,
              ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
