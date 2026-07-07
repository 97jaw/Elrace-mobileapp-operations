import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class TmGreetingHeader extends StatelessWidget {
  const TmGreetingHeader({
    super.key,
    required this.name,
    this.greeting = 'Hello,',
    this.onBellTap,
  });

  final String name;
  final String greeting;
  final VoidCallback? onBellTap;

  @override
  Widget build(BuildContext context) {
    final initial =
        name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();

    return Row(
      children: [
        Container(
          width: TimesheetModuleLayout.headerAvatarSize,
          height: TimesheetModuleLayout.headerAvatarSize,
          decoration: BoxDecoration(
            color: TimesheetModuleColors.primaryTint,
            shape: BoxShape.circle,
            border: Border.all(color: TimesheetModuleColors.surface, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: TimesheetModuleTypography.h2().copyWith(
              color: TimesheetModuleColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: TimesheetModuleTypography.caption()),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TimesheetModuleTypography.display(),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onBellTap,
          icon: Icon(
            PhosphorIcons.bell(),
            color: TimesheetModuleColors.text,
          ),
        ),
      ],
    );
  }
}
