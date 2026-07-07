import 'dart:math' as math;

import 'package:el_race/ui/presentation/my_projects/domain/entities/project_entity.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/map/project_analytics_screen.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/client_in_progress_grouper.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_dashboard_aggregator.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_list_pagination.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_dashboard_shimmer.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_list_load_more_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> showClientProjectsBottomSheet({
  required BuildContext context,
  required ClientInProgressBarData client,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (ctx) => _ClientProjectsSheet(client: client),
  );
}

class _ClientProjectsSheet extends StatefulWidget {
  const _ClientProjectsSheet({required this.client});

  final ClientInProgressBarData client;

  @override
  State<_ClientProjectsSheet> createState() => _ClientProjectsSheetState();
}

class _ClientProjectsSheetState extends State<_ClientProjectsSheet>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _entryController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  int _visibleCount = kProjectsListPageSize;
  bool _scrollLoadTriggered = false;
  bool _initialLoading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );

    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);

    _entryController.forward();
    Future<void>.delayed(const Duration(milliseconds: 420), () {
      if (mounted) setState(() => _initialLoading = false);
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _visibleCount = kProjectsListPageSize;
      _scrollLoadTriggered = false;
    });
  }

  void _onScroll() {
    if (_initialLoading || _loadingMore || !_scrollController.hasClients) {
      return;
    }
    final pos = _scrollController.position;
    if (pos.pixels < pos.maxScrollExtent - 120) {
      _scrollLoadTriggered = false;
      return;
    }
    if (_scrollLoadTriggered) return;
    _scrollLoadTriggered = true;
    _loadMore();
  }

  Future<void> _loadMore() async {
    final filtered = _filteredProjects;
    if (_visibleCount >= filtered.length || _loadingMore) return;
    setState(() => _loadingMore = true);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() {
      _visibleCount = math.min(
        _visibleCount + kProjectsListPageSize,
        filtered.length,
      );
      _loadingMore = false;
      _scrollLoadTriggered = false;
    });
  }

  List<ProjectEntity> get _filteredProjects {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return widget.client.projects;

    return widget.client.projects.where((p) {
      final name = p.name.toLowerCase();
      final wo = p.woRefNo.toLowerCase();
      final pm = (p.projectManagerName ?? '').toLowerCase();
      return name.contains(q) || wo.contains(q) || pm.contains(q);
    }).toList(growable: false);
  }

  List<ProjectEntity> get _visibleProjects {
    final filtered = _filteredProjects;
    if (filtered.length <= _visibleCount) return filtered;
    return filtered.sublist(0, _visibleCount);
  }

  void _openProject(ProjectEntity project) {
    Navigator.pop(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProjectAnalyticsScreen(project: project),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.72;
    final filtered = _filteredProjects;
    final visible = _visibleProjects;
    final hasMore = visible.length < filtered.length;
    final showFooter = hasMore && visible.isNotEmpty && !_initialLoading;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            child: Material(
              color: Colors.transparent,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: ProjectsDashboardTheme.pickerSheetGradient,
                ),
                child: SizedBox(
                  height: sheetHeight,
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 8.h),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.client.clientName,
                                style: GoogleFonts.poppins(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                  color: ProjectsDashboardTheme.white,
                                ),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: ProjectsDashboardTheme.maroon
                                    .withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(20.r),
                                border: Border.all(
                                  color: ProjectsDashboardTheme.maroon
                                      .withValues(alpha: 0.65),
                                ),
                              ),
                              child: Text(
                                '${filtered.length} projects',
                                style: GoogleFonts.poppins(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: ProjectsDashboardTheme.white,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(
                                Icons.close_rounded,
                                color: ProjectsDashboardTheme.white,
                                size: 22.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: TextField(
                          controller: _searchController,
                          style: GoogleFonts.poppins(
                            fontSize: 13.sp,
                            color: ProjectsDashboardTheme.white,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search projects…',
                            hintStyle: GoogleFonts.poppins(
                              fontSize: 13.sp,
                              color: ProjectsDashboardTheme.greyPanel
                                  .withValues(alpha: 0.85),
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: ProjectsDashboardTheme.white
                                  .withValues(alpha: 0.9),
                              size: 22.sp,
                            ),
                            filled: true,
                            fillColor: ProjectsDashboardTheme.greyPanel
                                .withValues(alpha: 0.22),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 14.w,
                              vertical: 10.h,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14.r),
                              borderSide: BorderSide(
                                color: ProjectsDashboardTheme.maroon
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14.r),
                              borderSide: BorderSide(
                                color: ProjectsDashboardTheme.white
                                    .withValues(alpha: 0.28),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14.r),
                              borderSide: BorderSide(
                                color: ProjectsDashboardTheme.white
                                    .withValues(alpha: 0.55),
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: _initialLoading
                            ? ListView.separated(
                                padding: EdgeInsets.fromLTRB(
                                  16.w,
                                  0,
                                  16.w,
                                  bottomInset + 16.h,
                                ),
                                itemCount: 6,
                                separatorBuilder: (_, __) =>
                                    SizedBox(height: 10.h),
                                itemBuilder: (_, __) =>
                                    const ProjectsProjectRowShimmer(),
                              )
                            : filtered.isEmpty
                                ? Center(
                                    child: Text(
                                      'No projects found',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13.sp,
                                        color: ProjectsDashboardTheme.white,
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    controller: _scrollController,
                                    physics: const BouncingScrollPhysics(),
                                    padding: EdgeInsets.fromLTRB(
                                      16.w,
                                      0,
                                      16.w,
                                      bottomInset + 16.h,
                                    ),
                                    itemCount:
                                        visible.length + (showFooter ? 1 : 0),
                                    separatorBuilder: (_, __) =>
                                        SizedBox(height: 10.h),
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
                                          onTap: () => _openProject(project),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
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
      duration: Duration(milliseconds: 260 + (index % 8) * 30),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
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
    final pmPhoto = ProjectsDashboardAggregator.normalizePhotoUrl(
      project.managerPhoto ?? project.projectManagerPhoto,
    );
    final pmName = project.projectManagerName?.trim().isNotEmpty == true
        ? project.projectManagerName!
        : '—';
    final wo = project.woRefNo.trim().isNotEmpty
        ? project.woRefNo
        : '#${project.projectId}';

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
              _PmAvatar(photoUrl: pmPhoto, name: pmName),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pmName,
                      style: GoogleFonts.poppins(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: ProjectsDashboardTheme.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      project.name,
                      style: GoogleFonts.poppins(
                        fontSize: 11.sp,
                        color: ProjectsDashboardTheme.greyPanel
                            .withValues(alpha: 0.95),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Icon(
                Icons.chevron_right_rounded,
                color: ProjectsDashboardTheme.white.withValues(alpha: 0.85),
                size: 22.sp,
              ),
              SizedBox(width: 4.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: ProjectsDashboardTheme.maroon.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: ProjectsDashboardTheme.maroon.withValues(
                      alpha: 0.65,
                    ),
                  ),
                ),
                child: Text(
                  wo,
                  style: GoogleFonts.poppins(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: ProjectsDashboardTheme.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PmAvatar extends StatelessWidget {
  const _PmAvatar({required this.photoUrl, required this.name});

  final String photoUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty && name != '—'
        ? name.trim()[0].toUpperCase()
        : '?';

    if (photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 22.r,
        backgroundImage: NetworkImage(photoUrl),
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      radius: 22.r,
      backgroundColor: ProjectsDashboardTheme.navy,
      child: Text(
        initial,
        style: GoogleFonts.poppins(
          color: ProjectsDashboardTheme.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
