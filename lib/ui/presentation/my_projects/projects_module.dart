import 'package:el_race/ui/presentation/my_projects/data/datasources/project_remote_datasource.dart';
import 'package:el_race/ui/presentation/my_projects/data/repositories/project_repository_impl.dart';
import 'package:el_race/ui/presentation/my_projects/domain/repositories/project_repository.dart';
import 'package:el_race/ui/presentation/my_projects/domain/usecases/get_projects_by_filters_usecase.dart';
import 'package:el_race/ui/presentation/my_projects/domain/usecases/get_projects_by_partner_usecase.dart';
import 'package:el_race/ui/presentation/my_projects/domain/usecases/get_projects_usecase.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_list_bloc.dart';
import 'package:el_race/utils/di.dart';

/// Shared Projects DI accessors — one [ProjectRemoteDataSource] per app session
/// so v2 hub probe state is not reset on every screen open.
abstract final class ProjectsModule {
  static ProjectRemoteDataSource get remote {
    if (!sl.isRegistered<ProjectRemoteDataSource>()) {
      sl.registerLazySingleton<ProjectRemoteDataSource>(
        ProjectRemoteDataSource.new,
      );
    }
    return sl<ProjectRemoteDataSource>();
  }

  static ProjectRepository get repository {
    if (!sl.isRegistered<ProjectRepository>()) {
      sl.registerLazySingleton<ProjectRepository>(
        () => ProjectRepositoryImpl(remote),
      );
    }
    return sl<ProjectRepository>();
  }

  /// Fresh bloc per screen (factory when DI wired; otherwise constructed here).
  static ProjectListBloc createListBloc() {
    if (sl.isRegistered<ProjectListBloc>()) {
      return sl<ProjectListBloc>();
    }
    final repo = repository;
    return ProjectListBloc(
      getProjectsUseCase: GetProjectsUseCase(repository: repo),
      getProjectAttachmentsUseCase:
          GetProjectAttachmentsUseCase(repository: repo),
      getProjectsByPartnerUseCase:
          GetProjectsByPartnerUseCase(repository: repo),
      getProjectsByFiltersUseCase:
          GetProjectsByFiltersUseCase(repository: repo),
    );
  }
}
