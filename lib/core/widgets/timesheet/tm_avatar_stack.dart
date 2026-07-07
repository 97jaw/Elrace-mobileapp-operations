import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:flutter/material.dart';

class TmAvatarStack extends StatelessWidget {
  const TmAvatarStack({
    super.key,
    required this.labels,
    this.maxVisible = 3,
    this.size = TimesheetModuleLayout.avatarSize,
  });

  final List<String> labels;
  final int maxVisible;
  final double size;

  @override
  Widget build(BuildContext context) {
    final visibleLabels = labels.take(maxVisible).toList();
    final extraCount = labels.length - visibleLabels.length;

    return SizedBox(
      width: (visibleLabels.length + (extraCount > 0 ? 1 : 0)) * (size * 0.72),
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < visibleLabels.length; i++)
            Positioned(
              left: i * (size * 0.62),
              child: _TmAvatarBubble(
                label: visibleLabels[i],
                size: size,
              ),
            ),
          if (extraCount > 0)
            Positioned(
              left: visibleLabels.length * (size * 0.62),
              child: _TmAvatarBubble(
                label: '+$extraCount',
                size: size,
                isCount: true,
              ),
            ),
        ],
      ),
    );
  }
}

class _TmAvatarBubble extends StatelessWidget {
  const _TmAvatarBubble({
    required this.label,
    required this.size,
    this.isCount = false,
  });

  final String label;
  final double size;
  final bool isCount;

  @override
  Widget build(BuildContext context) {
    final text = isCount
        ? label
        : label.trim().isEmpty
            ? '?'
            : label.trim().characters.first.toUpperCase();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isCount
            ? TimesheetModuleColors.text
            : TimesheetModuleColors.primaryTint,
        shape: BoxShape.circle,
        border: Border.all(
          color: TimesheetModuleColors.surface,
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TimesheetModuleTypography.caption().copyWith(
          color: isCount
              ? TimesheetModuleColors.surface
              : TimesheetModuleColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
