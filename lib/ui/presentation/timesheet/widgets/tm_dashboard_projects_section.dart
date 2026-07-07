import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:el_race/core/timesheet/models/timesheet_models.dart';
import 'package:el_race/core/timesheet/routing/timesheet_route_names.dart';
import 'package:el_race/core/widgets/timesheet/timesheet_widgets.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_async_state.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_animated_list_item.dart';
import 'package:el_race/ui/presentation/timesheet/timesheet_route_args.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Dashboard strip: search, filter → see-all screen, up to 10 project tiles.
class TmDashboardProjectsSection extends StatefulWidget {
  const TmDashboardProjectsSection({
    super.key,
    required this.projects,
    required this.onProjectTap,
    this.maxOnDashboard = 10,
  });

  final List<Project> projects;
  final void Function(Project project) onProjectTap;
  final int maxOnDashboard;

  @override
  State<TmDashboardProjectsSection> createState() =>
      _TmDashboardProjectsSectionState();
}

class _TmDashboardProjectsSectionState extends State<TmDashboardProjectsSection> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final q = _searchQuery.toLowerCase();
    final filtered = widget.projects.where((project) {
      if (q.isEmpty) return true;
      return project.name.toLowerCase().contains(q) ||
          project.woRefNo.toLowerCase().contains(q) ||
          project.code.toLowerCase().contains(q);
    }).toList();

    final visible = filtered.take(widget.maxOnDashboard).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TmSearchField(
                hintText: 'Search projects',
                onDebouncedChanged: (value) =>
                    setState(() => _searchQuery = value.trim()),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Filters',
              onPressed: () => Navigator.of(context).pushNamed(
                TimesheetRouteNames.projectPicker,
                arguments: const TimesheetProjectsListArgs(
                  showFiltersInitially: true,
                ),
              ),
              icon: Icon(
                PhosphorIcons.funnel(),
                color: TimesheetModuleColors.navy,
              ),
            ),
          ],
        ),
        const SizedBox(height: TimesheetModuleLayout.cardSpacing),
        if (visible.isEmpty)
          const TimesheetEmptyState(message: 'No projects match your search')
        else
          for (var i = 0; i < visible.length; i++) ...[
            TmAnimatedListItem(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: TmProjectCard.fromProject(
                  visible[i],
                  onTap: () => widget.onProjectTap(visible[i]),
                ),
              ),
            ),
            const SizedBox(height: TimesheetModuleLayout.cardSpacing),
          ],
        const SizedBox(height: TimesheetModuleLayout.sectionGap),
        if (filtered.length > widget.maxOnDashboard)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).pushNamed(
                TimesheetRouteNames.projectPicker,
                arguments: const TimesheetProjectsListArgs(
                  showFiltersInitially: false,
                ),
              ),
              child: Text(
                'See more',
                style: TimesheetModuleTypography.body().copyWith(
                  color: TimesheetModuleColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
