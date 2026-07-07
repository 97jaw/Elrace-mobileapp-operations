import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_layout.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/widgets/hr_management/hr_search_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Search row + filter icon; [filterPanel] expands when [filtersExpanded] is true.
class HrSearchFilterHeader extends StatelessWidget {
  const HrSearchFilterHeader({
    super.key,
    required this.hintText,
    required this.onDebouncedChanged,
    required this.filtersExpanded,
    required this.onFilterToggle,
    this.filterPanel,
    this.showFilterButton = true,
  });

  final String hintText;
  final ValueChanged<String> onDebouncedChanged;
  final bool filtersExpanded;
  final VoidCallback onFilterToggle;
  final Widget? filterPanel;
  final bool showFilterButton;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: HrSearchBar(
                hintText: hintText,
                onDebouncedChanged: onDebouncedChanged,
              ),
            ),
            if (showFilterButton) ...[
              SizedBox(width: 8.w),
              Material(
                color: HrModuleColors.surface,
                borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius.r),
                elevation: 0,
                shadowColor: Colors.transparent,
                child: InkWell(
                  onTap: onFilterToggle,
                  borderRadius: BorderRadius.circular(HrModuleLayout.cardRadius.r),
                  child: Container(
                    width: 48.w,
                    height: 48.h,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(HrModuleLayout.cardRadius.r),
                      border: Border.all(
                        color: filtersExpanded
                            ? HrModuleColors.primary
                            : HrModuleColors.border,
                        width: filtersExpanded ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.filter_list,
                          size: 22.sp,
                          color: filtersExpanded
                              ? HrModuleColors.primary
                              : HrModuleColors.mutedText,
                        ),
                        Text(
                          'Filter',
                          style: HrModuleTypography.caption().copyWith(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w600,
                            color: filtersExpanded
                                ? HrModuleColors.primary
                                : HrModuleColors.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: filterPanel ?? const SizedBox.shrink(),
          crossFadeState: filtersExpanded && filterPanel != null
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}
