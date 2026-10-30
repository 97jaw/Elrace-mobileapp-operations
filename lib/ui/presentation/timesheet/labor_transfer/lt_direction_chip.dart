import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:flutter/material.dart';

enum LtTransferDirection { sent, incoming }

class LtDirectionChip extends StatelessWidget {
  const LtDirectionChip({super.key, required this.direction});

  final LtTransferDirection direction;

  @override
  Widget build(BuildContext context) {
    final isSent = direction == LtTransferDirection.sent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isSent
            ? TimesheetModuleColors.accentTint
            : TimesheetModuleColors.navyTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isSent ? 'Sent' : 'Incoming',
        style: TextStyle(
          color: isSent
              ? TimesheetModuleColors.accent
              : TimesheetModuleColors.navy,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
