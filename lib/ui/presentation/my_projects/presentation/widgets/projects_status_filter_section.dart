import 'package:el_race/core/utils/responsive_breakpoints.dart';
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
  });

  final String inProgress;
  final String completed;
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
      padding: EdgeInsets.fromLTRB(16.tw, 4.th, 16.tw, 2.th),
      child: SizedBox(
        height: 40.th,
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
                  SizedBox(width: 8.tw),
                  _StatusFilterChip(
                    label: labels.completed,
                    count: stats?.completed ?? 0,
                    accent: ProjectsDashboardTheme.greyPanel,
                    onTap: () =>
                        onFilterTap(ProjectsStatusFilterKind.completed),
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
        2,
        (i) => Padding(
          padding: EdgeInsets.only(right: i < 1 ? 8.tw : 0),
          child: ProjectsShimmerBox(
            width: 108.tw,
            height: 36.th,
            borderRadius: 20.tr,
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
        borderRadius: BorderRadius.circular(22.tr),
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
            borderRadius: BorderRadius.circular(22.tr),
            border: Border.all(
              color: ProjectsDashboardTheme.white.withValues(alpha: 0.38),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 7.th),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  constraints: BoxConstraints(minWidth: 26.tw),
                  padding: EdgeInsets.symmetric(horizontal: 7.tw, vertical: 2.th),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12.tr),
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
                      fontSize: 14.tsp,
                      height: 1,
                      color: ProjectsDashboardTheme.white,
                    ),
                  ),
                ),
                SizedBox(width: 8.tw),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11.tsp,
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
