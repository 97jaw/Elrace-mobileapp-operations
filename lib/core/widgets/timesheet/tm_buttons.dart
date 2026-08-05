import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:flutter/material.dart';

class TmPrimaryButton extends StatelessWidget {
  const TmPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.warm = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Warm theme: orange -> charcoal gradient (foreman Timesheet screens).
  final bool warm;

  @override
  Widget build(BuildContext context) {
    final content = _TmButtonContent(label: label, icon: icon);
    final enabledGradient = warm
        ? TimesheetModuleColors.warmButtonGradient
        : TimesheetModuleColors.primaryGradient;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: onPressed == null ? null : enabledGradient,
        color: onPressed == null ? TimesheetModuleColors.divider : null,
        borderRadius: BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
        boxShadow: onPressed == null ? null : TimesheetModuleShadows.fabShadow,
      ),
      child: SizedBox(
        height: TimesheetModuleLayout.buttonHeight,
        width: double.infinity,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: TimesheetModuleColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
            ),
          ),
          child: content,
        ),
      ),
    );
  }
}

class TmSecondaryButton extends StatelessWidget {
  const TmSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.warm = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Warm theme: orange outline/text (foreman Timesheet screens).
  final bool warm;

  @override
  Widget build(BuildContext context) {
    final color =
        warm ? TimesheetModuleColors.accent : TimesheetModuleColors.primary;
    return SizedBox(
      height: TimesheetModuleLayout.buttonHeight,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          backgroundColor:
              warm ? TimesheetModuleColors.glassSurface : null,
          side: BorderSide(color: color),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
          ),
        ),
        child: _TmButtonContent(
          label: label,
          icon: icon,
          color: color,
        ),
      ),
    );
  }
}

class _TmButtonContent extends StatelessWidget {
  const _TmButtonContent({
    required this.label,
    this.icon,
    this.color = TimesheetModuleColors.surface,
  });

  final String label;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: TimesheetModuleTypography.button(color: color),
          ),
        ],
      ),
    );
  }
}
