import 'package:el_race/ui/presentation/my_projects/domain/entities/project_entity.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_model.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/map/portfolio_project_status.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/projects_group_hub_filters.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_dashboard_aggregator.dart';

/// Client-side project filtering when rebuilding PM buckets or when the API
/// does not yet honor hub filter params on `get_projects`.
abstract final class ProjectsGroupHubFilterApplier {
  static List<ProjectModel> apply(
    List<ProjectModel> projects,
    ProjectsGroupHubFilters filters,
  ) {
    if (!filters.hasActiveFilters) return projects;
    return projects.where((p) => _matches(p, filters)).toList(growable: false);
  }

  /// Client-side filter for project list when v2 partner API is unavailable.
  static List<ProjectEntity> applyEntities(
    List<ProjectEntity> projects,
    ProjectsGroupHubFilters filters,
  ) {
    if (!filters.hasActiveFilters) return projects;
    return projects.where((p) => _matchesEntity(p, filters)).toList(growable: false);
  }

  static bool _matchesEntity(ProjectEntity p, ProjectsGroupHubFilters filters) {
    if (p is ProjectModel) return _matches(p, filters);
    return _matches(
      ProjectModel(
        projectId: p.projectId,
        partnerId: p.partnerId,
        agreementId: p.agreementId,
        woRefNo: p.woRefNo,
        name: p.name,
        woAmount: p.woAmount,
        projectStatus: p.projectStatus,
        date: p.date,
        dateStart: p.dateStart,
        differenceDays: p.differenceDays,
        projectManagerPhoto: p.projectManagerPhoto,
        latitude: p.latitude,
        longitude: p.longitude,
        clientImageUrl: p.clientImageUrl,
        managerPhoto: p.managerPhoto,
        projectManagerName: p.projectManagerName,
        projectManagerId: p.projectManagerId,
        projectStatusCompute: p.projectStatusCompute,
        projectNameArabic: p.projectNameArabic,
        woTypeNoOffice: p.woTypeNoOffice,
        partnerName: p.partnerName,
        cityId: p.cityId,
        cityName: p.cityName,
        totalProgress: p.totalProgress,
        contractorName: p.contractorName,
        milestoneLabel: p.milestoneLabel,
        budgetLabel: p.budgetLabel,
        openIssuesCount: p.openIssuesCount,
        supervisors: p.supervisors,
      ),
      filters,
    );
  }

  static bool _matches(ProjectModel p, ProjectsGroupHubFilters filters) {
    if (filters.year != null || filters.month != null) {
      final d = DateTime.tryParse(
        p.dateStart.isNotEmpty ? p.dateStart : p.date,
      );
      if (d == null) return false;
      if (filters.year != null && d.year != filters.year) return false;
      if (filters.month != null && d.month != filters.month) return false;
    }

    final status = filters.projectStatusCompute?.trim().toLowerCase();
    if (status != null && status.isNotEmpty) {
      switch (status) {
        case 'completed':
          if (!ProjectsDashboardAggregator.isCompletedProject(p)) return false;
          break;
        case 'in_progress':
          if (ProjectsDashboardAggregator.isCompletedProject(p)) return false;
          break;
        case 'on_map':
          if (!hasRealCoordinates(p)) return false;
          break;
        case 'unmapped':
          if (hasRealCoordinates(p)) return false;
          break;
        default:
          final compute =
              (p.projectStatusCompute ?? p.projectStatus).toLowerCase();
          if (compute != status) return false;
      }
    }

    final wo = filters.woRefNo?.trim().toLowerCase();
    if (wo != null && wo.isNotEmpty) {
      if (!p.woRefNo.toLowerCase().contains(wo)) return false;
    }

    final woType = filters.woTypeNoOffice?.trim().toLowerCase();
    if (woType != null && woType.isNotEmpty) {
      final raw = (p.woTypeNoOffice ?? '').toLowerCase();
      if (raw != woType) return false;
    }

    final q = filters.searchName?.trim().toLowerCase();
    if (q != null && q.isNotEmpty) {
      final en = p.name.toLowerCase();
      final ar = (p.projectNameArabic ?? '').toLowerCase();
      if (!en.contains(q) && !ar.contains(q)) return false;
    }

    return true;
  }
}
