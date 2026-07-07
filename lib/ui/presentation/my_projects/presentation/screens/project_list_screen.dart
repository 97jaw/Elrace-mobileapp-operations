import 'dart:async';
import 'dart:math' as math;

import 'package:el_race/ui/presentation/my_projects/domain/entities/project_entity.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_list_bloc.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_list_event.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_list_state.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/map/project_analytics_screen.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/projects_group_hub_filters.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/projects_list_context.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_dashboard_aggregator.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_list_pagination.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_agreement_hero_header.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_dashboard_shimmer.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_glass_chrome.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_hub_filter_button.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_hub_filters_sheet.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_list_load_more_footer.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_theme_project_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:google_fonts/google_fonts.dart';

class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({
    super.key,
    required this.bloc,
    this.agreementId,
    this.partnerId,
    this.projectManagerId,
    this.cityId,
    this.partnerName,
    this.partnerPhoto,
    this.agreementNo,
    this.listContext = ProjectsListContext.general,
    this.preloadedProjects,
    this.hubFilters,
    this.initialKeyword,
    this.bucketName,
    this.onHome,
  });

  final ProjectListBloc bloc;
  final int? agreementId;
  final int? partnerId;
  final int? projectManagerId;
  final int? cityId;
  final String? partnerName;
  final String? partnerPhoto;
  final String? agreementNo;
  final ProjectsListContext listContext;
  final List<ProjectEntity>? preloadedProjects;
  final ProjectsGroupHubFilters? hubFilters;
  final String? initialKeyword;
  final String? bucketName;
  final VoidCallback? onHome;

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  late ProjectListBloc bloc;
  Timer? _searchDebounce;
  bool _scrollLoadTriggered = false;
  bool _initialFiltersDispatched = false;

  late ProjectsGroupHubFilters _hubFilters;

  int _preloadedVisibleCount = kProjectsListPageSize;

  bool get _hasAgreementHero =>
      widget.listContext == ProjectsListContext.agreement;

  bool get _hidePmAvatar =>
      widget.listContext == ProjectsListContext.projectManager;

  bool get _showCardBackgroundLogo => !_hasAgreementHero;

  bool get _usesPreloadedList => widget.preloadedProjects != null;

  @override
  void initState() {
    super.initState();
    _hubFilters = widget.hubFilters ?? const ProjectsGroupHubFilters();
    if (widget.initialKeyword != null &&
        widget.initialKeyword!.trim().isNotEmpty) {
      _searchController.text = widget.initialKeyword!.trim();
    }
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    bloc = widget.bloc;

    if (widget.preloadedProjects != null) {
      bloc.add(LoadPreloadedProjectsEvent(widget.preloadedProjects!));
    } else if (_usesServerFilters) {
      _dispatchFilters();
    } else {
      bloc.add(LoadProjectsEvent());
    }
  }

  bool get _usesFilterApi =>
      widget.agreementId != null ||
      widget.projectManagerId != null ||
      widget.cityId != null ||
      widget.partnerId != null;

  bool get _usesServerFilters =>
      _usesFilterApi || _hubFilters.hasActiveFilters;

  ProjectsGroupHubFilters? get _activeHubFilters {
    if (widget.hubFilters != null || _hubFilters.hasActiveFilters) {
      return _hubFilters;
    }
    return null;
  }

  void _dispatchFilters({String? keyword}) {
    if (_initialFiltersDispatched && keyword == null) return;
    _initialFiltersDispatched = true;
    final q = keyword ??
        (_searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim());
    bloc.add(LoadProjectsByFiltersEvent(
      agreementId: widget.agreementId,
      partnerId: widget.partnerId,
      projectManagerId: widget.projectManagerId,
      cityId: widget.cityId,
      keyword: q,
      hubFilters: _activeHubFilters,
      bucketName: widget.bucketName,
      bucketContext: widget.bucketName != null ? widget.listContext : null,
      refresh: true,
    ));
  }

  Future<void> _openHubFilters() async {
    final result = await ProjectsHubFiltersSheet.show(
      context,
      initial: _hubFilters,
    );
    if (result == null || !mounted) return;
    setState(() => _hubFilters = result);
    _initialFiltersDispatched = false;
    _dispatchFilters(keyword: _searchController.text.trim().isEmpty
        ? null
        : _searchController.text.trim());
  }

  void _clearHubFilters() {
    if (!_hubFilters.hasActiveFilters) return;
    setState(() => _hubFilters = const ProjectsGroupHubFilters());
    _initialFiltersDispatched = false;
    if (_usesFilterApi || widget.bucketName != null) {
      _dispatchFilters(
        keyword: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );
    } else {
      bloc.add(LoadProjectsEvent(refresh: true));
    }
  }

  void _onSearchChanged() {
    if (_usesPreloadedList) {
      setState(() {
        _preloadedVisibleCount = kProjectsListPageSize;
        _scrollLoadTriggered = false;
      });
      return;
    }

    if (!_usesServerFilters) return;

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      final q = _searchController.text.trim();
      _initialFiltersDispatched = true;
      bloc.add(LoadProjectsByFiltersEvent(
        agreementId: widget.agreementId,
        partnerId: widget.partnerId,
        projectManagerId: widget.projectManagerId,
        cityId: widget.cityId,
        keyword: q.isEmpty ? null : q,
        hubFilters: _activeHubFilters,
        bucketName: widget.bucketName,
        bucketContext: widget.bucketName != null ? widget.listContext : null,
        refresh: true,
      ));
    });
  }

  List<ProjectEntity> _filterPreloaded(List<ProjectEntity> projects) {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return projects;
    return projects.where((p) {
      final name = p.name.toLowerCase();
      final wo = p.woRefNo.toLowerCase();
      final agreement = p.agreementId.toLowerCase();
      final pm = (p.projectManagerName ?? '').toLowerCase();
      return name.contains(q) ||
          wo.contains(q) ||
          agreement.contains(q) ||
          pm.contains(q);
    }).toList(growable: false);
  }

  List<ProjectEntity> _displayList() {
    if (_usesPreloadedList) {
      final filtered = _filterPreloaded(bloc.allProjects);
      if (filtered.isEmpty) return const [];
      final end = math.min(_preloadedVisibleCount, filtered.length);
      return filtered.sublist(0, end);
    }
    return bloc.visibleProjects;
  }

  bool _canLoadMore() {
    if (_usesPreloadedList) {
      final filtered = _filterPreloaded(bloc.allProjects);
      return _displayList().length < filtered.length;
    }
    return bloc.hasMoreProjects;
  }

  void _loadMore() {
    if (!_canLoadMore()) return;

    if (_usesPreloadedList) {
      setState(() {
        _preloadedVisibleCount = math.min(
          _preloadedVisibleCount + kProjectsListPageSize,
          _filterPreloaded(bloc.allProjects).length,
        );
        _scrollLoadTriggered = false;
      });
      return;
    }

    bloc.add(LoadMoreProjectsEvent());
    _scrollLoadTriggered = false;
  }

  void _onScroll() {
    if (!_scrollController.hasClients || !_canLoadMore()) return;
    final pos = _scrollController.position;
  // Short lists are not scrollable — never auto-prefetch more pages (causes 4x API burst).
    if (pos.maxScrollExtent <= 0) {
      _scrollLoadTriggered = false;
      return;
    }
    if (pos.pixels < pos.maxScrollExtent - 120) {
      _scrollLoadTriggered = false;
      return;
    }
    if (_scrollLoadTriggered || bloc.isLoadingMore) return;
    _scrollLoadTriggered = true;
    _loadMore();
  }

  void _openProject(ProjectEntity project) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProjectAnalyticsScreen(project: project),
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildGlassChromeHeader() {
    final heroTitle = widget.partnerName?.trim() ?? 'Projects';

    return ProjectsGlassChromeHeader(
      title: _hasAgreementHero ? null : heroTitle,
      showBack: !_hasAgreementHero,
      titleTrailing: !_hasAgreementHero && widget.onHome != null
          ? ProjectsGlassChromeHeader.homeTrailing(
              onPressed: widget.onHome!,
            )
          : null,
    );
  }

  Widget _buildFixedHeader() {
    final heroTitle = widget.partnerName?.trim() ?? 'Projects';
    final heroPhoto =
        ProjectsDashboardAggregator.normalizePhotoUrl(widget.partnerPhoto);
    final heroSubtitle = widget.agreementNo?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_hasAgreementHero)
          ProjectsAgreementHeroHeader(
            title: heroTitle,
            photoUrl: heroPhoto,
            subtitle: heroSubtitle,
            showBack: true,
            onBack: () => Navigator.of(context).maybePop(),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 10.h),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.poppins(
                    fontSize: 13.sp,
                    color: ProjectsDashboardTheme.white,
                  ),
                  decoration: InputDecoration(
                    hintText: translate('projects_dashboard.search_name_hint'),
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 13.sp,
                      color: ProjectsDashboardTheme.greyPanel.withValues(alpha: 0.85),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: ProjectsDashboardTheme.white.withValues(alpha: 0.9),
                      size: 22.sp,
                    ),
                    filled: true,
                    fillColor: ProjectsDashboardTheme.greyPanel.withValues(
                      alpha: 0.18,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 10.h,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                      borderSide: BorderSide(
                        color: ProjectsDashboardTheme.white.withValues(alpha: 0.22),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                      borderSide: BorderSide(
                        color: ProjectsDashboardTheme.white.withValues(alpha: 0.22),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                      borderSide: BorderSide(
                        color: ProjectsDashboardTheme.maroonLight.withValues(
                          alpha: 0.75,
                        ),
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              if (!_usesPreloadedList) ...[
                SizedBox(width: 8.w),
                ProjectsHubFilterButton(
                  active: _hubFilters.hasActiveFilters,
                  onTap: _openHubFilters,
                  onClear:
                      _hubFilters.hasActiveFilters ? _clearHubFilters : null,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: ProjectsDashboardTheme.screenGradient,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildGlassChromeHeader(),
            _buildFixedHeader(),
            Expanded(
              child: BlocBuilder<ProjectListBloc, ProjectListState>(
                buildWhen: (prev, curr) =>
                    curr is ProjectListLoading ||
                    curr is ProjectListLoaded ||
                    curr is ProjectListError,
                builder: (context, state) {
                  if (state is ProjectListLoaded) {
                    _scrollLoadTriggered = false;
                  }
                  if (state is ProjectListLoading &&
                      bloc.visibleProjects.isEmpty) {
                    return ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      itemCount: 6,
                      separatorBuilder: (_, __) => SizedBox(height: 10.h),
                      itemBuilder: (_, __) => const ProjectsProjectRowShimmer(),
                    );
                  }

                  if (state is ProjectListError) {
                    return Center(
                      child: Text(
                        state.message,
                        style: GoogleFonts.poppins(
                          color: ProjectsDashboardTheme.white,
                        ),
                      ),
                    );
                  }

                  final list = _displayList();
                  if (list.isEmpty && state is! ProjectListLoading) {
                    return Center(
                      child: Text(
                        'No projects found',
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          color: ProjectsDashboardTheme.greyPanel,
                        ),
                      ),
                    );
                  }

                  final showFooter =
                      _canLoadMore() && list.isNotEmpty && !bloc.isLoadingMore;
                  final showLoadingFooter = bloc.isLoadingMore;

                  return ListView.separated(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(bottom: 100.h),
                    itemCount: list.length +
                        (showLoadingFooter || showFooter ? 1 : 0),
                    separatorBuilder: (_, __) => SizedBox(height: 10.h),
                    itemBuilder: (context, index) {
                      if (index >= list.length) {
                        return ProjectsListLoadMoreFooter(
                          loading: showLoadingFooter,
                        );
                      }

                      final project = list[index];
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(
                          milliseconds: 260 + (index % 8) * 30,
                        ),
                        curve: Curves.easeOutCubic,
                        builder: (context, t, child) => Opacity(
                          opacity: t,
                          child: Transform.translate(
                            offset: Offset(0, 12 * (1 - t)),
                            child: child,
                          ),
                        ),
                        child: ProjectsThemeProjectCard(
                          project: project,
                          showBackgroundLogo: _showCardBackgroundLogo,
                          hidePmAvatar: _hidePmAvatar,
                          onTap: () => _openProject(project),
                        ),
                      );
                    },
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
