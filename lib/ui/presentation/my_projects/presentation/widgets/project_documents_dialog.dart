import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_list_bloc.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/screens/project_documents_hub_screen.dart';
import 'package:flutter/material.dart';

/// Opens the project documents hub (WO / Estimation / Cloud).
abstract final class ProjectDocumentsDialog {
  static Future<void> show(
    BuildContext context, {
    required int projectId,
    required ProjectListBloc bloc,
    String? projectTitle,
  }) {
    return ProjectDocumentsHubScreen.open(
      context,
      projectId: projectId,
      projectTitle: projectTitle,
      fromPortfolioHub: false,
    );
  }
}
