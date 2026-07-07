import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:flutter/material.dart';

class TmTaskRow extends StatelessWidget {
  const TmTaskRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(TimesheetModuleLayout.cardPadding),
        decoration: BoxDecoration(
          color: TimesheetModuleColors.surface,
          borderRadius:
              BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
          boxShadow: TimesheetModuleShadows.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: TimesheetModuleLayout.iconTileSize,
              height: TimesheetModuleLayout.iconTileSize,
              decoration: BoxDecoration(
                color: TimesheetModuleColors.primaryTint,
                borderRadius:
                    BorderRadius.circular(TimesheetModuleLayout.cardRadiusSm),
              ),
              child: Icon(
                icon,
                color: TimesheetModuleColors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TimesheetModuleTypography.cardTitle()),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TimesheetModuleTypography.caption(),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing ?? const SizedBox.shrink(),
            ],
          ],
        ),
      ),
    );
  }
}
