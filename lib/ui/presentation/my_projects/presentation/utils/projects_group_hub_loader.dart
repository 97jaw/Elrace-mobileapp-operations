import 'package:el_race/ui/presentation/my_projects/data/datasources/project_remote_datasource.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_manager_filter_item.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_manager_filter_item_extensions.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/projects_group_hub_filters.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_group_hub_filter_applier.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_group_list_builder.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_list_pagination.dart';

/// Group-by hub: **filter project/WO records first**, then aggregate buckets.
///
/// Uses v2 project list when deployed; v1 `get_projects` otherwise. Grouped
/// `clients/list` is not used for counts (v1 ignores hub filters and PM id=0).
class ProjectsGroupHubLoader {
  ProjectsGroupHubLoader({ProjectRemoteDataSource? dataSource})
      : _dataSource = dataSource ?? ProjectRemoteDataSource();

  final ProjectRemoteDataSource _dataSource;

  Future<List<ProjectManagerFilterItem>> load({
    required ProjectsGroupByMode mode,
    ProjectsGroupHubFilters filters = const ProjectsGroupHubFilters(),
  }) async {
    final projects = await _dataSource.fetchProjectsForGroupHub(
      filters: filters,
      maxItems: kProjectsGroupHubMaxProjects,
    );
    final filtered = ProjectsGroupHubFilterApplier.apply(projects, filters);
    var buckets = ProjectsGroupListBuilder.fromProjects(
      filtered,
      mode,
      allowNameFallback: true,
    );

    if (mode == ProjectsGroupByMode.client) {
      buckets = await _enrichClientNames(buckets);
    }
    return buckets;
  }

  /// `get_projects` often returns bare `partner_id` ints without `partner_name`.
  /// Patch display labels from `clients/list` group_by=client when needed.
  Future<List<ProjectManagerFilterItem>> _enrichClientNames(
    List<ProjectManagerFilterItem> buckets,
  ) async {
    final needsName = buckets.any((b) {
      final n = b.name.trim();
      return n.isEmpty ||
          n == b.id.toString() ||
          n.toLowerCase().startsWith('client #');
    });
    if (!needsName) return buckets;

    try {
      final named =
          await _dataSource.fetchClientsGroupedList(groupBy: 'client');
      if (named.isEmpty) return buckets;
      final byId = <int, ProjectManagerFilterItem>{
        for (final row in named)
          if (row.id > 0) row.id: row,
      };
      return buckets.map((b) {
        final match = byId[b.id];
        if (match == null) return b;
        final label = match.name.trim();
        if (label.isEmpty ||
            label == b.id.toString() ||
            label.toLowerCase().startsWith('client #')) {
          return b;
        }
        return b.copyWith(
          name: label,
          photoUrl: (b.photoUrl == null || b.photoUrl!.isEmpty)
              ? match.photoUrl
              : b.photoUrl,
        );
      }).toList(growable: false);
    } catch (_) {
      return buckets;
    }
  }
}
