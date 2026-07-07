import 'dart:math' as math;

import 'package:el_race/ui/presentation/my_projects/domain/entities/project_entity.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/map/project_analytics_screen.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_list_pagination.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_dashboard_shimmer.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_list_load_more_footer.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_glass_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';


/// Projects list filtered by a dashboard status chip (access-scoped data).
class ProjectsStatusListScreen extends StatefulWidget {
  const ProjectsStatusListScreen({
    super.key,
    required this.title,
    required this.projects,
  });

  final String title;
  final List<ProjectEntity> projects;

  @override
  State<ProjectsStatusListScreen> createState() =>
      _ProjectsStatusListScreenState();
}

class _ProjectsStatusListScreenState extends State<ProjectsStatusListScreen> {
  final ScrollController _scrollController = ScrollController();
  int _visibleCount = kProjectsListPageSize;
  bool _scrollLoadTriggered = false;
  bool _initialLoading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _initialLoading = false);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  List<ProjectEntity> get _visibleProjects {
    if (widget.projects.length <= _visibleCount) return widget.projects;
    return widget.projects.sublist(0, _visibleCount);
  }

  bool get _hasMore => _visibleCount < widget.projects.length;

  void _onScroll() {
    if (_initialLoading || _loadingMore || !_scrollController.hasClients) {
      return;
    }
    final pos = _scrollController.position;
    if (pos.pixels < pos.maxScrollExtent - 120) {
      _scrollLoadTriggered = false;
      return;
    }
    if (_scrollLoadTriggered || !_hasMore) return;
    _scrollLoadTriggered = true;
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() {
      _visibleCount = math.min(
        _visibleCount + kProjectsListPageSize,
        widget.projects.length,
      );
      _loadingMore = false;
      _scrollLoadTriggered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleProjects;
    final showFooter =
        _hasMore && visible.isNotEmpty && !_initialLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      body: ProjectsGlassShell(
        title: widget.title,
        body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _initialLoading
                ? ListView.separated(
                    padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
                    itemCount: 6,
                    separatorBuilder: (_, __) => SizedBox(height: 10.h),
                    itemBuilder: (_, __) => const ProjectsProjectRowShimmer(),
                  )
                : widget.projects.isEmpty
                    ? Center(
                        child: Text(
                          'No projects',
                          style: GoogleFonts.poppins(
                            fontSize: 14.sp,
                            color: ProjectsDashboardTheme.grey,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
                        itemCount: visible.length + (showFooter ? 1 : 0),
                        separatorBuilder: (_, __) => SizedBox(height: 10.h),
                        itemBuilder: (context, index) {
                          if (index >= visible.length) {
                            return ProjectsListLoadMoreFooter(
                              loading: _loadingMore,
                            );
                          }

                          final project = visible[index];
                          return _AnimatedProjectRow(
                            index: index,
                            child: _ProjectRow(
                              project: project,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ProjectAnalyticsScreen(
                                      project: project,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      ),
    );
  }
}

class _AnimatedProjectRow extends StatelessWidget {
  const _AnimatedProjectRow({
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + (index % 8) * 35),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({
    required this.project,
    required this.onTap,
  });

  final ProjectEntity project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = project.projectStatus.trim().isNotEmpty
        ? project.projectStatus
        : '—';
    final name = project.name.trim().isNotEmpty
        ? project.name
        : project.agreementId;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: ProjectsDashboardTheme.frostedPanel(radius: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1F2937),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      status,
                      style: GoogleFonts.poppins(
                        fontSize: 11.sp,
                        color: ProjectsDashboardTheme.maroon,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: ProjectsDashboardTheme.maroon,
                size: 24.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
