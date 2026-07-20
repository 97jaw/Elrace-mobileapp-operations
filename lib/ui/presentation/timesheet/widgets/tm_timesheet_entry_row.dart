import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// One Odoo timesheet row for day list (work date, end time, employee, hours, break).
class TmTimesheetEntryRow extends StatelessWidget {
  const TmTimesheetEntryRow({
    super.key,
    required this.row,
    this.index,
    this.homeLight = false,
  });

  final Map<String, dynamic> row;
  final int? index;

  /// Warm parchment glass card for the foreman home theme.
  final bool homeLight;

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

    const glassCard = Color(0xFFF7F2E8);
    const glassBorder = Color(0xFFE4DCCB);
    const homeOrange = Color(0xFFF97316);
    const homeInk = Color(0xFF2A2A2A);
    const homeMuted = Color(0xFF7A7062);

    final cardBg =
        homeLight ? glassCard : TimesheetModuleColors.surface;
    final cardBorder =
        homeLight ? glassBorder : TimesheetModuleColors.divider;
    final accent =
        homeLight ? homeOrange : TimesheetModuleColors.primary;
    final titleColor =
        homeLight ? homeInk : TimesheetModuleColors.navy;
    final bodyColor =
        homeLight ? homeInk : TimesheetModuleColors.text;
    final metaColor =
        homeLight ? homeMuted : TimesheetModuleColors.navy;
    final indexBg =
        homeLight ? Colors.white : TimesheetModuleColors.navyTint;
    final indexFg =
        homeLight ? homeOrange : TimesheetModuleColors.navy;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder),
        boxShadow: homeLight
            ? null
            : [
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
                color: accent,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
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
                          color: indexBg,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$index',
                          style: TimesheetModuleTypography.caption().copyWith(
                            fontWeight: FontWeight.w800,
                            color: indexFg,
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
                                color: metaColor,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '$workDate — $end',
                                  style: TimesheetModuleTypography.caption()
                                      .copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: titleColor,
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
                              color: bodyColor,
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
                                homeLight: homeLight,
                              ),
                              const SizedBox(width: 8),
                              _MetricChip(
                                label: breakLabel,
                                icon: PhosphorIcons.coffee(),
                                tone: _ChipTone.neutral,
                                homeLight: homeLight,
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
    this.homeLight = false,
  });

  final String label;
  final IconData icon;
  final _ChipTone tone;
  final bool homeLight;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (homeLight) {
      bg = Colors.white;
      fg = tone == _ChipTone.primary
          ? const Color(0xFFF97316)
          : const Color(0xFF7A7062);
    } else {
      bg = tone == _ChipTone.primary
          ? TimesheetModuleColors.primaryTint
          : TimesheetModuleColors.navyTint;
      fg = tone == _ChipTone.primary
          ? TimesheetModuleColors.primary
          : TimesheetModuleColors.navy;
    }

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
