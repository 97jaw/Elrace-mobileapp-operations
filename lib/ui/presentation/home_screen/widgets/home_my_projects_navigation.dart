import 'package:el_race/ui/presentation/my_projects/presentation/map/project_analytics_screen.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/projects_list_context.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/screens/my_project.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/screens/project_list_screen.dart';
import 'package:el_race/ui/presentation/my_projects/domain/entities/project_entity.dart';
import 'package:el_race/ui/presentation/my_projects/projects_module.dart';
import 'package:el_race/utils/Util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the existing My Projects module for a widget row tap.
abstract final class HomeMyProjectsNavigation {
  /// Blocks accidental double-taps during the push animation only.
  static bool _opening = false;
  static const Duration _tapGuard = Duration(milliseconds: 800);

  static Future<void> _runGuarded(Future<void> Function() action) async {
    if (_opening) return;
    _opening = true;
    try {
      await action();
    } finally {
      // Hold the lock through the route transition, then allow the next open.
      await Future<void>.delayed(_tapGuard);
      _opening = false;
    }
  }

  static Future<void> openProject(
    BuildContext context, {
    required int projectId,
    String name = '',
    double? totalProgress,
  }) {
    return _runGuarded(() async {
      final project = ProjectEntity.stub(
        projectId: projectId,
        name: name,
        totalProgress: totalProgress,
      );
      if (!context.mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProjectAnalyticsScreen(project: project),
        ),
      );
    });
  }

  static Future<void> openProjectsModule(BuildContext context) {
    return _runGuarded(() async {
      Util.pushPage(const MyProject(), context);
    });
  }

  static Future<void> openProjectList(
    BuildContext context, {
    required int projectId,
    String name = '',
  }) {
    return _runGuarded(() async {
      final project = ProjectEntity.stub(
        projectId: projectId,
        name: name,
      );
      if (!context.mounted) return;

      final bloc = ProjectsModule.createListBloc();
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
    });
  }
}
