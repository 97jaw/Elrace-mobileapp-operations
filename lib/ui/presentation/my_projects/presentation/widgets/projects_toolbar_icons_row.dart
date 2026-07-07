import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_view_switch_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dashboard toolbar: dashboard, map, group-by, documents hub, AI.
class ProjectsToolbarIconsRow extends StatelessWidget {
  const ProjectsToolbarIconsRow({
    super.key,
    required this.viewMode,
    required this.onDashboardTap,
    required this.onMapsTap,
    required this.onGroupByTap,
    required this.onDocumentsTap,
    required this.onAiTap,
  });

  final ProjectsViewMode viewMode;
  final VoidCallback onDashboardTap;
  final VoidCallback onMapsTap;
  final VoidCallback onGroupByTap;
  final VoidCallback onDocumentsTap;
  final VoidCallback onAiTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ToolbarIcon(
          icon: Icons.dashboard_rounded,
          isActive: viewMode == ProjectsViewMode.dashboard,
          onTap: onDashboardTap,
        ),
        _ToolbarIcon(
          icon: Icons.map_rounded,
          isActive: viewMode == ProjectsViewMode.maps,
          onTap: onMapsTap,
        ),
        _ToolbarIcon(
          icon: Icons.account_tree_rounded,
          isActive: false,
          onTap: onGroupByTap,
        ),
        _ToolbarIcon(
          icon: Icons.folder_open_rounded,
          isActive: false,
          onTap: onDocumentsTap,
        ),
        _AiToolbarIcon(onTap: onAiTap),
      ],
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  const _ToolbarIcon({
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          width: 46.w,
          height: 46.w,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            gradient: isActive
                ? ProjectsDashboardTheme.iconTileActiveGradient
                : ProjectsDashboardTheme.iconTileGradient,
            border: Border.all(
              color: isActive
                  ? ProjectsDashboardTheme.white.withValues(alpha: 0.45)
                  : ProjectsDashboardTheme.maroon.withValues(alpha: 0.4),
              width: isActive ? 1.8 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: ProjectsDashboardTheme.white,
            size: 22.sp,
          ),
        ),
      ),
    );
  }
}

class _AiToolbarIcon extends StatelessWidget {
  const _AiToolbarIcon({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          width: 46.w,
          height: 46.w,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            gradient: ProjectsDashboardTheme.maroonAccentGradient,
            border: Border.all(
              color: ProjectsDashboardTheme.white.withValues(alpha: 0.62),
              width: 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: ProjectsDashboardTheme.maroonDark.withValues(alpha: 0.45),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: ProjectsDashboardTheme.maroonLight.withValues(alpha: 0.35),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 5.h,
                right: 7.w,
                child: Icon(
                  Icons.auto_awesome,
                  size: 9.sp,
                  color: ProjectsDashboardTheme.white.withValues(alpha: 0.85),
                ),
              ),
              Positioned(
                bottom: 6.h,
                left: 7.w,
                child: Icon(
                  Icons.auto_awesome,
                  size: 6.sp,
                  color: ProjectsDashboardTheme.maroonSoft.withValues(alpha: 0.95),
                ),
              ),
              Text(
                'Ai',
                style: GoogleFonts.poppins(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w800,
                  color: ProjectsDashboardTheme.white,
                  height: 1,
                  letterSpacing: -0.5,
                  shadows: [
                    Shadow(
                      color: ProjectsDashboardTheme.maroonDark.withValues(alpha: 0.55),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
