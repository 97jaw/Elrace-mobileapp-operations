import 'package:el_race/ui/presentation/my_projects/data/datasources/project_documents_remote_datasource.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_documents_models.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/project_document_hub_kind.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/projects_group_hub_filters.dart';

class ProjectDocumentsRepository {
  ProjectDocumentsRepository(this._remote);

  final ProjectDocumentsRemoteDataSource _remote;

  Future<ProjectDocumentsDashboardData> getDashboard(
    ProjectsGroupHubFilters filters,
  ) =>
      _remote.fetchDashboard(filters);

  Future<({List<ProjectDocumentFolderProject> projects, int total, bool hasMore})>
      getFolderProjects({
    required ProjectDocumentHubKind kind,
    required ProjectsGroupHubFilters filters,
    String? keyword,
    int limit = 20,
    int offset = 0,
  }) =>
      _remote.fetchFolderProjects(
        kind: kind,
        filters: filters,
        keyword: keyword,
        limit: limit,
        offset: offset,
      );

  Future<ProjectDocumentsPagedFiles> getFiles({
    required ProjectsGroupHubFilters filters,
    ProjectDocumentHubKind? kind,
    int? projectId,
    String? fileName,
    int? uploaderId,
    int limit = 30,
    int offset = 0,
  }) =>
      _remote.fetchFiles(
        filters: filters,
        kind: kind,
        projectId: projectId,
        fileName: fileName,
        uploaderId: uploaderId,
        limit: limit,
        offset: offset,
      );

  Future<ProjectDocumentsPagedFiles> getProjectFiles({
    required int projectId,
    required ProjectDocumentHubKind kind,
    ProjectsGroupHubFilters filters = const ProjectsGroupHubFilters(),
    String? fileName,
    int? uploaderId,
    int limit = 50,
    int offset = 0,
  }) =>
      _remote.fetchProjectFiles(
        projectId: projectId,
        kind: kind,
        filters: filters,
        fileName: fileName,
        uploaderId: uploaderId,
        limit: limit,
        offset: offset,
      );

  Future<ProjectDocumentsPagedUploaders> getUploaders({
    required ProjectsGroupHubFilters filters,
    String? keyword,
    int limit = 20,
    int offset = 0,
  }) =>
      _remote.fetchUploaders(
        filters: filters,
        keyword: keyword,
        limit: limit,
        offset: offset,
      );

  Future<({List<ProjectDocumentFolderProject> projects, int total, bool hasMore})>
      getUploaderProjects({
    required int employeeId,
    required ProjectsGroupHubFilters filters,
    String? keyword,
    int limit = 20,
    int offset = 0,
  }) =>
      _remote.fetchUploaderProjects(
        employeeId: employeeId,
        filters: filters,
        keyword: keyword,
        limit: limit,
        offset: offset,
      );
}
