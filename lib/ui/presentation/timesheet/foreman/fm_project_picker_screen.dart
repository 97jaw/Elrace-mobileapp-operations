import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_models.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/core/timesheet/providers/timesheet_role_provider.dart';
import 'package:el_race/core/timesheet/routing/timesheet_route_names.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_paginated_list_view.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_route_args.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

enum _ProjectListStatusFilter { inProgress, completed, all }

/// See-all projects — same tiles as dashboard; optional filter panel.
class FmProjectPickerScreen extends ConsumerStatefulWidget {
  const FmProjectPickerScreen({
    super.key,
    this.showFiltersInitially = false,
    this.openChatOnSelect = false,
  });

  final bool showFiltersInitially;
  final bool openChatOnSelect;

  @override
  ConsumerState<FmProjectPickerScreen> createState() =>
      _FmProjectPickerScreenState();
}

class _FmProjectPickerScreenState extends ConsumerState<FmProjectPickerScreen> {
  String _searchQuery = '';
  late bool _filtersOpen;
  _ProjectListStatusFilter _statusFilter = _ProjectListStatusFilter.inProgress;
  List<Project>? _completedCache;

  @override
  void initState() {
    super.initState();
    _filtersOpen = widget.showFiltersInitially;
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
      onChanged: (id) => setState(() {
        _completedCache = null;
        _statusFilter = switch (id) {
          'completed' => _ProjectListStatusFilter.completed,
          'all' => _ProjectListStatusFilter.all,
          _ => _ProjectListStatusFilter.inProgress,
        };
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TmScaffold(
      appBar: AppBar(
        title: Text('All projects', style: TimesheetModuleTypography.h2()),
        backgroundColor: TimesheetModuleColors.surface,
        foregroundColor: TimesheetModuleColors.text,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: _filtersOpen ? 'Hide filters' : 'Show filters',
            onPressed: () => setState(() => _filtersOpen = !_filtersOpen),
            icon: Icon(
              _filtersOpen ? PhosphorIcons.funnelX() : PhosphorIcons.funnel(),
              color: TimesheetModuleColors.navy,
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<Project>>(
        key: ValueKey(_statusFilter),
        future: _loadProjects(),
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
              onRetry: () => setState(() {
                _completedCache = null;
              }),
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

          if (filtered.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                TimesheetModuleLayout.screenPaddingH,
                TimesheetModuleLayout.cardSpacing,
                TimesheetModuleLayout.screenPaddingH,
                32,
              ),
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
            header: Column(
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
            ),
            itemBuilder: (context, index) {
              final project = filtered[index];
              return TmProjectCard.fromProject(
                project,
                statusLabel: _statusFilter == _ProjectListStatusFilter.completed
                    ? 'Completed'
                    : null,
                onTap: () {
                  final args = TimesheetProjectArgs(
                    projectId: project.id,
                    projectName: project.name,
                    clientImageUrl: project.clientImageUrl,
                    woRefNo: project.woRefNo,
                  );
                  Navigator.of(context).pushNamed(
                    widget.openChatOnSelect
                        ? TimesheetRouteNames.projectChat
                        : TimesheetRouteNames.projectDates,
                    arguments: args,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
