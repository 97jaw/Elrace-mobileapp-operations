import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_models.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/core/timesheet/providers/timesheet_role_provider.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/report_module/data/repositories/company_repository.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/tm_site_reports_for_project_screen.dart';
import 'package:el_race/ui/presentation/timesheet/site_reports/widgets/tm_site_report_company_app_bar.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_paginated_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

enum _ProjectListStatusFilter { inProgress, completed, all }

/// Pick a project, then open the same Site Reports flow used in project detail.
class MyReportsSiteReportProjectPickerScreen extends ConsumerStatefulWidget {
  const MyReportsSiteReportProjectPickerScreen({
    super.key,
    this.showFiltersInitially = false,
  });

  final bool showFiltersInitially;

  @override
  ConsumerState<MyReportsSiteReportProjectPickerScreen> createState() =>
      _MyReportsSiteReportProjectPickerScreenState();
}

class _MyReportsSiteReportProjectPickerScreenState
    extends ConsumerState<MyReportsSiteReportProjectPickerScreen> {
  String _searchQuery = '';
  late bool _filtersOpen;
  _ProjectListStatusFilter _statusFilter = _ProjectListStatusFilter.inProgress;
  List<Project>? _completedCache;
  Future<List<Project>>? _projectsFuture;
  bool _companyReady = false;

  @override
  void initState() {
    super.initState();
    _filtersOpen = widget.showFiltersInitially;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await CompanyRepository().getCompany();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _companyReady = true;
      _projectsFuture = _loadProjects();
    });
  }

  Future<List<Project>> _loadProjects() async {
    final client = ref.read(timesheetApiClientProvider);
    final resolution = ref.read(tmRoleResolutionProvider);
    final role =
        resolution.role == TimesheetEffectiveRole.pm ? 'pm' : 'foreman';
    switch (_statusFilter) {
      case _ProjectListStatusFilter.inProgress:
        final env = await client.getProjects(
          role: role,
          hrWideScope: resolution.hrWideScope,
          status: 'in_progress',
        );
        return env.data ?? const [];
      case _ProjectListStatusFilter.completed:
        _completedCache ??= await client.fetchCompletedSiteProjects();
        return _completedCache!;
      case _ProjectListStatusFilter.all:
        final inProg = await client.getProjects(
          role: role,
          hrWideScope: resolution.hrWideScope,
          status: 'in_progress',
        );
        final done = await client.fetchCompletedSiteProjects();
        return [...(inProg.data ?? const []), ...done];
    }
  }

  void _reloadProjects() {
    _completedCache = null;
    setState(() => _projectsFuture = _loadProjects());
  }

  void _openSiteReports(Project project) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TmSiteReportsForProjectScreen(
          projectId: project.id,
          projectName: project.name,
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return TmFilterChipRow(
      options: const [
        TmFilterOption(id: 'in_progress', label: 'In progress'),
        TmFilterOption(id: 'completed', label: 'Completed'),
        TmFilterOption(id: 'all', label: 'All'),
      ],
      selectedId: switch (_statusFilter) {
        _ProjectListStatusFilter.inProgress => 'in_progress',
        _ProjectListStatusFilter.completed => 'completed',
        _ => 'all',
      },
      onChanged: (id) {
        _statusFilter = switch (id) {
          'completed' => _ProjectListStatusFilter.completed,
          'all' => _ProjectListStatusFilter.all,
          _ => _ProjectListStatusFilter.inProgress,
        };
        _reloadProjects();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return TmSiteReportGlassShell(
      title: 'Select project',
      trailing: [
        IconButton(
          tooltip: _filtersOpen ? 'Hide filters' : 'Show filters',
          onPressed: () => setState(() => _filtersOpen = !_filtersOpen),
          icon: Icon(
            _filtersOpen ? PhosphorIcons.funnelX() : PhosphorIcons.funnel(),
            color: const Color(0xFF1E2365),
          ),
        ),
      ],
      body: !_companyReady
          ? const TimesheetLoadingState(
              style: TimesheetLoadingStyle.list,
              itemCount: 5,
            )
          : FutureBuilder<List<Project>>(
              future: _projectsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const TimesheetLoadingState(
                    style: TimesheetLoadingStyle.list,
                    itemCount: 5,
                  );
                }
                if (snapshot.hasError) {
                  return TimesheetErrorState(
                    message: 'Could not load projects',
                    onRetry: _reloadProjects,
                  );
                }
                final projects = snapshot.data ?? const [];
                final q = _searchQuery.toLowerCase();
                final filtered = projects.where((project) {
                  if (q.isEmpty) return true;
                  return project.name.toLowerCase().contains(q) ||
                      project.woRefNo.toLowerCase().contains(q) ||
                      project.code.toLowerCase().contains(q);
                }).toList();

                final header = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TmSearchField(
                      hintText: 'Search projects',
                      onDebouncedChanged: (value) =>
                          setState(() => _searchQuery = value.trim()),
                    ),
                    if (_filtersOpen) ...[
                      const SizedBox(height: TimesheetModuleLayout.cardSpacing),
                      _buildFilterRow(),
                    ],
                    const SizedBox(height: TimesheetModuleLayout.sectionGap),
                  ],
                );

                if (filtered.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      TimesheetModuleLayout.screenPaddingH,
                      TimesheetModuleLayout.cardSpacing,
                      TimesheetModuleLayout.screenPaddingH,
                      32,
                    ),
                    children: [
                      header,
                      const TimesheetEmptyState(message: 'No projects found'),
                    ],
                  );
                }

                return TmPaginatedListView(
                  itemCount: filtered.length,
                  itemSpacing: TimesheetModuleLayout.cardSpacing,
                  padding: const EdgeInsets.fromLTRB(
                    TimesheetModuleLayout.screenPaddingH,
                    TimesheetModuleLayout.cardSpacing,
                    TimesheetModuleLayout.screenPaddingH,
                    32,
                  ),
                  header: header,
                  itemBuilder: (context, index) {
                    final project = filtered[index];
                    return TmProjectCard.fromProject(
                      project,
                      statusLabel:
                          _statusFilter == _ProjectListStatusFilter.completed
                              ? 'Completed'
                              : null,
                      onTap: () => _openSiteReports(project),
                    );
                  },
                );
              },
            ),
    );
  }
}
