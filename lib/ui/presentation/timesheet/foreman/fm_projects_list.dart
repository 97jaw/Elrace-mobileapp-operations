import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/providers/timesheet_data_providers.dart';
import 'package:el_race/core/timesheet/routing/timesheet_route_names.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_paginated_list_view.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_route_args.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FmProjectsList extends ConsumerStatefulWidget {
  const FmProjectsList({super.key});

  @override
  ConsumerState<FmProjectsList> createState() => _FmProjectsListState();
}

class _FmProjectsListState extends ConsumerState<FmProjectsList> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(timesheetProjectsProvider);

    return TmScaffold(
      appBar: AppBar(
        title: Text('Projects', style: TimesheetModuleTypography.h2()),
        backgroundColor: TimesheetModuleColors.surface,
        foregroundColor: TimesheetModuleColors.text,
        elevation: 0,
      ),
      body: projectsAsync.when(
        loading: () => const TimesheetLoadingState(
          style: TimesheetLoadingStyle.list,
          itemCount: 6,
        ),
        error: (_, __) => TimesheetErrorState(
          message: 'Could not load projects',
          onRetry: () => ref.invalidate(timesheetProjectsProvider),
        ),
        data: (projects) {
          if (projects.isEmpty) {
            return const TimesheetEmptyState(message: 'No projects assigned');
          }
          final filtered = projects.where((project) {
            if (_searchQuery.isEmpty) return true;
            final q = _searchQuery.toLowerCase();
            return project.name.toLowerCase().contains(q) ||
                project.code.toLowerCase().contains(q);
          }).toList();
          if (filtered.isEmpty) {
            return const TimesheetEmptyState(
              message: 'No projects match your search',
            );
          }
          return TmPaginatedListView(
            itemCount: filtered.length,
            itemSpacing: TimesheetModuleLayout.cardSpacing,
            header: TmSearchField(
              hintText: 'Search projects',
              onDebouncedChanged: (value) =>
                  setState(() => _searchQuery = value.trim()),
            ),
            padding: const EdgeInsets.fromLTRB(
              TimesheetModuleLayout.screenPaddingH,
              TimesheetModuleLayout.cardSpacing,
              TimesheetModuleLayout.screenPaddingH,
              32,
            ),
            itemBuilder: (context, index) {
              final project = filtered[index];
              return TmProjectCard.fromProject(
                project,
                onTap: () => Navigator.of(context).pushNamed(
                  TimesheetRouteNames.projectDates,
                  arguments: TimesheetProjectArgs(
                    projectId: project.id,
                    projectName: project.name,
                    clientImageUrl: project.clientImageUrl,
                    woRefNo: project.woRefNo,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
