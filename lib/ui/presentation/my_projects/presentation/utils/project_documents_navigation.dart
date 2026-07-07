import 'package:el_race/ui/presentation/my_projects/data/models/project_documents_models.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_documents/project_documents_cubit.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/project_document_hub_kind.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/project_documents_breadcrumb.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/screens/cloud_documents_screen.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/screens/project_documents/project_documents_project_files_screen.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/screens/project_documents/project_documents_uploader_project_files_screen.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/screens/project_documents/project_documents_uploader_projects_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Pushes drill-down screens with [ProjectDocumentsCubit] so breadcrumb jumps work.
void pushProjectDocumentsProjectFiles(
  BuildContext context, {
  required int projectId,
  required String projectName,
  required ProjectDocumentHubKind kind,
  List<ProjectDocumentsBreadcrumb>? breadcrumbs,
}) {
  final cubit = context.read<ProjectDocumentsCubit>();
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: ProjectDocumentsProjectFilesScreen(
          projectId: projectId,
          projectName: projectName,
          kind: kind,
          breadcrumbs: breadcrumbs,
        ),
      ),
    ),
  );
}

void pushCloudDocumentsFolder(
  BuildContext context, {
  required int projectId,
  required String folderId,
  required String folderName,
  String? folderType,
  required List<ProjectDocumentsBreadcrumb> breadcrumbs,
}) {
  final cubit = context.read<ProjectDocumentsCubit>();
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: CloudDocumentsScreen(
          projectId: projectId,
          folderId: folderId,
          folderName: folderName,
          folderType: folderType,
          breadcrumbs: breadcrumbs,
        ),
      ),
    ),
  );
}

void pushUploaderProjects(
  BuildContext context, {
  required ProjectDocumentsUploaderItem uploader,
  List<ProjectDocumentsBreadcrumb>? breadcrumbs,
}) {
  final cubit = context.read<ProjectDocumentsCubit>();
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: ProjectDocumentsUploaderProjectsScreen(
          uploader: uploader,
          breadcrumbs: breadcrumbs ??
              projectDocumentsTrailForUploader(
                uploader.name,
                employeeId: uploader.employeeId,
              ),
        ),
      ),
    ),
  );
}

void pushUploaderProjectFiles(
  BuildContext context, {
  required ProjectDocumentsUploaderItem uploader,
  required int projectId,
  required String projectName,
  List<ProjectDocumentsBreadcrumb>? breadcrumbs,
}) {
  final cubit = context.read<ProjectDocumentsCubit>();
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: ProjectDocumentsUploaderProjectFilesScreen(
          uploader: uploader,
          projectId: projectId,
          projectName: projectName,
          breadcrumbs: breadcrumbs,
        ),
      ),
    ),
  );
}
