import 'package:el_race/ui/presentation/my_projects/data/datasources/project_remote_datasource.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_manager_filter_item.dart';
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
    return ProjectsGroupListBuilder.fromProjects(
      filtered,
      mode,
      allowNameFallback: true,
    );
  }
}
