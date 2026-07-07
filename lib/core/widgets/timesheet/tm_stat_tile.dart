import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:flutter/material.dart';

enum TmStatBadgeTone { neutral, inProgress, completed }

/// Matches dashboard stat row height (incl. Teams tile).
const double kTmStatTileMinHeight = 108;

class TmStatTile extends StatelessWidget {
  const TmStatTile({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.onTap,
    this.badgeTone = TmStatBadgeTone.neutral,
  });

  final String value;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final TmStatBadgeTone badgeTone;

  @override
  Widget build(BuildContext context) {
    final badgeColors = _badgeColors(badgeTone);

    return InkWell(
      borderRadius: BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
      onTap: onTap,
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
        child: Container(
          constraints: const BoxConstraints(minHeight: kTmStatTileMinHeight),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: badgeColors.background,
            borderRadius:
                BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
            boxShadow: TimesheetModuleShadows.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (badgeTone != TmStatBadgeTone.neutral)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColors.chipBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badgeTone == TmStatBadgeTone.inProgress
                              ? 'Active'
                              : 'Done',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TimesheetModuleTypography.caption().copyWith(
                            color: badgeColors.chipFg,
                            fontWeight: FontWeight.w700,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ),
                  const Spacer(),
                  Icon(icon, size: 16, color: badgeColors.icon),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TimesheetModuleTypography.statValue().copyWith(
                    color: badgeColors.value,
                    fontSize: 22,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TimesheetModuleTypography.statLabel().copyWith(
                  color: badgeColors.label,
                  fontSize: 10,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _StatColors _badgeColors(TmStatBadgeTone tone) {
    switch (tone) {
      case TmStatBadgeTone.inProgress:
        return const _StatColors(
          background: TimesheetModuleColors.navyTint,
          icon: TimesheetModuleColors.navy,
          value: TimesheetModuleColors.navy,
          label: TimesheetModuleColors.text,
          chipBg: TimesheetModuleColors.navy,
          chipFg: TimesheetModuleColors.surface,
        );
      case TmStatBadgeTone.completed:
        return const _StatColors(
          background: TimesheetModuleColors.primaryTint,
          icon: TimesheetModuleColors.primary,
          value: TimesheetModuleColors.primary,
          label: TimesheetModuleColors.text,
          chipBg: TimesheetModuleColors.primaryGradientEnd,
          chipFg: TimesheetModuleColors.surface,
        );
      case TmStatBadgeTone.neutral:
        return const _StatColors(
          background: Color(0xFFE4E9F2),
          icon: TimesheetModuleColors.navy,
          value: TimesheetModuleColors.text,
          label: TimesheetModuleColors.mutedText,
          chipBg: TimesheetModuleColors.divider,
          chipFg: TimesheetModuleColors.text,
        );
    }
  }
}

class _StatColors {
  const _StatColors({
    required this.background,
    required this.icon,
    required this.value,
    required this.label,
    required this.chipBg,
    required this.chipFg,
  });

  final Color background;
  final Color icon;
  final Color value;
  final Color label;
  final Color chipBg;
  final Color chipFg;
}
