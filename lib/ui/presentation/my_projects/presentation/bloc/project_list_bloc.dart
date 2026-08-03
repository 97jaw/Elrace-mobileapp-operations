import 'package:el_race/ui/presentation/my_projects/domain/entities/attachment_entity.dart';
import 'package:el_race/ui/presentation/my_projects/domain/entities/project_entity.dart';
import 'package:el_race/ui/presentation/my_projects/domain/usecases/get_projects_by_filters_usecase.dart';
import 'package:el_race/ui/presentation/my_projects/domain/usecases/get_projects_by_partner_usecase.dart';
import 'package:el_race/ui/presentation/my_projects/domain/usecases/get_projects_usecase.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_list_event.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_list_state.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_list_ordering.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_list_pagination.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProjectListBloc extends Bloc<ProjectListEvent, ProjectListState> {
  static ProjectListBloc get(BuildContext context) => BlocProvider.of(context);

  final GetProjectsUseCase getProjectsUseCase;
  final GetProjectAttachmentsUseCase getProjectAttachmentsUseCase;
  final GetProjectsByPartnerUseCase? getProjectsByPartnerUseCase;
  final GetProjectsByFiltersUseCase? getProjectsByFiltersUseCase;

  List<ProjectEntity> projects = [];
  List<AttachmentEntity> projectAttacmentList = [];
  List<ProjectEntity> _allProjects = [];
  List<ProjectEntity> visibleProjects = [];

  bool _serverPaginated = false;
  bool _serverHasMore = false;
  bool isLoadingMore = false;
  bool _filtersLoading = false;
  LoadProjectsByFiltersEvent? _lastFiltersEvent;
  int _filtersRequestSeq = 0;

  int _clientLoadedPages = 0;

  bool get hasMoreProjects => _serverPaginated
      ? _serverHasMore
      : visibleProjects.length < _allProjects.length;

  List<ProjectEntity> get allProjects =>
      List<ProjectEntity>.unmodifiable(_allProjects);

  int get totalProjectsCount => _allProjects.length;

  ProjectListBloc({
    required this.getProjectsUseCase,
    required this.getProjectAttachmentsUseCase,
    this.getProjectsByPartnerUseCase,
    this.getProjectsByFiltersUseCase,
  }) : super(ProjectListInitial()) {
    on<LoadProjectsEvent>(_onLoadProjects);
    on<LoadProjectsByPartnerEvent>(_onLoadProjectsByPartner);
    on<LoadProjectsByFiltersEvent>(_onLoadProjectsByFilters);
    on<LoadMoreProjectsEvent>(_onLoadMoreProjects);
    on<LoadPreloadedProjectsEvent>(_onLoadPreloadedProjects);

    on<GetProjectAttachmentsEvent>(
        (GetProjectAttachmentsEvent event, emit) async {
      emit(ProjectAttachmentsLoading());
      try {
        projectAttacmentList = await getProjectAttachmentsUseCase(
          event.projectId,
          folderType: event.folderType,
        );
        emit(const ProjectAttachmentsLoaded());
      } catch (e) {
        emit(ProjectAttachmentsError(e.toString()));
      }
    });
  }

  static bool _sameFilters(
    LoadProjectsByFiltersEvent a,
    LoadProjectsByFiltersEvent b,
  ) {
    return a.agreementId == b.agreementId &&
        a.partnerId == b.partnerId &&
        a.projectManagerId == b.projectManagerId &&
        a.cityId == b.cityId &&
        a.keyword == b.keyword &&
        a.hubFilters == b.hubFilters &&
        a.bucketName == b.bucketName &&
        a.bucketContext == b.bucketContext;
  }

  void _resetClientPagination() {
    _clientLoadedPages = _allProjects.isEmpty ? 0 : 1;
    visibleProjects = _allProjects
        .take(kProjectsListPageSize *
            (_clientLoadedPages == 0 ? 0 : _clientLoadedPages))
        .toList();
  }

  Future<void> _onLoadProjects(LoadProjectsEvent event, Emitter emit) async {
    if (_allProjects.isNotEmpty && !event.refresh) return;
    emit(ProjectListLoading());
    try {
      _serverPaginated = false;
      _serverHasMore = false;
      _allProjects =
          ProjectsListOrdering.sortEntitiesDesc(await getProjectsUseCase());
      projects = _allProjects;
      _resetClientPagination();
      emit(ProjectListLoaded());
    } catch (e) {
      emit(ProjectListError(e.toString()));
    }
  }

  Future<void> _onLoadProjectsByPartner(
      LoadProjectsByPartnerEvent event, Emitter emit) async {
    if (getProjectsByFiltersUseCase == null) {
      emit(ProjectListError('Projects filters use case not available'));
      return;
    }
    add(LoadProjectsByFiltersEvent(
      partnerId: event.partnerId,
      refresh: event.refresh,
    ));
  }

  Future<void> _onLoadProjectsByFilters(
      LoadProjectsByFiltersEvent event, Emitter emit) async {
    if (getProjectsByFiltersUseCase == null) {
      emit(ProjectListError('Projects filters use case not available'));
      return;
    }

    final isAppend = event.offset > 0;

    if (!isAppend &&
        _filtersLoading &&
        _lastFiltersEvent != null &&
        _sameFilters(event, _lastFiltersEvent!)) {
      return;
    }

    final requestId = ++_filtersRequestSeq;

    _lastFiltersEvent = LoadProjectsByFiltersEvent(
      agreementId: event.agreementId,
      partnerId: event.partnerId,
      projectManagerId: event.projectManagerId,
      cityId: event.cityId,
      keyword: event.keyword,
      hubFilters: event.hubFilters,
      bucketName: event.bucketName,
      bucketContext: event.bucketContext,
    );

    if (!isAppend) {
      _filtersLoading = true;
      emit(ProjectListLoading());
      _allProjects = [];
      visibleProjects = [];
    } else {
      if (isLoadingMore) return;
      isLoadingMore = true;
      emit(ProjectListLoaded());
    }

    try {
      final page = await getProjectsByFiltersUseCase!(
        agreementId: event.agreementId,
        partnerId: event.partnerId,
        projectManagerId: event.projectManagerId,
        cityId: event.cityId,
        keyword: event.keyword,
        hubFilters: event.hubFilters,
        bucketName: event.bucketName,
        bucketContext: event.bucketContext,
        limit: event.limit,
        offset: event.offset,
      );

      if (requestId != _filtersRequestSeq) return;

      _serverPaginated = true;
      _serverHasMore = page.hasMore;

      if (isAppend) {
        _allProjects = ProjectsListOrdering.sortEntitiesDesc([
          ..._allProjects,
          ...page.projects,
        ]);
      } else {
        _allProjects = ProjectsListOrdering.sortEntitiesDesc(page.projects);
      }
      projects = _allProjects;
      visibleProjects = List<ProjectEntity>.from(_allProjects);
      isLoadingMore = false;
      _filtersLoading = false;
      emit(ProjectListLoaded());
    } catch (e) {
      if (requestId != _filtersRequestSeq) return;
      isLoadingMore = false;
      _filtersLoading = false;
      emit(ProjectListError(e.toString()));
    }
  }

  void _onLoadPreloadedProjects(
      LoadPreloadedProjectsEvent event, Emitter emit) {
    _serverPaginated = false;
    _serverHasMore = false;
    _lastFiltersEvent = null;
    _filtersLoading = false;
    _allProjects = ProjectsListOrdering.sortEntitiesDesc(event.projects);
    projects = _allProjects;
    _resetClientPagination();
    emit(ProjectListLoaded());
  }

  Future<void> _onLoadMoreProjects(
      LoadMoreProjectsEvent event, Emitter emit) async {
    if (_serverPaginated) {
      if (!_serverHasMore || isLoadingMore || _lastFiltersEvent == null) {
        return;
      }
      final filters = _lastFiltersEvent!;
      add(LoadProjectsByFiltersEvent(
        agreementId: filters.agreementId,
        partnerId: filters.partnerId,
        projectManagerId: filters.projectManagerId,
        cityId: filters.cityId,
        keyword: filters.keyword,
        hubFilters: filters.hubFilters,
        bucketName: filters.bucketName,
        bucketContext: filters.bucketContext,
        offset: _allProjects.length,
        limit: kProjectsListPageSize,
      ));
      return;
    }

    if (!hasMoreProjects) return;

    final nextPageStart = _clientLoadedPages * kProjectsListPageSize;
    final nextChunk = _allProjects
        .skip(nextPageStart)
        .take(kProjectsListPageSize)
        .toList();
    if (nextChunk.isEmpty) return;

    visibleProjects = [...visibleProjects, ...nextChunk];
    _clientLoadedPages++;
    emit(ProjectListLoaded());
  }
}
