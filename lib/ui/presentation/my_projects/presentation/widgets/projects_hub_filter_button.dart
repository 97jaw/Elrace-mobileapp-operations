import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Glassy filter control — tap opens filters; X clears when active.
class ProjectsHubFilterButton extends StatelessWidget {
  const ProjectsHubFilterButton({
    super.key,
    required this.active,
    required this.onTap,
    this.onClear,
    this.size,
  });

  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final box = size ?? 42.w;

    return SizedBox(
      width: box + (active && onClear != null ? 6.w : 0),
      height: box + (active && onClear != null ? 6.h : 0),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14.r),
              child: Container(
                width: box,
                height: box,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14.r),
                  gradient: active
                      ? ProjectsDashboardTheme.maroonAccentGradient
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            ProjectsDashboardTheme.white
                                .withValues(alpha: 0.28),
                            ProjectsDashboardTheme.glassFillStrong,
                            ProjectsDashboardTheme.glassFill
                                .withValues(alpha: 0.85),
                          ],
                        ),
                  border: Border.all(
                    color: active
                        ? ProjectsDashboardTheme.white.withValues(alpha: 0.55)
                        : ProjectsDashboardTheme.white.withValues(alpha: 0.32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: ProjectsDashboardTheme.white,
                  size: (box * 0.52).clamp(18, 26),
                ),
              ),
            ),
          ),
          if (active && onClear != null)
            Positioned(
              top: -2.h,
              right: -2.w,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onClear,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 20.w,
                    height: 20.w,
                    decoration: BoxDecoration(
                      color: ProjectsDashboardTheme.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ProjectsDashboardTheme.maroon,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14.sp,
                      color: ProjectsDashboardTheme.maroon,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
