import 'package:el_race/ui/presentation/my_projects/data/models/project_documents_models.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/project_document_hub_kind.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/projects_group_hub_filters.dart';
import 'package:equatable/equatable.dart';

enum ProjectDocumentsView {
  dashboard,
  folderProjects,
  files,
  uploadedBy,
}

class ProjectDocumentsState extends Equatable {
  const ProjectDocumentsState({
    this.activeView = ProjectDocumentsView.dashboard,
    this.hubFilters = const ProjectsGroupHubFilters(),
    this.searchQuery = '',
    this.selectedKind = ProjectDocumentHubKind.workOrder,
    this.dashboardLoading = false,
    this.folderLoading = false,
    this.filesLoading = false,
    this.uploadersLoading = false,
    this.refreshing = false,
    this.error,
    this.dashboard,
    this.folderProjects = const [],
    this.folderHasMore = false,
    this.files = const [],
    this.filesHasMore = false,
    this.uploaders = const [],
    this.uploadersHasMore = false,
    this.initialProjectId,
    this.initialProjectTitle,
    this.tabSwitchLoading = false,
  });

  final ProjectDocumentsView activeView;
  final ProjectsGroupHubFilters hubFilters;
  final String searchQuery;
  final ProjectDocumentHubKind selectedKind;
  final bool dashboardLoading;
  final bool folderLoading;
  final bool filesLoading;
  final bool uploadersLoading;
  final bool refreshing;
  final String? error;
  final ProjectDocumentsDashboardData? dashboard;
  final List<ProjectDocumentFolderProject> folderProjects;
  final bool folderHasMore;
  final List<ProjectDocumentFileItem> files;
  final bool filesHasMore;
  final List<ProjectDocumentsUploaderItem> uploaders;
  final bool uploadersHasMore;
  final int? initialProjectId;
  final String? initialProjectTitle;
  final bool tabSwitchLoading;

  bool get hasActiveFilters => hubFilters.hasActiveFilters;

  bool get hasDocumentScopeFilters {
    final f = hubFilters;
    return f.year != null ||
        f.month != null ||
        (f.projectStatusCompute?.isNotEmpty == true) ||
        (f.woRefNo?.trim().isNotEmpty == true) ||
        (f.woTypeNoOffice?.isNotEmpty == true);
  }

  bool get showTabLoadingOverlay => tabSwitchLoading;

  /// Bottom bar slot highlight (decoupled from IndexedStack index).
  int get bottomBarIndex => switch (activeView) {
        ProjectDocumentsView.dashboard => 2,
        ProjectDocumentsView.files => 1,
        ProjectDocumentsView.uploadedBy => 3,
        ProjectDocumentsView.folderProjects => -1,
      };

  /// IndexedStack child index (decoupled from bottom bar slots).
  int get stackIndex => switch (activeView) {
        ProjectDocumentsView.dashboard => 0,
        ProjectDocumentsView.folderProjects => 1,
        ProjectDocumentsView.files => 2,
        ProjectDocumentsView.uploadedBy => 3,
      };

  ProjectDocumentsState copyWith({
    ProjectDocumentsView? activeView,
    ProjectsGroupHubFilters? hubFilters,
    String? searchQuery,
    ProjectDocumentHubKind? selectedKind,
    bool? dashboardLoading,
    bool? folderLoading,
    bool? filesLoading,
    bool? uploadersLoading,
    bool? refreshing,
    String? error,
    bool clearError = false,
    ProjectDocumentsDashboardData? dashboard,
    List<ProjectDocumentFolderProject>? folderProjects,
    bool? folderHasMore,
    List<ProjectDocumentFileItem>? files,
    bool? filesHasMore,
    List<ProjectDocumentsUploaderItem>? uploaders,
    bool? uploadersHasMore,
    int? initialProjectId,
    String? initialProjectTitle,
    bool? tabSwitchLoading,
  }) {
    return ProjectDocumentsState(
      activeView: activeView ?? this.activeView,
      hubFilters: hubFilters ?? this.hubFilters,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedKind: selectedKind ?? this.selectedKind,
      dashboardLoading: dashboardLoading ?? this.dashboardLoading,
      folderLoading: folderLoading ?? this.folderLoading,
      filesLoading: filesLoading ?? this.filesLoading,
      uploadersLoading: uploadersLoading ?? this.uploadersLoading,
      refreshing: refreshing ?? this.refreshing,
      error: clearError ? null : (error ?? this.error),
      dashboard: dashboard ?? this.dashboard,
      folderProjects: folderProjects ?? this.folderProjects,
      folderHasMore: folderHasMore ?? this.folderHasMore,
      files: files ?? this.files,
      filesHasMore: filesHasMore ?? this.filesHasMore,
      uploaders: uploaders ?? this.uploaders,
      uploadersHasMore: uploadersHasMore ?? this.uploadersHasMore,
      initialProjectId: initialProjectId ?? this.initialProjectId,
      initialProjectTitle: initialProjectTitle ?? this.initialProjectTitle,
      tabSwitchLoading: tabSwitchLoading ?? this.tabSwitchLoading,
    );
  }

  @override
  List<Object?> get props => [
        activeView,
        hubFilters,
        searchQuery,
        selectedKind,
        dashboardLoading,
        folderLoading,
        filesLoading,
        uploadersLoading,
        refreshing,
        error,
        dashboard,
        folderProjects,
        folderHasMore,
        files,
        filesHasMore,
        uploaders,
        uploadersHasMore,
        initialProjectId,
        initialProjectTitle,
        tabSwitchLoading,
      ];
}
