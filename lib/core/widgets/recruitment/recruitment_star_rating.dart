import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Read-only 1–5 stars (Module 2 F.2).
class RecruitmentStarDisplay extends StatelessWidget {
  const RecruitmentStarDisplay({super.key, required this.value, this.size});

  final double value;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final sz = size ?? 18.sp;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final f = i + 1;
        final filled = value >= f - 0.25;
        final half = !filled && value >= f - 0.75;
        IconData icon;
        if (filled) {
          icon = Icons.star_rounded;
        } else if (half) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_outline_rounded;
        }
        return Icon(icon, size: sz, color: HrModuleColors.warning);
      }),
    );
  }
}

/// Interactive 1–5 star row (Module 2 F.2 / A2).
class RecruitmentStarInput extends StatelessWidget {
  const RecruitmentStarInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TextStyle(
              fontSize: 12.sp,
              color: HrModuleColors.mutedText,
            ),
          ),
          SizedBox(height: 4.h),
        ],
        Row(
          children: List.generate(5, (i) {
            final n = i + 1;
            final on = n <= value;
            return IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () => onChanged(n),
              icon: Icon(
                on ? Icons.star_rounded : Icons.star_outline_rounded,
                color: on ? HrModuleColors.warning : HrModuleColors.border,
                size: 28.sp,
              ),
            );
          }),
        ),
      ],
    );
  }
}
