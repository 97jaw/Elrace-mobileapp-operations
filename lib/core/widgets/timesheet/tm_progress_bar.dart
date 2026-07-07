import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:flutter/material.dart';

class TmProgressBar extends StatelessWidget {
  const TmProgressBar({
    super.key,
    required this.value,
    this.height = TimesheetModuleLayout.progressBarHeight,
  });

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final normalized = value.clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        minHeight: height,
        value: normalized,
        backgroundColor: TimesheetModuleColors.primaryTint,
        valueColor: const AlwaysStoppedAnimation<Color>(
          TimesheetModuleColors.primary,
        ),
      ),
    );
  }
}
