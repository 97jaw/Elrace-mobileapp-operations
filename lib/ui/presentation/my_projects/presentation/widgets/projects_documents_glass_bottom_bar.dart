import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Bottom bar: Refresh | Files | Dashboard (center) | Uploaded By | AI
class ProjectsDocumentsGlassBottomBar extends StatelessWidget {
  const ProjectsDocumentsGlassBottomBar({
    super.key,
    this.activeIndex = 2,
    this.onItemTap,
  });

  /// Highlighted view slot (2 = Dashboard). -1 = no view highlight (folder drill-down).
  final int activeIndex;
  final ValueChanged<int>? onItemTap;

  static const _icons = <IconData>[
    Icons.sync_rounded,
    Icons.description_rounded,
    Icons.apps_rounded,
    Icons.person_outline_rounded,
    Icons.auto_awesome_rounded,
  ];

  /// Action slots never show as active.
  static const _actionSlots = {0, 4};

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ColoredBox(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16.w,
          0,
          16.w,
          bottomInset + (bottomInset > 0 ? 8.h : 12.h),
        ),
        child: Container(
          height: 58.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30.r),
            color: Colors.black.withValues(alpha: 0.58),
            border: Border.all(
              color: ProjectsDashboardTheme.white.withValues(alpha: 0.14),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.38),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_icons.length, (index) {
              final isAction = _actionSlots.contains(index);
              final isAi = index == 4;
              final active = !isAction &&
                  activeIndex >= 0 &&
                  index == activeIndex;
              return _BarItem(
                icon: _icons[index],
                active: active,
                isAi: isAi,
                onTap: () => onItemTap?.call(index),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.icon,
    required this.active,
    this.isAi = false,
    this.onTap,
  });

  final IconData icon;
  final bool active;
  final bool isAi;
  final VoidCallback? onTap;

  static const _aiGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C3AED), Color(0xFF06B6D4)],
  );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 42.w,
          height: 42.w,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.r),
            gradient: isAi
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF7C3AED).withValues(alpha: 0.22),
                      const Color(0xFF06B6D4).withValues(alpha: 0.18),
                    ],
                  )
                : null,
            color: isAi
                ? null
                : active
                    ? ProjectsDashboardTheme.greyDark.withValues(alpha: 0.55)
                    : Colors.transparent,
            border: isAi
                ? Border.all(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.28),
                  )
                : null,
          ),
          child: isAi
              ? ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => _aiGradient.createShader(bounds),
                  child: Icon(
                    icon,
                    size: 21.sp,
                    color: Colors.white,
                  ),
                )
              : Icon(
                  icon,
                  size: 21.sp,
                  color: active
                      ? ProjectsDashboardTheme.greyPanel
                      : ProjectsDashboardTheme.greyLight.withValues(alpha: 0.65),
                ),
        ),
      ),
    );
  }
}
