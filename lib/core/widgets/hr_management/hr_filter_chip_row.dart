import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Single-select filter chip option.
class HrFilterOption {
  const HrFilterOption({required this.id, required this.label});

  final String id;
  final String label;
}

/// Horizontally scrollable single-select chips (SRD §3.1 filters).
///
/// ```dart
/// HrFilterChipRow(
///   options: [
///     HrFilterOption(id: 'all', label: 'All'),
///     HrFilterOption(id: 'PENDING', label: 'Pending'),
///   ],
///   selectedId: 'all',
///   onChanged: (id) => ref.read(filterProvider.notifier).state = id,
/// )
/// ```
class HrFilterChipRow extends StatelessWidget {
  const HrFilterChipRow({
    super.key,
    required this.options,
    required this.selectedId,
    required this.onChanged,
  });

  final List<HrFilterOption> options;
  final String selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    // ChoiceChip has a 48px touch target by default; a shorter SizedBox caused
    // vertical overflow above filter rows on small screens.
    final rowHeight = (HrModuleLayout.chipHeight.h + 20.h).clamp(48.0, 56.0);
    return SizedBox(
      height: rowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final o = options[index];
          final selected = o.id == selectedId;
          final fg = _chipForeground(o.id, selected);
          return ChoiceChip(
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            showCheckmark: false,
            label: Text(
              o.label,
              style: HrModuleTypography.caption().copyWith(
                    fontSize: 12.sp,
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            selected: selected,
            onSelected: (_) => onChanged(o.id),
            selectedColor: _chipBackground(o.id, true),
            backgroundColor: _chipBackground(o.id, false),
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius.r),
            ),
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
          );
        },
      ),
    );
  }
}

Color _chipBackground(String id, bool selected) {
  switch (id) {
    case 'PENDING':
      return selected
          ? HrModuleColors.warning
          : HrModuleColors.warning.withValues(alpha: 0.22);
    case 'APPROVED':
      return selected
          ? HrModuleColors.success
          : HrModuleColors.success.withValues(alpha: 0.2);
    case 'REJECTED':
      return selected
          ? HrModuleColors.danger
          : HrModuleColors.danger.withValues(alpha: 0.18);
    case 'DRAFT':
      return selected
          ? HrModuleColors.secondary
          : HrModuleColors.secondary.withValues(alpha: 0.2);
    case 'all':
    default:
      return selected
          ? HrModuleColors.primary
          : HrModuleColors.primary.withValues(alpha: 0.12);
  }
}

Color _chipForeground(String id, bool selected) {
  if (selected) return Colors.white;
  switch (id) {
    case 'PENDING':
      return const Color(0xFF7A4A00);
    case 'APPROVED':
      return const Color(0xFF1B5E3A);
    case 'REJECTED':
      return const Color(0xFF6D1F2A);
    case 'DRAFT':
      return const Color(0xFF2F4A63);
    case 'all':
    default:
      return HrModuleColors.primary;
  }
}
