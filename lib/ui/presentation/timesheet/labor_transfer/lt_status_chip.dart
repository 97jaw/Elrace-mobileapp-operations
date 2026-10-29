import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/labor_transfer_models.dart';
import 'package:flutter/material.dart';

class LtStatusChip extends StatelessWidget {
  const LtStatusChip({super.key, required this.state});

  final LaborTransferState state;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (state) {
      LaborTransferState.pending => (
          const Color(0xFFFFF3DC),
          TimesheetModuleColors.warning,
        ),
      LaborTransferState.partiallyApproved => (
          const Color(0xFFE8EEF8),
          const Color(0xFF4A6FA5),
        ),
      LaborTransferState.approved => (
          TimesheetModuleColors.navyTint,
          TimesheetModuleColors.success,
        ),
      LaborTransferState.rejected => (
          const Color(0xFFFDECEC),
          TimesheetModuleColors.danger,
        ),
      LaborTransferState.cancelled => (
          TimesheetModuleColors.divider,
          TimesheetModuleColors.mutedText,
        ),
      LaborTransferState.draft || LaborTransferState.unknown => (
          TimesheetModuleColors.divider,
          TimesheetModuleColors.mutedText,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: state == LaborTransferState.partiallyApproved
            ? Border.all(color: const Color(0xFFC9A227).withValues(alpha: 0.55))
            : null,
      ),
      child: Text(
        state.label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
