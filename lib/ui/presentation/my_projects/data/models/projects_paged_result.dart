import 'package:el_race/ui/presentation/my_projects/data/models/project_model.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_list_pagination.dart';

/// Paginated project list response from ERP listing APIs.
class ProjectsPagedResult {
  const ProjectsPagedResult({
    required this.projects,
    required this.total,
    required this.limit,
    required this.offset,
    required this.hasMore,
  });

  final List<ProjectModel> projects;
  final int total;
  final int limit;
  final int offset;
  final bool hasMore;

  factory ProjectsPagedResult.empty() => const ProjectsPagedResult(
        projects: [],
        total: 0,
        limit: kProjectsListPageSize,
        offset: 0,
        hasMore: false,
      );
}
