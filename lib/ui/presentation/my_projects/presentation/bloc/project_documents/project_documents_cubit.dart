import 'package:bloc/bloc.dart';
import 'package:el_race/ui/presentation/my_projects/data/datasources/project_documents_remote_datasource.dart';
import 'package:el_race/ui/presentation/my_projects/data/repositories/project_documents_repository.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_documents/project_documents_state.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/project_document_hub_kind.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/projects_group_hub_filters.dart';

class ProjectDocumentsCubit extends Cubit<ProjectDocumentsState> {
  ProjectDocumentsCubit({
    ProjectDocumentsRepository? repository,
    int? initialProjectId,
    String? initialProjectTitle,
    ProjectDocumentHubKind? initialKind,
  })  : _repo = repository ??
            ProjectDocumentsRepository(ProjectDocumentsRemoteDataSource()),
        super(ProjectDocumentsState(
          initialProjectId: initialProjectId,
          initialProjectTitle: initialProjectTitle,
          selectedKind: initialKind ?? ProjectDocumentHubKind.workOrder,
          activeView: initialProjectId != null
              ? ProjectDocumentsView.folderProjects
              : ProjectDocumentsView.dashboard,
        ));

  final ProjectDocumentsRepository _repo;

  static const _folderPageSize = 20;
  static const _filesPageSize = 30;
  static const _uploadersPageSize = 20;

  Future<void> initialize() async {
    emit(state.copyWith(tabSwitchLoading: true));
    await refreshAll();
    if (state.initialProjectId != null) {
      await loadFolderProjects(reset: true);
    }
    emit(state.copyWith(tabSwitchLoading: false));
  }

  Future<void> refreshAll() async {
    emit(state.copyWith(refreshing: true, clearError: true));
    await Future.wait([
      loadDashboard(),
      loadFolderProjects(reset: true),
      loadFiles(reset: true),
      loadUploaders(reset: true),
    ]);
    emit(state.copyWith(
      refreshing: false,
    ));
  }

  void onBottomBarTap(int index) {
    switch (index) {
      case 0:
        refreshAll();
        return;
      case 1:
        switchView(ProjectDocumentsView.files);
        return;
      case 2:
        switchView(ProjectDocumentsView.dashboard);
        return;
      case 3:
        switchView(ProjectDocumentsView.uploadedBy);
        return;
      case 4:
        return;
    }
  }

  bool _hasCachedData(ProjectDocumentsView view) => switch (view) {
        ProjectDocumentsView.dashboard => state.dashboard != null,
        ProjectDocumentsView.folderProjects => state.folderProjects.isNotEmpty,
        ProjectDocumentsView.files => state.files.isNotEmpty,
        ProjectDocumentsView.uploadedBy => state.uploaders.isNotEmpty,
      };

  void switchView(ProjectDocumentsView view) {
    if (view == state.activeView) return;
    final showLoader = !_hasCachedData(view);
    emit(state.copyWith(
      activeView: view,
      tabSwitchLoading: showLoader,
      clearError: true,
    ));
    if (!showLoader) return;
    _loadActiveViewTab().whenComplete(() {
      if (!isClosed) {
        emit(state.copyWith(tabSwitchLoading: false));
      }
    });
  }

  void backToDashboard() {
    if (state.activeView == ProjectDocumentsView.dashboard) return;
    emit(state.copyWith(
      activeView: ProjectDocumentsView.dashboard,
      tabSwitchLoading: false,
      clearError: true,
    ));
  }

  void openFolderFromDashboard(ProjectDocumentHubKind kind) {
    final kindChanged = kind != state.selectedKind;
    final needsLoad = kindChanged || state.folderProjects.isEmpty;
    emit(state.copyWith(
      selectedKind: kind,
      activeView: ProjectDocumentsView.folderProjects,
      folderProjects: kindChanged ? const [] : state.folderProjects,
      tabSwitchLoading: needsLoad,
      clearError: true,
    ));
    if (!needsLoad) return;
    loadFolderProjects(reset: true).whenComplete(() {
      if (!isClosed) {
        emit(state.copyWith(tabSwitchLoading: false));
      }
    });
  }

  Future<void> _loadActiveViewTab() {
    return switch (state.activeView) {
      ProjectDocumentsView.dashboard => loadDashboard(),
      ProjectDocumentsView.folderProjects => loadFolderProjects(reset: true),
      ProjectDocumentsView.files => loadFiles(reset: true),
      ProjectDocumentsView.uploadedBy => loadUploaders(reset: true),
    };
  }

  void selectKind(ProjectDocumentHubKind kind) {
    emit(state.copyWith(
      selectedKind: kind,
      clearError: true,
    ));
    loadFolderProjects(reset: true);
  }

  void setHubFilters(ProjectsGroupHubFilters filters) =>
      setDocumentFilters(filters);

  void setDocumentFilters(ProjectsGroupHubFilters filters) {
    final merged = ProjectsGroupHubFilters(
      year: filters.year,
      month: filters.month,
      projectStatusCompute: filters.projectStatusCompute,
      woRefNo: filters.woRefNo,
      woTypeNoOffice: filters.woTypeNoOffice,
      searchName: state.hubFilters.searchName,
    );
    emit(state.copyWith(hubFilters: merged, clearError: true));
    refreshAll();
  }

  void clearHubFilters() {
    setDocumentFilters(const ProjectsGroupHubFilters());
  }

  void setSearchQuery(String query) {
    if (state.activeView == ProjectDocumentsView.dashboard) {
      final trimmed = query.trim();
      final filters = ProjectsGroupHubFilters(
        year: state.hubFilters.year,
        month: state.hubFilters.month,
        projectStatusCompute: state.hubFilters.projectStatusCompute,
        woRefNo: state.hubFilters.woRefNo,
        woTypeNoOffice: state.hubFilters.woTypeNoOffice,
        searchName: trimmed.isEmpty ? null : trimmed,
      );
      emit(state.copyWith(
        searchQuery: query,
        hubFilters: filters,
        tabSwitchLoading: state.dashboard == null,
        clearError: true,
      ));
      loadDashboard().whenComplete(() {
        if (!isClosed) {
          emit(state.copyWith(tabSwitchLoading: false));
        }
      });
      return;
    }

    emit(state.copyWith(
      searchQuery: query,
      clearError: true,
    ));
    final loader = switch (state.activeView) {
      ProjectDocumentsView.folderProjects => state.folderProjects.isEmpty,
      ProjectDocumentsView.files => state.files.isEmpty,
      ProjectDocumentsView.uploadedBy => state.uploaders.isEmpty,
      ProjectDocumentsView.dashboard => false,
    };
    if (loader) emit(state.copyWith(tabSwitchLoading: true));

    Future<void> loadFuture = switch (state.activeView) {
      ProjectDocumentsView.folderProjects => loadFolderProjects(reset: true),
      ProjectDocumentsView.files => loadFiles(reset: true),
      ProjectDocumentsView.uploadedBy => loadUploaders(reset: true),
      ProjectDocumentsView.dashboard => Future.value(),
    };

    loadFuture.whenComplete(() {
      if (!isClosed) {
        emit(state.copyWith(tabSwitchLoading: false));
      }
    });
  }

  Future<void> loadDashboard() async {
    emit(state.copyWith(dashboardLoading: true, clearError: true));
    try {
      final data = await _repo.getDashboard(state.hubFilters);
      emit(state.copyWith(dashboardLoading: false, dashboard: data));
    } on ProjectDocumentsApiException catch (e) {
      emit(state.copyWith(dashboardLoading: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(
        dashboardLoading: false,
        error: 'Failed to load documents dashboard',
      ));
    }
  }

  Future<void> loadFolderProjects({bool reset = false}) async {
    emit(state.copyWith(folderLoading: true, clearError: true));
    try {
      final offset = reset ? 0 : state.folderProjects.length;
      final result = await _repo.getFolderProjects(
        kind: state.selectedKind,
        filters: state.hubFilters,
        keyword: state.searchQuery,
        limit: _folderPageSize,
        offset: offset,
      );
      final merged = reset
          ? result.projects
          : [...state.folderProjects, ...result.projects];
      final filtered = state.initialProjectId != null
          ? merged
              .where((p) => p.projectId == state.initialProjectId)
              .toList()
          : merged;
      emit(state.copyWith(
        folderLoading: false,
        folderProjects: filtered,
        folderHasMore: state.initialProjectId != null ? false : result.hasMore,
      ));
    } on ProjectDocumentsApiException catch (e) {
      emit(state.copyWith(folderLoading: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(
        folderLoading: false,
        error: 'Failed to load projects',
      ));
    }
  }

  Future<void> loadFiles({bool reset = false}) async {
    emit(state.copyWith(filesLoading: true, clearError: true));
    try {
      final offset = reset ? 0 : state.files.length;
      final result = await _repo.getFiles(
        filters: state.hubFilters,
        fileName: state.searchQuery,
        limit: _filesPageSize,
        offset: offset,
      );
      final merged =
          reset ? result.files : [...state.files, ...result.files];
      emit(state.copyWith(
        filesLoading: false,
        files: merged,
        filesHasMore: result.hasMore,
      ));
    } on ProjectDocumentsApiException catch (e) {
      emit(state.copyWith(filesLoading: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(filesLoading: false, error: 'Failed to load files'));
    }
  }

  Future<void> loadUploaders({bool reset = false}) async {
    emit(state.copyWith(uploadersLoading: true, clearError: true));
    try {
      final offset = reset ? 0 : state.uploaders.length;
      final result = await _repo.getUploaders(
        filters: state.hubFilters,
        keyword: state.searchQuery,
        limit: _uploadersPageSize,
        offset: offset,
      );
      final merged =
          reset ? result.uploaders : [...state.uploaders, ...result.uploaders];
      emit(state.copyWith(
        uploadersLoading: false,
        uploaders: merged,
        uploadersHasMore: result.hasMore,
      ));
    } on ProjectDocumentsApiException catch (e) {
      emit(state.copyWith(uploadersLoading: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(
        uploadersLoading: false,
        error: 'Failed to load uploaders',
      ));
    }
  }
}
