import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Shared hint / label styling for HR Request inputs.
InputDecoration hrRequestsInputDecoration({
  required String labelText,
  String? hintText,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    labelStyle: HrModuleTypography.caption().copyWith(
      fontSize: 11.sp,
      fontWeight: FontWeight.w600,
      color: HrModuleColors.mutedText,
    ),
    hintStyle: HrModuleTypography.caption().copyWith(
      fontSize: 12.sp,
      fontWeight: FontWeight.w400,
      color: HrModuleColors.mutedText.withValues(alpha: 0.65),
    ),
    filled: true,
    fillColor: HrModuleColors.surface,
    isDense: true,
    contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius.r),
      borderSide: BorderSide(color: HrModuleColors.border.withValues(alpha: 0.7)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius.r),
      borderSide: BorderSide(color: HrModuleColors.border.withValues(alpha: 0.7)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius.r),
      borderSide: const BorderSide(color: HrModuleColors.primary, width: 1.2),
    ),
  );
}

class HrPickerOption<T> {
  const HrPickerOption({
    required this.value,
    required this.label,
    this.icon,
    this.iconColor,
  });

  final T value;
  final String label;
  final IconData? icon;
  final Color? iconColor;
}

/// Tappable white field → bottom sheet list (fixed height, scrollable).
class HrThemedPickerField<T> extends StatelessWidget {
  const HrThemedPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.displayText,
    required this.onChanged,
    this.hint = 'Any',
  });

  final String label;
  final T? value;
  final List<HrPickerOption<T>> options;
  final String Function(T? value) displayText;
  final ValueChanged<T?> onChanged;
  final String hint;

  Future<void> _openSheet(BuildContext context) async {
    final picked = await showModalBottomSheet<HrPickerOption<T>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          margin: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
          decoration: BoxDecoration(
            color: HrModuleColors.surface,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: HrModuleColors.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 14.h, 8.w, 8.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: HrModuleTypography.sectionHeading().copyWith(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                      color: HrModuleColors.mutedText,
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: HrModuleColors.border.withValues(alpha: 0.5)),
              SizedBox(
                height: 280.h,
                child: ListView.separated(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  itemCount: options.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    indent: 56.w,
                    color: HrModuleColors.border.withValues(alpha: 0.35),
                  ),
                  itemBuilder: (context, i) {
                    final o = options[i];
                    final selected = o.value == value;
                    return Material(
                      color: selected
                          ? HrModuleColors.requestsGradientTop
                          : HrModuleColors.surface,
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          o.icon ?? Icons.circle_outlined,
                          color: o.iconColor ?? HrModuleColors.primary,
                          size: 22.sp,
                        ),
                        title: Text(
                          o.label,
                          style: HrModuleTypography.body().copyWith(
                            fontSize: 14.sp,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: HrModuleColors.text,
                          ),
                        ),
                        trailing: selected
                            ? Icon(Icons.check_circle,
                                color: HrModuleColors.primary, size: 20.sp)
                            : null,
                        onTap: () => Navigator.pop(ctx, o),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    if (picked != null) {
      onChanged(picked.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = displayText(value);
    final isHint = value == null;
    return InkWell(
      onTap: () => _openSheet(context),
      borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius.r),
      child: InputDecorator(
        decoration: hrRequestsInputDecoration(labelText: label),
        child: Row(
          children: [
            Expanded(
              child: Text(
                isHint ? hint : text,
                style: HrModuleTypography.body().copyWith(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: isHint
                      ? HrModuleColors.mutedText.withValues(alpha: 0.65)
                      : HrModuleColors.text,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: HrModuleColors.mutedText, size: 22.sp),
          ],
        ),
      ),
    );
  }
}
