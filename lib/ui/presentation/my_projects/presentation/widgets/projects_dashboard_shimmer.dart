import 'package:el_race/core/utils/responsive_breakpoints.dart';
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
      padding: EdgeInsets.symmetric(horizontal: 16.tw),
      child: Row(
        children: [
          Expanded(child: _box()),
          SizedBox(width: 10.tw),
          Expanded(child: _box()),
        ],
      ),
    );
  }

  Widget _box() {
    return Container(
      height: 88.th,
      padding: EdgeInsets.all(14.tw),
      decoration: ProjectsDashboardTheme.frostedPanel(radius: 16),
      child: Row(
        children: [
          ProjectsShimmerBox(width: 42.tw, height: 42.tw, borderRadius: 12.tr),
          SizedBox(width: 10.tw),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ProjectsShimmerBox(
                  width: double.infinity,
                  height: 10.th,
                  borderRadius: 6.tr,
                ),
                SizedBox(height: 8.th),
                ProjectsShimmerBox(width: 64.tw, height: 18.th, borderRadius: 6.tr),
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
            padding: EdgeInsets.symmetric(horizontal: 4.tw),
            child: ProjectsShimmerBox(
              width: double.infinity,
              height: 72.th + (i * 10).th,
              borderRadius: 8.tr,
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
      padding: EdgeInsets.all(12.tw),
      decoration: ProjectsDashboardTheme.frostedPanel(radius: 14),
      child: Row(
        children: [
          ProjectsShimmerBox(width: 44.tw, height: 44.tw, borderRadius: 22.tr),
          SizedBox(width: 12.tw),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProjectsShimmerBox(
                  width: double.infinity,
                  height: 13.th,
                  borderRadius: 6.tr,
                ),
                SizedBox(height: 8.th),
                ProjectsShimmerBox(width: 120.tw, height: 10.th, borderRadius: 6.tr),
              ],
            ),
          ),
          SizedBox(width: 8.tw),
          ProjectsShimmerBox(width: 48.tw, height: 28.th, borderRadius: 10.tr),
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
      margin: EdgeInsets.symmetric(horizontal: 16.tw, vertical: 6.th),
      height: 120.th,
      padding: EdgeInsets.all(12.tw),
      decoration: ProjectsDashboardTheme.frostedPanel(radius: 18),
      child: Row(
        children: [
          ProjectsShimmerBox(width: 64.tw, height: 64.tw, borderRadius: 12.tr),
          SizedBox(width: 12.tw),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ProjectsShimmerBox(
                  width: double.infinity,
                  height: 14.th,
                  borderRadius: 6.tr,
                ),
                SizedBox(height: 10.th),
                ProjectsShimmerBox(width: 90.tw, height: 10.th, borderRadius: 6.tr),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
