import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_dashboard_aggregator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class ProjectsKpiStrip extends StatelessWidget {
  const ProjectsKpiStrip({
    super.key,
    required this.stats,
    this.isLoading = false,
    this.labels,
  });

  final ProjectsDashboardStripStats? stats;
  final bool isLoading;
  final ProjectsKpiStripLabels? labels;

  @override
  Widget build(BuildContext context) {
    final l = labels ?? const ProjectsKpiStripLabels();

    return Padding(
      padding: EdgeInsets.fromLTRB(16.tw, 12.th, 16.tw, 4.th),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.sectionTitle,
            style: GoogleFonts.poppins(
              fontSize: 13.tsp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF374151),
            ),
          ),
          SizedBox(height: 8.th),
          SizedBox(
            height: 36.th,
            child: isLoading
                ? _LoadingChips(labels: l)
                : stats == null
                    ? Center(
                        child: Text(
                          l.unavailable,
                          style: GoogleFonts.poppins(
                            fontSize: 12.tsp,
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                      )
                    : ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _Chip(
                            label: l.inProgress,
                            count: stats!.inProgress,
                            color: const Color(0xFF1565C0),
                          ),
                          SizedBox(width: 8.tw),
                          _Chip(
                            label: l.completed,
                            count: stats!.completed,
                            color: const Color(0xFF2E7D32),
                          ),
                          SizedBox(width: 8.tw),
                          _Chip(
                            label: l.invoiced,
                            count: stats!.invoiced,
                            color: const Color(0xFF1E2365),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class ProjectsKpiStripLabels {
  const ProjectsKpiStripLabels({
    this.sectionTitle = 'Project status',
    this.inProgress = 'In progress',
    this.completed = 'Completed',
    this.invoiced = 'Invoiced',
    this.unavailable = 'Status breakdown unavailable',
  });

  final String sectionTitle;
  final String inProgress;
  final String completed;
  final String invoiced;
  final String unavailable;
}

class _LoadingChips extends StatelessWidget {
  const _LoadingChips({required this.labels});

  final ProjectsKpiStripLabels labels;

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.horizontal,
      children: List.generate(3, (i) {
        return Padding(
          padding: EdgeInsets.only(right: i < 2 ? 8.tw : 0),
          child: Container(
            width: 100.tw,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(20.tr),
            ),
          ),
        );
      }),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 6.th),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20.tr),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: GoogleFonts.koulen(
              fontSize: 16.tsp,
              color: color,
            ),
          ),
          SizedBox(width: 6.tw),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11.tsp,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
