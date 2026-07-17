import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_dashboard_aggregator.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_dashboard_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ProjectsMetallicKpiRow extends StatelessWidget {
  const ProjectsMetallicKpiRow({
    super.key,
    required this.stats,
    required this.agreementsLabel,
    required this.totalProjectsLabel,
    this.isLoading = false,
  });

  final ProjectsDashboardBoxStats stats;
  final String agreementsLabel;
  final String totalProjectsLabel;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const ProjectsKpiShimmerRow();

    final valueFmt = NumberFormat('#,##0', 'en');

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.tw),
      child: Row(
        children: [
          Expanded(
            child: _KpiBox(
              label: agreementsLabel,
              value: valueFmt.format(stats.agreementsCount),
              icon: Icons.handshake_rounded,
            ),
          ),
          SizedBox(width: 10.tw),
          Expanded(
            child: _KpiBox(
              label: totalProjectsLabel,
              value: valueFmt.format(stats.totalProjects),
              icon: Icons.folder_copy_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiBox extends StatelessWidget {
  const _KpiBox({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88.th,
      padding: EdgeInsets.symmetric(horizontal: 14.tw, vertical: 10.th),
      decoration: ProjectsDashboardTheme.frostedPanel(radius: 16),
      child: Row(
        children: [
          Container(
            width: 42.tw,
            height: 42.tw,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.tr),
              gradient: ProjectsDashboardTheme.maroonAccentGradient,
            ),
            child: Icon(
              icon,
              color: ProjectsDashboardTheme.white,
              size: 22.tsp,
            ),
          ),
          SizedBox(width: 10.tw),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10.tsp,
                    fontWeight: FontWeight.w500,
                    color: ProjectsDashboardTheme.greyPanel.withValues(
                      alpha: 0.9,
                    ),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: GoogleFonts.koulen(
                    fontSize: 22.tsp,
                    color: ProjectsDashboardTheme.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
