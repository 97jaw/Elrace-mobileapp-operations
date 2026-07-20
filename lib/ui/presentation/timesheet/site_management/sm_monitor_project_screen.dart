import 'dart:async';

import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/widgets/timesheet/tm_scaffold.dart';
import 'package:el_race/ui/presentation/my_projects/data/datasources/project_remote_datasource.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_model.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_scurve_model.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/projects_paged_result.dart';
import 'package:el_race/ui/presentation/timesheet/site_management/widgets/sm_common.dart';
import 'package:el_race/ui/presentation/timesheet/site_management/widgets/sm_foremen_section.dart';
import 'package:el_race/ui/presentation/timesheet/site_management/widgets/sm_monitoring_tab.dart';
import 'package:el_race/ui/presentation/timesheet/site_management/widgets/sm_progress_section.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_fast_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Site Management "Monitor Project" first screen.
///
/// Search-first: shows a project search until a project is selected. Once
/// selected, the search collapses into a project header with Info (progress +
/// foremen) and Monitoring (camera + map) tabs.
class SmMonitorProjectScreen extends ConsumerStatefulWidget {
  const SmMonitorProjectScreen({super.key});

  @override
  ConsumerState<SmMonitorProjectScreen> createState() =>
      _SmMonitorProjectScreenState();
}

class _SmMonitorProjectScreenState extends ConsumerState<SmMonitorProjectScreen>
    with SingleTickerProviderStateMixin {
  final ProjectRemoteDataSource _ds = ProjectRemoteDataSource();
  final TextEditingController _searchCtrl = TextEditingController();
  late final TabController _tab;

  Timer? _debounce;
  Future<ProjectsPagedResult>? _searchFuture;
  String _query = '';

  ProjectModel? _selected;
  Future<ProjectScurveData>? _scurveFuture;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _tab.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final q = value.trim();
      if (q == _query) return;
      setState(() {
        _query = q;
        _searchFuture = q.isEmpty
            ? null
            : _ds.fetchProjectsPage(keyword: q, limit: 25, portfolio: true);
      });
    });
  }

  void _selectProject(ProjectModel project) {
    FocusScope.of(context).unfocus();
    setState(() {
      _selected = project;
      _scurveFuture = _ds.fetchProjectScurve(project.projectId);
      _tab.index = 0;
    });
  }

  void _clearSelection() {
    setState(() {
      _selected = null;
      _scurveFuture = null;
      _searchFuture = null;
      _query = '';
      _searchCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return TmScaffold(
      glassTitle: 'Monitor Project',
      padding: const EdgeInsets.fromLTRB(
        TimesheetModuleLayout.screenPaddingH,
        12,
        TimesheetModuleLayout.screenPaddingH,
        0,
      ),
      body: selected == null ? _buildSearchView() : _buildProjectView(selected),
    );
  }

  // ---------------------------------------------------------------------------
  // Search-first state
  // ---------------------------------------------------------------------------

  Widget _buildSearchView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SearchField(
          controller: _searchCtrl,
          onChanged: _onSearchChanged,
          onClear: () {
            _searchCtrl.clear();
            _onSearchChanged('');
          },
        ),
        const SizedBox(height: 16),
        Expanded(child: _buildSearchResults()),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_searchFuture == null) {
      return _searchHint();
    }
    return FutureBuilder<ProjectsPagedResult>(
      future: _searchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: TimesheetModuleColors.accent,
            ),
          );
        }
        if (snapshot.hasError) {
          return TimesheetErrorState(
            warm: true,
            message: 'Could not search projects.',
            onRetry: () => _onSearchChanged(_query),
          );
        }
        final projects = snapshot.data?.projects ?? const [];
        if (projects.isEmpty) {
          return _searchHint(
            icon: PhosphorIcons.magnifyingGlass(),
            message: 'No projects match "$_query".',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 20),
          itemCount: projects.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _ProjectResultTile(
            project: projects[i],
            onTap: () => _selectProject(projects[i]),
          ),
        );
      },
    );
  }

  Widget _searchHint({IconData? icon, String? message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? PhosphorIcons.buildings(),
              size: 46,
              color: TimesheetModuleColors.accent.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 14),
            Text(
              message ?? 'Search a project to start monitoring.',
              textAlign: TextAlign.center,
              style: TimesheetModuleTypography.body().copyWith(
                color: TimesheetModuleColors.warmMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Selected-project state
  // ---------------------------------------------------------------------------

  Widget _buildProjectView(ProjectModel project) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        _SelectedProjectHeader(project: project, onClear: _clearSelection),
        const SizedBox(height: 16),
        _buildTabBar(),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildInfoTab(project),
              SmMonitoringTab(project: project),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TimesheetModuleColors.glassBorder),
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: _tab,
        indicator: BoxDecoration(
          gradient: TimesheetModuleColors.warmButtonGradient,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: TimesheetModuleColors.warmMuted,
        labelStyle: TimesheetModuleTypography.body().copyWith(
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: TimesheetModuleTypography.body(),
        tabs: const [
          Tab(text: 'Info'),
          Tab(text: 'Monitoring'),
        ],
      ),
    );
  }

  Widget _buildInfoTab(ProjectModel project) {
    return FutureBuilder<ProjectScurveData>(
      future: _scurveFuture,
      builder: (context, snapshot) {
        final waiting = snapshot.connectionState == ConnectionState.waiting;
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (waiting)
              const SizedBox(
                height: 320,
                child: Center(
                  child: CircularProgressIndicator(
                    color: TimesheetModuleColors.accent,
                  ),
                ),
              )
            else if (snapshot.hasError)
              SizedBox(
                height: 320,
                child: TimesheetErrorState(
                  warm: true,
                  message: 'Could not load project progress.',
                  onRetry: () => setState(() {
                    _scurveFuture = _ds.fetchProjectScurve(project.projectId);
                  }),
                ),
              )
            else
              SmProgressSection(
                data: snapshot.data ?? ProjectScurveData.empty(),
              ),
            const SizedBox(height: TimesheetModuleLayout.sectionGap),
            SmForemenSection(projectId: project.projectId.toString()),
          ],
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Search input
// -----------------------------------------------------------------------------

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: smGlassCardDecoration(radius: 14),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: TimesheetModuleTypography.body().copyWith(
          color: TimesheetModuleColors.ink,
        ),
        decoration: InputDecoration(
          hintText: 'Monitor Project — search by name',
          hintStyle: TimesheetModuleTypography.body().copyWith(
            color: TimesheetModuleColors.warmMuted,
          ),
          prefixIcon: Icon(
            PhosphorIcons.magnifyingGlass(),
            color: TimesheetModuleColors.accent,
            size: 20,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: Icon(
                  PhosphorIcons.x(),
                  color: TimesheetModuleColors.warmMuted,
                  size: 18,
                ),
                onPressed: onClear,
              );
            },
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Search result tile
// -----------------------------------------------------------------------------

class _ProjectResultTile extends StatelessWidget {
  const _ProjectResultTile({required this.project, required this.onTap});

  final ProjectModel project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: smGlassCardDecoration(radius: TimesheetModuleLayout.cardRadiusMd),
        child: Row(
          children: [
            _ClientLogo(url: project.clientImageUrl, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TimesheetModuleTypography.cardTitle().copyWith(
                      color: TimesheetModuleColors.ink,
                    ),
                  ),
                  if (project.partnerName?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(
                      project.partnerName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TimesheetModuleTypography.caption().copyWith(
                        color: TimesheetModuleColors.warmMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              PhosphorIcons.caretRight(),
              size: 18,
              color: TimesheetModuleColors.warmMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Collapsed selected-project header
// -----------------------------------------------------------------------------

class _SelectedProjectHeader extends StatelessWidget {
  const _SelectedProjectHeader({required this.project, required this.onClear});

  final ProjectModel project;
  final VoidCallback onClear;

  String get _expiry {
    final raw = project.date.trim();
    if (raw.isEmpty) return '—';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('dd MMM yyyy').format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: smGlassCardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ClientLogo(url: project.clientImageUrl, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TimesheetModuleTypography.h2().copyWith(
                    color: TimesheetModuleColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _pmAvatar(),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        project.projectManagerName?.isNotEmpty == true
                            ? project.projectManagerName!
                            : 'PM not assigned',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TimesheetModuleTypography.caption().copyWith(
                          color: TimesheetModuleColors.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      PhosphorIcons.calendarBlank(),
                      size: 13,
                      color: TimesheetModuleColors.warmMuted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Expires on $_expiry',
                      style: TimesheetModuleTypography.caption().copyWith(
                        color: TimesheetModuleColors.warmMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onClear,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: TimesheetModuleColors.danger.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                PhosphorIcons.x(),
                size: 16,
                color: TimesheetModuleColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pmAvatar() {
    final url = project.managerPhoto?.trim() ?? project.projectManagerPhoto?.trim() ?? '';
    const size = 20.0;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: TimesheetModuleColors.accentTint,
      ),
      child: url.startsWith('http')
          ? TmFastNetworkImage(url: url, width: size, height: size)
          : Icon(
              PhosphorIcons.user(),
              size: 12,
              color: TimesheetModuleColors.accent,
            ),
    );
  }
}

// -----------------------------------------------------------------------------
// Client logo badge
// -----------------------------------------------------------------------------

class _ClientLogo extends StatelessWidget {
  const _ClientLogo({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final u = url?.trim() ?? '';
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TimesheetModuleColors.glassBorder),
      ),
      child: u.startsWith('http')
          ? TmFastNetworkImage(
              url: u,
              fit: BoxFit.contain,
              borderRadius: BorderRadius.circular(8),
            )
          : Icon(
              PhosphorIcons.buildings(),
              color: TimesheetModuleColors.accent,
              size: size * 0.5,
            ),
    );
  }
}
