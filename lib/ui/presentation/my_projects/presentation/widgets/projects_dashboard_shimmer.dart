import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ProjectsShimmerBox extends StatefulWidget {
  const ProjectsShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<ProjectsShimmerBox> createState() => _ProjectsShimmerBoxState();
}

class _ProjectsShimmerBoxState extends State<ProjectsShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = 0.22 + (_controller.value * 0.28);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: ProjectsDashboardTheme.white.withValues(alpha: t),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

class ProjectsKpiShimmerRow extends StatelessWidget {
  const ProjectsKpiShimmerRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          Expanded(child: _box()),
          SizedBox(width: 10.w),
          Expanded(child: _box()),
        ],
      ),
    );
  }

  Widget _box() {
    return Container(
      height: 88.h,
      padding: EdgeInsets.all(14.w),
      decoration: ProjectsDashboardTheme.frostedPanel(radius: 16),
      child: Row(
        children: [
          ProjectsShimmerBox(width: 42.w, height: 42.w, borderRadius: 12.r),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ProjectsShimmerBox(
                  width: double.infinity,
                  height: 10.h,
                  borderRadius: 6.r,
                ),
                SizedBox(height: 8.h),
                ProjectsShimmerBox(width: 64.w, height: 18.h, borderRadius: 6.r),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProjectsChartShimmer extends StatelessWidget {
  const ProjectsChartShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(
        5,
        (i) => Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: ProjectsShimmerBox(
              width: double.infinity,
              height: 72.h + (i * 10).h,
              borderRadius: 8.r,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shimmer placeholder for a project list row (bottom sheet / status list).
class ProjectsProjectRowShimmer extends StatelessWidget {
  const ProjectsProjectRowShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: ProjectsDashboardTheme.frostedPanel(radius: 14),
      child: Row(
        children: [
          ProjectsShimmerBox(width: 44.w, height: 44.w, borderRadius: 22.r),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProjectsShimmerBox(
                  width: double.infinity,
                  height: 13.h,
                  borderRadius: 6.r,
                ),
                SizedBox(height: 8.h),
                ProjectsShimmerBox(width: 120.w, height: 10.h, borderRadius: 6.r),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          ProjectsShimmerBox(width: 48.w, height: 28.h, borderRadius: 10.r),
        ],
      ),
    );
  }
}

class ProjectsAgreementCardShimmer extends StatelessWidget {
  const ProjectsAgreementCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      height: 120.h,
      padding: EdgeInsets.all(12.w),
      decoration: ProjectsDashboardTheme.frostedPanel(radius: 18),
      child: Row(
        children: [
          ProjectsShimmerBox(width: 64.w, height: 64.w, borderRadius: 12.r),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ProjectsShimmerBox(
                  width: double.infinity,
                  height: 14.h,
                  borderRadius: 6.r,
                ),
                SizedBox(height: 10.h),
                ProjectsShimmerBox(width: 90.w, height: 10.h, borderRadius: 6.r),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
