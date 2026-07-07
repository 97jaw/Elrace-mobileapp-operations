import 'package:el_race/ui/presentation/my_projects/data/models/projects_dashboard_summary_model.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/user_project_model.dart';
import 'package:el_race/ui/presentation/my_projects/domain/entities/project_entity.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_dashboard_access.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';

/// Portfolio-level stat boxes for the Projects dashboard.
class ProjectsDashboardBoxStats {
  const ProjectsDashboardBoxStats({
    required this.agreementsCount,
    required this.totalProjects,
    required this.portfolioValueAed,
    required this.delayedProjects,
  });

  final int agreementsCount;
  final int totalProjects;
  final double portfolioValueAed;
  final int delayedProjects;
}

/// Dashboard status filter chip kinds.
enum ProjectsStatusFilterKind {
  inProgress,
  completed,
  invoiced,
}

/// Status breakdown chips for the KPI strip.
class ProjectsDashboardStripStats {
  const ProjectsDashboardStripStats({
    required this.inProgress,
    required this.completed,
    required this.invoiced,
  });

  final int inProgress;
  final int completed;
  final int invoiced;
}

class ProjectsDashboardAggregator {
  static String normalizePhotoUrl(String? raw) {
    final trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.contains('erp.elrace.compublic')) {
      return trimmed.replaceAll(
        'erp.elrace.compublic',
        'erp.elrace.com/public',
      );
    }
    return trimmed;
  }

  static String featuredPhotoUrl({
    List<UserProjectModel>? agreements,
    ProjectsDashboardSummaryModel? summary,
  }) {
    final fromSummary =
        normalizePhotoUrl(summary?.featuredClientPhoto);
    if (fromSummary.isNotEmpty) return fromSummary;

    if (agreements != null) {
      for (final a in agreements) {
        final url = normalizePhotoUrl(a.photoUrl);
        if (url.isNotEmpty) return url;
      }
    }
    return '';
  }

  static ProjectsDashboardBoxStats boxStatsFromSummary(
    ProjectsDashboardSummaryModel summary,
  ) {
    return ProjectsDashboardBoxStats(
      agreementsCount: summary.agreementsCount,
      totalProjects: summary.totalProjects,
      portfolioValueAed: summary.totalValueAed,
      delayedProjects: summary.delayedProjects,
    );
  }

  static ProjectsDashboardStripStats stripStatsFromSummary(
    ProjectsDashboardSummaryModel summary,
  ) {
    return ProjectsDashboardStripStats(
      inProgress: summary.inProgress,
      completed: summary.completed,
      invoiced: summary.invoiced,
    );
  }

  /// KPI boxes from domain-scoped agreements (header counts).
  static ProjectsDashboardBoxStats computeBoxStats({
    required List<UserProjectModel> agreements,
    Map<String, dynamic>? widgetRecordMap,
    List<ProjectEntity>? domainProjects,
  }) {
    final agreementsCount = agreements.length;
    final portfolioValueAed = agreements.fold<double>(
      0,
      (sum, a) => sum + a.totalProjectsAmount,
    );
    final totalProjects = domainProjects != null
        ? domainProjects.length
        : agreements.fold<int>(0, (sum, a) => sum + a.totalProjects);

    final delayed = domainProjects != null
        ? _countDelayedProjects(domainProjects)
        : _parseInt(widgetRecordMap?['delayed_projects']);

    return ProjectsDashboardBoxStats(
      agreementsCount: agreementsCount,
      totalProjects: totalProjects,
      portfolioValueAed: portfolioValueAed,
      delayedProjects: delayed,
    );
  }

  /// Header + status stats with management bypass for domain scope.
  static ProjectsDashboardBoxStats resolveBoxStats({
    required List<UserProjectModel> agreements,
    required List<ProjectEntity> domainProjects,
    ProjectsDashboardSummaryModel? summary,
    Map<String, dynamic>? widgetRecordMap,
  }) {
    if (ProjectsDashboardAccess.bypassesDomainScope && summary != null) {
      return boxStatsFromSummary(summary);
    }
    return computeBoxStats(
      agreements: agreements,
      widgetRecordMap: widgetRecordMap,
      domainProjects: domainProjects,
    );
  }

  static ProjectsDashboardStripStats? resolveStripStats({
    required List<ProjectEntity> domainProjects,
    ProjectsDashboardSummaryModel? summary,
  }) {
    if (ProjectsDashboardAccess.bypassesDomainScope && summary != null) {
      return stripStatsFromSummary(summary);
    }
    return computeStripStats(domainProjects);
  }

  static int _countDelayedProjects(List<ProjectEntity> projects) {
    var count = 0;
    for (final p in projects) {
      final days = p.differenceDays;
      if (days != null && days < 0 && !isCompletedProject(p)) {
        count++;
      }
    }
    return count;
  }

  static String _normKey(String? value) =>
      (value ?? '').trim().toLowerCase();

  /// Restricts [get_projects] rows to agreements from [clients/list].
  ///
  /// Prefer v2 portfolio APIs (server-side domain). This is a v1 fallback matcher.
  static List<ProjectEntity> filterProjectsForAccessibleAgreements({
    required List<ProjectEntity> projects,
    required List<UserProjectModel> agreements,
  }) {
    if (agreements.isEmpty) return const [];

    final clientNames = <String>{};
    final agreementNames = <String>{};
    final agreementCodes = <String>{};
    final agreementIds = <int>{};

    for (final a in agreements) {
      final client = _normKey(a.projectName);
      if (client.isNotEmpty) clientNames.add(client);

      final name = _normKey(a.agreementName);
      if (name.isNotEmpty) agreementNames.add(name);

      final code = _normKey(a.agreementNo);
      if (code.isNotEmpty) agreementCodes.add(code);

      final id = a.agreementId;
      if (id != null && id > 0) agreementIds.add(id);
    }

    return projects.where((p) {
      final partnerLabel = _projectPartnerLabel(p);
      if (partnerLabel.isNotEmpty && clientNames.contains(partnerLabel)) {
        return true;
      }

      final agreementLabel = _normKey(p.agreementId);
      if (agreementLabel.isNotEmpty &&
          agreementLabel != 'false' &&
          (agreementNames.contains(agreementLabel) ||
              agreementCodes.contains(agreementLabel))) {
        return true;
      }

      final agreementNumericId = int.tryParse(p.agreementId.trim());
      if (agreementNumericId != null &&
          agreementNumericId > 0 &&
          agreementIds.contains(agreementNumericId)) {
        return true;
      }

      return false;
    }).toList(growable: false);
  }

  static String _projectPartnerLabel(ProjectEntity p) {
    final name = _normKey(p.partnerName);
    if (name.isNotEmpty && !_isNumericKey(name)) return name;

    final raw = _normKey(p.partnerId);
    if (raw.isNotEmpty && raw != 'false' && raw != '0' && !_isNumericKey(raw)) {
      return raw;
    }
    return '';
  }

  static bool _isNumericKey(String value) =>
      int.tryParse(value.trim()) != null;

  static MyProjectsRecord? widgetRecordFromLogin(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    return MyProjectsRecord.fromMap(map);
  }

  /// Client-side fallback from [get_projects] list.
  static ProjectsDashboardStripStats? computeStripStats(
    List<ProjectEntity>? projects,
  ) {
    if (projects == null) return null;
    var completed = 0;
    var invoiced = 0;
    var inProgress = 0;
    for (final p in projects) {
      if (isInvoicedProject(p)) {
        invoiced++;
      } else if (isCompletedProject(p)) {
        completed++;
      } else {
        inProgress++;
      }
    }
    return ProjectsDashboardStripStats(
      inProgress: inProgress,
      completed: completed,
      invoiced: invoiced,
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _normalizedProjectStatus(dynamic raw) {
    final s = (raw ?? '').toString().trim().toLowerCase();
    return s.replaceAll('_', ' ');
  }

  static bool _isCompletedStatus(String status) {
    return status.contains('completed') ||
        status.contains('complete') ||
        status.contains('done') ||
        status.contains('closed') ||
        status.contains('finish') ||
        status.contains('finished');
  }

  static bool isCompletedProject(ProjectEntity project) =>
      _isCompletedStatus(_normalizedProjectStatus(project.projectStatus));

  static bool isInvoicedProject(ProjectEntity project) {
    final compute = (project.projectStatusCompute ?? '').trim().toLowerCase();
    if (compute == 'invoiced') return true;
    final status = _normalizedProjectStatus(project.projectStatus);
    return status.contains('invoiced') || status.contains('invoice');
  }

  /// Filters access-scoped projects for a dashboard status chip.
  static List<ProjectEntity> filterByStatusKind({
    required List<ProjectEntity> projects,
    required ProjectsStatusFilterKind kind,
  }) {
    switch (kind) {
      case ProjectsStatusFilterKind.completed:
        return projects
            .where((p) => isCompletedProject(p) && !isInvoicedProject(p))
            .toList(growable: false);
      case ProjectsStatusFilterKind.invoiced:
        return projects.where(isInvoicedProject).toList(growable: false);
      case ProjectsStatusFilterKind.inProgress:
        return projects
            .where(
              (p) => !isCompletedProject(p) && !isInvoicedProject(p),
            )
            .toList(growable: false);
    }
  }
}
