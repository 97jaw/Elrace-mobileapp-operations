import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_dashboard_aggregator.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_dashboard_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class ProjectsStatusFilterLabels {
  const ProjectsStatusFilterLabels({
    required this.inProgress,
    required this.completed,
    required this.invoiced,
  });

  final String inProgress;
  final String completed;
  final String invoiced;
}

/// Frosted status filter chips with count badges (no section title).
class ProjectsStatusFilterSection extends StatelessWidget {
  const ProjectsStatusFilterSection({
    super.key,
    required this.stats,
    required this.isLoading,
    required this.labels,
    required this.onFilterTap,
  });

  final ProjectsDashboardStripStats? stats;
  final bool isLoading;
  final ProjectsStatusFilterLabels labels;
  final ValueChanged<ProjectsStatusFilterKind> onFilterTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 8.h),
      child: SizedBox(
        height: 40.h,
        child: isLoading
            ? _LoadingRow()
            : ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  _StatusFilterChip(
                    label: labels.inProgress,
                    count: stats?.inProgress ?? 0,
                    accent: ProjectsDashboardTheme.maroonLight,
                    onTap: () =>
                        onFilterTap(ProjectsStatusFilterKind.inProgress),
                  ),
                  SizedBox(width: 8.w),
                  _StatusFilterChip(
                    label: labels.completed,
                    count: stats?.completed ?? 0,
                    accent: ProjectsDashboardTheme.greyPanel,
                    onTap: () =>
                        onFilterTap(ProjectsStatusFilterKind.completed),
                  ),
                  SizedBox(width: 8.w),
                  _StatusFilterChip(
                    label: labels.invoiced,
                    count: stats?.invoiced ?? 0,
                    accent: ProjectsDashboardTheme.navy,
                    onTap: () =>
                        onFilterTap(ProjectsStatusFilterKind.invoiced),
                  ),
                ],
              ),
      ),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.horizontal,
      children: List.generate(
        3,
        (i) => Padding(
          padding: EdgeInsets.only(right: i < 2 ? 8.w : 0),
          child: ProjectsShimmerBox(
            width: 108.w,
            height: 36.h,
            borderRadius: 20.r,
          ),
        ),
      ),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    required this.label,
    required this.count,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22.r),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                ProjectsDashboardTheme.greyPanel.withValues(alpha: 0.28),
                accent.withValues(alpha: 0.42),
                ProjectsDashboardTheme.maroon.withValues(alpha: 0.32),
              ],
            ),
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(
              color: ProjectsDashboardTheme.white.withValues(alpha: 0.38),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  constraints: BoxConstraints(minWidth: 26.w),
                  padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: ProjectsDashboardTheme.white.withValues(
                        alpha: 0.45,
                      ),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$count',
                    style: GoogleFonts.koulen(
                      fontSize: 14.sp,
                      height: 1,
                      color: ProjectsDashboardTheme.white,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: ProjectsDashboardTheme.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
