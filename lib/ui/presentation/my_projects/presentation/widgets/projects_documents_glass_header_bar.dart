import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Header icon row: Dashboard | Files | Uploaded By | Search | Smart filter.
class ProjectsDocumentsGlassHeaderBar extends StatelessWidget {
  const ProjectsDocumentsGlassHeaderBar({
    super.key,
    this.activeIndex = 0,
    this.searchActive = false,
    this.hasActiveFilters = false,
    this.onItemTap,
    this.onSearchTap,
    this.onFilterTap,
  });

  /// Highlighted view slot (0 = Dashboard). -1 = no view highlight (folder drill-down).
  final int activeIndex;
  final bool searchActive;
  final bool hasActiveFilters;
  final ValueChanged<int>? onItemTap;
  final VoidCallback? onSearchTap;
  final VoidCallback? onFilterTap;

  static const _viewIcons = <IconData>[
    Icons.apps_rounded,
    Icons.description_rounded,
    Icons.person_outline_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.tw, 0, 16.tw, 10.th),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < _viewIcons.length; i++)
            _BarItem(
              icon: _viewIcons[i],
              active: activeIndex >= 0 && i == activeIndex,
              onTap: () => onItemTap?.call(i),
            ),
          _BarItem(
            icon: Icons.search_rounded,
            active: searchActive,
            onTap: onSearchTap,
          ),
          _BarItem(
            icon: Icons.tune_rounded,
            active: hasActiveFilters,
            showDot: hasActiveFilters,
            onTap: onFilterTap,
          ),
        ],
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.icon,
    required this.active,
    this.showDot = false,
    this.onTap,
  });

  final IconData icon;
  final bool active;
  final bool showDot;
  final VoidCallback? onTap;

  static final Color _tileBg =
      ProjectsDashboardTheme.white.withValues(alpha: 0.18);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.tr),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 42.tw,
          height: 42.tw,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.tr),
            color: _tileBg,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                icon,
                size: 21.tsp,
                color: active
                    ? ProjectsDashboardTheme.white
                    : ProjectsDashboardTheme.white.withValues(alpha: 0.75),
              ),
              if (showDot)
                Positioned(
                  top: 8.th,
                  right: 8.tw,
                  child: Container(
                    width: 7.tw,
                    height: 7.tw,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
