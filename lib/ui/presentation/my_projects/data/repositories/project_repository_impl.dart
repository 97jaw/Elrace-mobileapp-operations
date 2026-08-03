import 'package:el_race/ui/presentation/my_projects/data/datasources/project_remote_datasource.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/partner_model.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/projects_paged_result.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_model.dart';
import 'package:el_race/ui/presentation/my_projects/domain/entities/attachment_entity.dart';
import 'package:el_race/ui/presentation/my_projects/domain/entities/partner_entity.dart';
import 'package:el_race/ui/presentation/my_projects/domain/entities/project_entity.dart';
import 'package:el_race/ui/presentation/my_projects/domain/entities/projects_page.dart';
import 'package:el_race/ui/presentation/my_projects/domain/repositories/project_repository.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/projects_group_hub_filters.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/projects_list_context.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_group_hub_filter_applier.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_list_ordering.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_list_pagination.dart';

class ProjectRepositoryImpl implements ProjectRepository {
  final ProjectRemoteDataSource remoteDataSource;

  ProjectRepositoryImpl(this.remoteDataSource);

  @override
  Future<List<ProjectEntity>> getProjects() async {
    final List<ProjectModel> models = await remoteDataSource.fetchProjects();
    return models
        .map((model) => ProjectEntity(
              projectId: model.projectId,
              partnerId: model.partnerId,
              agreementId: model.agreementId,
              woRefNo: model.woRefNo,
              name: model.name,
              woAmount: model.woAmount,
              projectStatus: model.projectStatus,
              date: model.date,
              dateStart: model.dateStart,
              differenceDays: model.differenceDays,
              projectManagerPhoto: model.projectManagerPhoto,
              latitude: model.latitude,
              longitude: model.longitude,
              clientImageUrl: model.clientImageUrl,
              managerPhoto: model.managerPhoto,
              projectManagerName: model.projectManagerName,
              totalProgress: model.totalProgress,
              contractorName: model.contractorName,
              milestoneLabel: model.milestoneLabel,
              budgetLabel: model.budgetLabel,
              openIssuesCount: model.openIssuesCount,
              supervisors: model.supervisors,
            ))
        .toList();
  }

  @override
  Future<List<AttachmentEntity>> getProjectAttachement(String projectID,
      {String? folderType}) async {
    final List<AttachmentEntity> models = await remoteDataSource
        .fetchProjectAttachments(projectID, folderType: folderType);
    return models
        .map((model) => AttachmentEntity(
              name: model.name,
              type: model.type,
              url: model.url,
              source: model.source,
              isFile: model.isFile,
              folder: model.folder,
              id: model.id,
            ))
        .toList();
  }

  @override
  Future<List<PartnerEntity>> getPartnerProjects(
      {int? partnerId, String? keyword}) async {
    final List<PartnerModel> models =
        await remoteDataSource.fetchPartnerProjects(
      partnerId: partnerId,
      keyword: keyword,
    );
    return models
        .map((model) => PartnerEntity(
              id: model.id,
              name: model.name,
              icon: model.icon,
              workOrdersCount: model.workOrdersCount,
            ))
        .toList();
  }

  @override
  Future<List<ProjectEntity>> getProjectsByPartnerId(int partnerId) async {
    final List<ProjectModel> models =
        await remoteDataSource.fetchProjectsByPartnerId(partnerId);
    return models
        .map((model) => ProjectEntity(
              projectId: model.projectId,
              partnerId: model.partnerId,
              agreementId: model.agreementId,
              woRefNo: model.woRefNo,
              name: model.name,
              woAmount: model.woAmount,
              projectStatus: model.projectStatus,
              date: model.date,
              dateStart: model.dateStart,
              differenceDays: model.differenceDays,
              projectManagerPhoto: model.projectManagerPhoto,
              latitude: model.latitude,
              longitude: model.longitude,
              clientImageUrl: model.clientImageUrl,
              managerPhoto: model.managerPhoto,
              projectManagerName: model.projectManagerName,
              totalProgress: model.totalProgress,
              contractorName: model.contractorName,
              milestoneLabel: model.milestoneLabel,
              budgetLabel: model.budgetLabel,
              openIssuesCount: model.openIssuesCount,
              supervisors: model.supervisors,
            ))
        .toList();
  }

  ProjectEntity _toEntity(ProjectModel model) => ProjectEntity(
        projectId: model.projectId,
        partnerId: model.partnerId,
        agreementId: model.agreementId,
        woRefNo: model.woRefNo,
        name: model.name,
        woAmount: model.woAmount,
        projectStatus: model.projectStatus,
        date: model.date,
        dateStart: model.dateStart,
        differenceDays: model.differenceDays,
        projectManagerPhoto: model.projectManagerPhoto,
        latitude: model.latitude,
        longitude: model.longitude,
        clientImageUrl: model.clientImageUrl,
        managerPhoto: model.managerPhoto,
        projectManagerName: model.projectManagerName,
        totalProgress: model.totalProgress,
        contractorName: model.contractorName,
        milestoneLabel: model.milestoneLabel,
        budgetLabel: model.budgetLabel,
        openIssuesCount: model.openIssuesCount,
        supervisors: model.supervisors,
      );

  @override
  Future<ProjectsPage> getProjectsByFilters({
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
  }) async {
    final hasBucket = agreementId != null ||
        partnerId != null ||
        projectManagerId != null ||
        cityId != null;

    final ProjectsPagedResult page;
    if (!hasBucket && hubFilters != null) {
      page = await remoteDataSource.fetchProjectsPage(
        limit: limit,
        offset: offset,
        year: hubFilters.year,
        month: hubFilters.month,
        projectStatusCompute: hubFilters.projectStatusCompute,
        woRefNo: hubFilters.woRefNo,
        woTypeNoOffice: hubFilters.woTypeNoOffice,
        nameSearch: hubFilters.searchName,
        keyword: keyword,
        portfolio: true,
      );
    } else {
      page = await remoteDataSource.fetchProjectsByFilters(
        agreementId: agreementId,
        partnerId: partnerId,
        projectManagerId: projectManagerId,
        cityId: cityId,
        keyword: keyword,
        hubFilters: hubFilters,
        limit: limit,
        offset: offset,
      );
    }

    var entities = page.projects.map(_toEntity).toList(growable: false);
    entities = _applyHubFiltersIfNeeded(entities, hubFilters);
    entities = _applyBucketNameFilter(entities, bucketName, bucketContext);
    entities = ProjectsListOrdering.sortEntitiesDesc(entities);

    return ProjectsPage(
      projects: entities,
      total: page.total,
      limit: page.limit,
      offset: page.offset,
      hasMore: page.hasMore,
    );
  }

  List<ProjectEntity> _applyBucketNameFilter(
    List<ProjectEntity> projects,
    String? bucketName,
    ProjectsListContext? context,
  ) {
    if (bucketName == null || bucketName.trim().isEmpty || context == null) {
      return projects;
    }
    final norm = bucketName.trim().toLowerCase();
    return projects.where((p) {
      return switch (context) {
        ProjectsListContext.projectManager =>
          (p.projectManagerName ?? '').trim().toLowerCase() == norm,
        ProjectsListContext.client =>
          (p.partnerName ?? p.partnerId).trim().toLowerCase() == norm,
        ProjectsListContext.city =>
          (p.cityName ?? '').trim().toLowerCase() == norm,
        _ => true,
      };
    }).toList(growable: false);
  }

  List<ProjectEntity> _applyHubFiltersIfNeeded(
    List<ProjectEntity> projects,
    ProjectsGroupHubFilters? hubFilters,
  ) {
    if (hubFilters == null || !hubFilters.hasActiveFilters) return projects;
    if (remoteDataSource.projectsHubV2Available) return projects;
    return ProjectsGroupHubFilterApplier.applyEntities(projects, hubFilters);
  }
}
