import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Two-segment control (e.g. Requests / Dashboard).
class HrPillSegmentControl extends StatelessWidget {
  const HrPillSegmentControl({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
    this.trackColor,
  });

  final List<String> segments;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    return _PillTrack(
      trackColor: trackColor,
      child: Row(
        children: List.generate(segments.length, (i) {
          return Expanded(
            child: _PillTab(
              label: segments[i],
              selected: selectedIndex == i,
              onTap: () => onChanged(i),
            ),
          );
        }),
      ),
    );
  }
}

/// Tab row (e.g. All requests / My requests) — use with [TabController].
class HrPillTabBar extends StatelessWidget {
  const HrPillTabBar({
    super.key,
    required this.tabs,
    required this.controller,
    this.trackColor,
  });

  final List<String> tabs;
  final TabController controller;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: _PillTrack(
            child: Row(
              children: List.generate(tabs.length, (i) {
                return Expanded(
                  child: _PillTab(
                    label: tabs[i],
                    selected: controller.index == i,
                    onTap: () => controller.animateTo(i),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}

class _PillTrack extends StatelessWidget {
  const _PillTrack({required this.child, this.trackColor});

  final Widget child;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: (trackColor ?? HrModuleColors.requestsTabTrack)
            .withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: child,
    );
  }
}

class _PillTab extends StatelessWidget {
  const _PillTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: selected ? HrModuleColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected ? HrModuleColors.cardShadow : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: HrModuleTypography.caption().copyWith(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: selected ? HrModuleColors.primary : HrModuleColors.mutedText,
            ),
          ),
        ),
      ),
    );
  }
}
