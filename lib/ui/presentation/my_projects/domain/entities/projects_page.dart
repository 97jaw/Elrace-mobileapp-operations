import 'package:el_race/ui/presentation/my_projects/domain/entities/project_entity.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_list_pagination.dart';

/// One page of projects from a paginated listing API.
class ProjectsPage {
  const ProjectsPage({
    required this.projects,
    required this.total,
    required this.limit,
    required this.offset,
    required this.hasMore,
  });

  final List<ProjectEntity> projects;
  final int total;
  final int limit;
  final int offset;
  final bool hasMore;

  factory ProjectsPage.empty() => const ProjectsPage(
        projects: [],
        total: 0,
        limit: kProjectsListPageSize,
        offset: 0,
        hasMore: false,
      );
}
