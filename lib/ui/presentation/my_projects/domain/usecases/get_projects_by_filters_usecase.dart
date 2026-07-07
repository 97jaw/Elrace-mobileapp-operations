import 'package:el_race/ui/presentation/my_projects/domain/entities/projects_page.dart';
import 'package:el_race/ui/presentation/my_projects/domain/repositories/project_repository.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/projects_group_hub_filters.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/projects_list_context.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_list_pagination.dart';

class GetProjectsByFiltersUseCase {
  GetProjectsByFiltersUseCase({required this.repository});

  final ProjectRepository repository;

  Future<ProjectsPage> call({
    int? agreementId,
    int? partnerId,
    int? projectManagerId,
    int? cityId,
    String? keyword,
    ProjectsGroupHubFilters? hubFilters,
    String? bucketName,
    ProjectsListContext? bucketContext,
    int limit = kProjectsListPageSize,
    int offset = 0,
  }) {
    return repository.getProjectsByFilters(
      agreementId: agreementId,
      partnerId: partnerId,
      projectManagerId: projectManagerId,
      cityId: cityId,
      keyword: keyword,
      hubFilters: hubFilters,
      bucketName: bucketName,
      bucketContext: bucketContext,
      limit: limit,
      offset: offset,
    );
  }
}
