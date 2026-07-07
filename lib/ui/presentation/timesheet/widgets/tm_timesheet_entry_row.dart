import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// One Odoo timesheet row for day list (work date, end time, employee, hours, break).
class TmTimesheetEntryRow extends StatelessWidget {
  const TmTimesheetEntryRow({
    super.key,
    required this.row,
    this.index,
  });

  final Map<String, dynamic> row;
  final int? index;

  static String _formatEnd(String? dateTimeEnd) {
    if (dateTimeEnd == null || dateTimeEnd.isEmpty) return '—';
    final parts = dateTimeEnd.split(' ');
    if (parts.length >= 2) return parts[1].substring(0, 5);
    return dateTimeEnd;
  }

  @override
  Widget build(BuildContext context) {
    final workDate = row['date']?.toString() ?? '—';
    final end = _formatEnd(row['date_time_end']?.toString());
    final employee = row['employee']?.toString() ??
        row['name']?.toString() ??
        'Worker';
    final hours = row['unit_amount'];
    final duration =
        hours is num ? '${hours.toStringAsFixed(1)} hrs' : '$hours';
    final breakH = row['break_time'];
    final breakLabel = breakH is num
        ? '${breakH.toStringAsFixed(1)} hr break'
        : '$breakH break';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: TimesheetModuleColors.surface,
        borderRadius:
            BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
        border: Border.all(color: TimesheetModuleColors.divider),
        boxShadow: [
          BoxShadow(
            color: TimesheetModuleColors.navy.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: TimesheetModuleColors.primary,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(TimesheetModuleLayout.cardRadiusMd),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (index != null)
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: TimesheetModuleColors.navyTint,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$index',
                          style: TimesheetModuleTypography.caption().copyWith(
                            fontWeight: FontWeight.w800,
                            color: TimesheetModuleColors.navy,
                          ),
                        ),
                      ),
                    if (index != null) const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                PhosphorIcons.clock(),
                                size: 14,
                                color: TimesheetModuleColors.navy,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '$workDate — $end',
                                  style: TimesheetModuleTypography.caption()
                                      .copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: TimesheetModuleColors.navy,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            employee,
                            style: TimesheetModuleTypography.body().copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _MetricChip(
                                label: duration,
                                icon: PhosphorIcons.timer(),
                                tone: _ChipTone.primary,
                              ),
                              const SizedBox(width: 8),
                              _MetricChip(
                                label: breakLabel,
                                icon: PhosphorIcons.coffee(),
                                tone: _ChipTone.neutral,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ChipTone { primary, neutral }

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.icon,
    required this.tone,
  });

  final String label;
  final IconData icon;
  final _ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final bg = tone == _ChipTone.primary
        ? TimesheetModuleColors.primaryTint
        : TimesheetModuleColors.navyTint;
    final fg = tone == _ChipTone.primary
        ? TimesheetModuleColors.primary
        : TimesheetModuleColors.navy;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TimesheetModuleTypography.caption().copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
