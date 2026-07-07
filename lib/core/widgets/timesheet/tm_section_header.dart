import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:flutter/material.dart';

class TmSectionHeader extends StatelessWidget {
  const TmSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onActionTap,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TimesheetModuleTypography.h2(),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onActionTap,
            child: Text(
              actionLabel ?? '',
              style: TimesheetModuleTypography.caption().copyWith(
                color: TimesheetModuleColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}
