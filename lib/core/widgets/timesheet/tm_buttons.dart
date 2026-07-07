import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:flutter/material.dart';

class TmPrimaryButton extends StatelessWidget {
  const TmPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final content = _TmButtonContent(label: label, icon: icon);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient:
            onPressed == null ? null : TimesheetModuleColors.primaryGradient,
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
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: TimesheetModuleLayout.buttonHeight,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: TimesheetModuleColors.primary,
          side: const BorderSide(color: TimesheetModuleColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(TimesheetModuleLayout.cardRadiusMd),
          ),
        ),
        child: _TmButtonContent(
          label: label,
          icon: icon,
          color: TimesheetModuleColors.primary,
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: TimesheetModuleTypography.button(color: color),
        ),
      ],
    );
  }
}
