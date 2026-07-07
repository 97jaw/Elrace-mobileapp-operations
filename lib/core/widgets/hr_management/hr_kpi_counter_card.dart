import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Square KPI tile — clean white card with colored value and label.
class HrKpiCounterCard extends StatelessWidget {
  const HrKpiCounterCard({
    super.key,
    required this.value,
    required this.label,
    this.onTap,
    this.valueColor,
    this.fillColor,
  });

  final String value;
  final String label;
  final VoidCallback? onTap;
  final Color? valueColor;

  /// Tint for value/label when not using [valueColor] directly.
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    final accent = valueColor ?? fillColor ?? HrModuleColors.primary;
    final radius = HrModuleLayout.cardRadius.r;
    final numberStyle = HrModuleTypography.counterNumber().copyWith(
      fontSize: 28.sp,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
      color: accent,
    );
    final labelStyle = HrModuleTypography.counterLabel().copyWith(
      fontSize: 11.sp,
      fontWeight: FontWeight.w700,
      color: accent.withValues(alpha: 0.88),
    );

    final child = Container(
      constraints: BoxConstraints(minHeight: 72.h),
      decoration: BoxDecoration(
        color: HrModuleColors.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: HrModuleColors.cardShadow,
      ),
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 10.h),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: numberStyle, textAlign: TextAlign.center),
          SizedBox(height: 4.h),
          Text(
            label,
            style: labelStyle,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}
