import 'package:el_race/core/hr_management/hr_effective_view.dart';
import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Dev role toggles — TASKS F.4 / SRD §1.4 (hide in release via call sites).
///
/// // TODO(release): Remove dev role toggle. Replace with dynamic role
/// // detection from login API booleans (is_hr_manager, is_management, is_pm).
/// // Reference: doc/Module_1_HR_Requests_TASKS.md §3.
class HrRoleDevToggleBar extends ConsumerWidget {
  const HrRoleDevToggleBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effective = ref.watch(hrEffectiveViewProvider);
    final notifier = ref.read(hrDevViewOverrideProvider.notifier);

    return Material(
      color: HrModuleColors.lightBg,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'View: ${effective.label}',
                style: HrModuleTypography.caption().copyWith(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: HrModuleColors.secondary,
                    ),
              ),
            ),
            _toggleIcon(
              tooltip: 'Force Employee',
              icon: Icons.person_outline,
              selected: effective == HrEffectiveView.employee,
              onTap: () => notifier.setOverride(HrEffectiveView.employee),
            ),
            SizedBox(width: 6.w),
            _toggleIcon(
              tooltip: 'Force Manager',
              icon: Icons.groups_outlined,
              selected: effective == HrEffectiveView.manager,
              onTap: () => notifier.setOverride(HrEffectiveView.manager),
            ),
            SizedBox(width: 6.w),
            _toggleIcon(
              tooltip: 'Force HR Manager',
              icon: Icons.business_center_outlined,
              selected: effective == HrEffectiveView.hrManager,
              onTap: () => notifier.setOverride(HrEffectiveView.hrManager),
            ),
            SizedBox(width: 6.w),
            IconButton(
              tooltip: 'Use login flags (clear override)',
              iconSize: 20.sp,
              onPressed: () => notifier.setOverride(null),
              icon: Icon(Icons.restart_alt, color: HrModuleColors.mutedText, size: 20.sp),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleIcon({
    required String tooltip,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected
            ? HrModuleColors.primary.withValues(alpha: 0.15)
            : HrModuleColors.surface,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(8.r),
            child: Icon(
              icon,
              size: 20.sp,
              color: selected ? HrModuleColors.primary : HrModuleColors.mutedText,
            ),
          ),
        ),
      ),
    );
  }
}
