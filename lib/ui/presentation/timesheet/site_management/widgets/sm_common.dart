import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:flutter/material.dart';

/// Glassy faded card used across Site Management "Monitor Project" sections,
/// matching the warm Timesheet theme.
BoxDecoration smGlassCardDecoration({double radius = TimesheetModuleLayout.cardRadiusLg}) {
  return BoxDecoration(
    color: TimesheetModuleColors.glassSurface.withValues(alpha: 0.92),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: TimesheetModuleColors.glassBorder),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

/// Section header row: title (+ optional subtitle) on the left, trailing widget
/// (e.g. a metric pill) on the right.
class SmSectionHeader extends StatelessWidget {
  const SmSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TimesheetModuleTypography.h2().copyWith(
                  color: TimesheetModuleColors.ink,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TimesheetModuleTypography.caption().copyWith(
                    color: TimesheetModuleColors.warmMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Small accent "K hrs"-style metric pill.
class SmMetricPill extends StatelessWidget {
  const SmMetricPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: TimesheetModuleColors.warmButtonGradient,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TimesheetModuleTypography.caption().copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
