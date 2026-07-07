import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:flutter/material.dart';

class TmFilterOption {
  const TmFilterOption({
    required this.id,
    required this.label,
    this.icon,
  });

  final String id;
  final String label;
  final IconData? icon;
}

class TmFilterChipRow extends StatelessWidget {
  const TmFilterChipRow({
    super.key,
    required this.options,
    required this.selectedId,
    required this.onChanged,
  });

  final List<TmFilterOption> options;
  final String selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in options) ...[
            _TmFilterChip(
              option: option,
              selected: option.id == selectedId,
              onTap: () => onChanged(option.id),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _TmFilterChip extends StatelessWidget {
  const _TmFilterChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final TmFilterOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg =
        selected ? TimesheetModuleColors.surface : TimesheetModuleColors.text;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        height: TimesheetModuleLayout.chipHeight,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected
              ? TimesheetModuleColors.primary
              : TimesheetModuleColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? TimesheetModuleColors.primary
                : TimesheetModuleColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (option.icon != null) ...[
              Icon(option.icon, size: 16, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              option.label,
              style: TimesheetModuleTypography.caption().copyWith(color: fg),
            ),
          ],
        ),
      ),
    );
  }
}
