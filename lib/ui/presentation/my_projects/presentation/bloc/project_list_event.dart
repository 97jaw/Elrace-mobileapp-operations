import 'package:el_race/ui/presentation/my_projects/domain/entities/project_entity.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/projects_group_hub_filters.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/projects_list_context.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_list_pagination.dart';

abstract class ProjectListEvent {}

class LoadProjectsEvent extends ProjectListEvent {
  final bool refresh;
  LoadProjectsEvent({this.refresh = false});
}

class LoadProjectsByPartnerEvent extends ProjectListEvent {
  final int partnerId;
  final bool refresh;

  LoadProjectsByPartnerEvent({required this.partnerId, this.refresh = false});
}

class LoadProjectsByFiltersEvent extends ProjectListEvent {
  final int? agreementId;
  final int? partnerId;
  final int? projectManagerId;
  final int? cityId;
  final String? keyword;
  final ProjectsGroupHubFilters? hubFilters;
  /// When group bucket id is synthetic (v1), filter by display name client-side.
  final String? bucketName;
  final ProjectsListContext? bucketContext;
  final bool refresh;
  final int limit;
  final int offset;

  LoadProjectsByFiltersEvent({
    this.agreementId,
    this.partnerId,
    this.projectManagerId,
    this.cityId,
    this.keyword,
    this.hubFilters,
    this.bucketName,
    this.bucketContext,
    this.refresh = false,
    this.limit = kProjectsListPageSize,
    this.offset = 0,
  });
}

class GetProjectAttachmentsEvent extends ProjectListEvent {
  final String projectId;
  final String? folderType;

  GetProjectAttachmentsEvent(this.projectId, {this.folderType});
}

class LoadMoreProjectsEvent extends ProjectListEvent {}

class LoadPreloadedProjectsEvent extends ProjectListEvent {
  LoadPreloadedProjectsEvent(this.projects);

  final List<ProjectEntity> projects;
}
