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
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 4.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.sectionTitle,
            style: GoogleFonts.poppins(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF374151),
            ),
          ),
          SizedBox(height: 8.h),
          SizedBox(
            height: 36.h,
            child: isLoading
                ? _LoadingChips(labels: l)
                : stats == null
                    ? Center(
                        child: Text(
                          l.unavailable,
                          style: GoogleFonts.poppins(
                            fontSize: 12.sp,
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
                          SizedBox(width: 8.w),
                          _Chip(
                            label: l.completed,
                            count: stats!.completed,
                            color: const Color(0xFF2E7D32),
                          ),
                          SizedBox(width: 8.w),
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
          padding: EdgeInsets.only(right: i < 2 ? 8.w : 0),
          child: Container(
            width: 100.w,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(20.r),
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
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: GoogleFonts.koulen(
              fontSize: 16.sp,
              color: color,
            ),
          ),
          SizedBox(width: 6.w),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
