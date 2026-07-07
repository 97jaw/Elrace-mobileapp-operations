import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/providers/timesheet_role_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class TimesheetDevRoleToggleBar extends ConsumerWidget {
  const TimesheetDevRoleToggleBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDebugMode) return const SizedBox.shrink();

    final resolution = ref.watch(tmRoleResolutionProvider);
    final override = ref.watch(tmDevRoleOverrideProvider);

    // TODO(release): Remove dev role toggle. Replace with dynamic role
    // detection from login API booleans (is_hr_manager, is_pm, is_foreman).
    // Reference: Module 6 TASKS.md §3.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DevRoleButton(
          tooltip: 'Foreman',
          icon: PhosphorIcons.hardHat(),
          selected: override == TimesheetEffectiveRole.foreman,
          onTap: () {
            ref
                .read(tmDevRoleOverrideProvider.notifier)
                .setOverride(TimesheetEffectiveRole.foreman);
            ref.read(tmDevHrWideScopeProvider.notifier).setWideScope(false);
          },
        ),
        _DevRoleButton(
          tooltip: 'PM',
          icon: PhosphorIcons.userGear(),
          selected:
              override == TimesheetEffectiveRole.pm && !resolution.hrWideScope,
          onTap: () {
            ref
                .read(tmDevRoleOverrideProvider.notifier)
                .setOverride(TimesheetEffectiveRole.pm);
            ref.read(tmDevHrWideScopeProvider.notifier).setWideScope(false);
          },
        ),
        _DevRoleButton(
          tooltip: 'HR-wide PM',
          icon: PhosphorIcons.briefcase(),
          selected:
              override == TimesheetEffectiveRole.pm && resolution.hrWideScope,
          onTap: () {
            ref
                .read(tmDevRoleOverrideProvider.notifier)
                .setOverride(TimesheetEffectiveRole.pm);
            ref.read(tmDevHrWideScopeProvider.notifier).setWideScope(true);
          },
        ),
        _DevRoleButton(
          tooltip: 'Reset',
          icon: PhosphorIcons.arrowClockwise(),
          selected: override == null,
          onTap: () {
            ref.read(tmDevRoleOverrideProvider.notifier).setOverride(null);
            ref.read(tmDevHrWideScopeProvider.notifier).setWideScope(false);
          },
        ),
      ],
    );
  }
}

class _DevRoleButton extends StatelessWidget {
  const _DevRoleButton({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: selected
                  ? TimesheetModuleColors.primary
                  : TimesheetModuleColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 18,
              color: selected
                  ? TimesheetModuleColors.surface
                  : TimesheetModuleColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}
