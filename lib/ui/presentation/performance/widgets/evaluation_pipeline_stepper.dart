import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Horizontal pipeline: DRAFT → IN PROGRESS → HR EVALUATION → COMPLETED / REJECTED.
class EvaluationPipelineStepper extends StatelessWidget {
  const EvaluationPipelineStepper({
    super.key,
    required this.uiStatus,
  });

  final String uiStatus;

  static const _labels = [
    'DRAFT',
    'IN PROGRESS',
    'HR EVALUATION',
    'COMPLETED',
    'REJECTED',
  ];

  static const _keys = [
    'DRAFT',
    'IN_PROGRESS',
    'HR_EVALUATION',
    'COMPLETED',
    'REJECTED',
  ];

  int _activeIndex() {
    final n = uiStatus.toUpperCase().replaceAll(' ', '_');
    final i = _keys.indexOf(n);
    return i >= 0 ? i : 0;
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeIndex();
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 360;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < _labels.length; i++) ...[
                if (i > 0) _Chevron(active: i <= active),
                _StepChip(
                  label: _labels[i],
                  isActive: i == active,
                  isPast: i < active,
                  compact: narrow,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 2.w),
      child: Icon(
        Icons.chevron_right,
        size: 18.sp,
        color: active ? HrModuleColors.primary : HrModuleColors.border,
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.label,
    required this.isActive,
    required this.isPast,
    required this.compact,
  });

  final String label;
  final bool isActive;
  final bool isPast;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bg = isActive
        ? HrModuleColors.primary
        : isPast
            ? const Color(0xFFE8EEF5)
            : HrModuleColors.surface;
    final fg = isActive
        ? Colors.white
        : isPast
            ? const Color(0xFF374151)
            : HrModuleColors.mutedText;
    final border = isActive
        ? HrModuleColors.primary
        : HrModuleColors.border;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6.w : 10.w,
        vertical: 6.h,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: HrModuleTypography.caption().copyWith(
              fontSize: (compact ? 9 : 10).sp,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: fg,
            ),
      ),
    );
  }
}
