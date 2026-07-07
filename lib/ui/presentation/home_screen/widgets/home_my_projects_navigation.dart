import 'package:el_race/ui/presentation/my_projects/data/datasources/project_remote_datasource.dart';
import 'package:el_race/ui/presentation/my_projects/data/repositories/project_repository_impl.dart';
import 'package:el_race/ui/presentation/my_projects/domain/entities/project_entity.dart';
import 'package:el_race/ui/presentation/my_projects/domain/usecases/get_projects_by_filters_usecase.dart';
import 'package:el_race/ui/presentation/my_projects/domain/usecases/get_projects_by_partner_usecase.dart';
import 'package:el_race/ui/presentation/my_projects/domain/usecases/get_projects_usecase.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_list_bloc.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/map/project_analytics_screen.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/projects_list_context.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/screens/my_project.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/screens/project_list_screen.dart';
import 'package:el_race/utils/Util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the existing My Projects module for a widget row tap.
abstract final class HomeMyProjectsNavigation {
  static ProjectListBloc _buildBloc() {
    final repo = ProjectRepositoryImpl(ProjectRemoteDataSource());
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

  static Future<ProjectEntity?> _resolveProject(int projectId) async {
    final repo = ProjectRepositoryImpl(ProjectRemoteDataSource());
    final projects = await repo.getProjects();
    for (final project in projects) {
      if (project.projectId == projectId) return project;
    }
    return null;
  }

  static Future<void> openProject(BuildContext context, int projectId) async {
    final project = await _resolveProject(projectId);
    if (!context.mounted) return;

    if (project == null) {
      Util.pushPage(const MyProject(), context);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProjectAnalyticsScreen(project: project),
      ),
    );
  }

  static void openProjectsModule(BuildContext context) {
    Util.pushPage(const MyProject(), context);
  }

  static Future<void> openProjectList(BuildContext context, int projectId) async {
    final project = await _resolveProject(projectId);
    if (!context.mounted) return;

    if (project == null) {
      openProjectsModule(context);
      return;
    }

    final bloc = _buildBloc();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: ProjectListScreen(
            bloc: bloc,
            preloadedProjects: [project],
            partnerName: project.name,
            listContext: ProjectsListContext.general,
          ),
        ),
      ),
    );
  }
}
