import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_documents/project_documents_cubit.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/bloc/project_documents/project_documents_state.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/project_document_hub_kind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum ProjectDocumentsBreadcrumbType {
  home,
  kind,
  project,
  sharePointFolder,
  uploader,
}

class ProjectDocumentsBreadcrumb {
  const ProjectDocumentsBreadcrumb({
    required this.label,
    required this.type,
    this.kind,
    this.employeeId,
  });

  final String label;
  final ProjectDocumentsBreadcrumbType type;
  final ProjectDocumentHubKind? kind;
  final int? employeeId;

  static const home = ProjectDocumentsBreadcrumb(
    label: 'Project Documents',
    type: ProjectDocumentsBreadcrumbType.home,
  );

  factory ProjectDocumentsBreadcrumb.kind(ProjectDocumentHubKind kind) {
    return ProjectDocumentsBreadcrumb(
      label: kind.title,
      type: ProjectDocumentsBreadcrumbType.kind,
      kind: kind,
    );
  }

  factory ProjectDocumentsBreadcrumb.project(String name) {
    return ProjectDocumentsBreadcrumb(
      label: name,
      type: ProjectDocumentsBreadcrumbType.project,
    );
  }

  factory ProjectDocumentsBreadcrumb.sharePointFolder(String name) {
    return ProjectDocumentsBreadcrumb(
      label: name,
      type: ProjectDocumentsBreadcrumbType.sharePointFolder,
    );
  }

  factory ProjectDocumentsBreadcrumb.uploader(
    String name, {
    int? employeeId,
  }) {
    return ProjectDocumentsBreadcrumb(
      label: name,
      type: ProjectDocumentsBreadcrumbType.uploader,
      employeeId: employeeId,
    );
  }

  static bool isUploaderTrail(List<ProjectDocumentsBreadcrumb> trail) =>
      trail.length > 1 &&
      trail[1].type == ProjectDocumentsBreadcrumbType.uploader;

  /// Routes pushed on top of the documents shell.
  static int pushedDepthFor(List<ProjectDocumentsBreadcrumb> trail) {
    if (trail.length <= 1) return 0;
    if (isUploaderTrail(trail)) {
      return trail.length - 1;
    }
    if (trail.length <= 2) return 0;
    return trail.length - 2;
  }

  static int _popsToTarget(
    List<ProjectDocumentsBreadcrumb> trail,
    int targetIndex,
  ) {
    final depth = pushedDepthFor(trail);
    if (isUploaderTrail(trail)) {
      return depth - targetIndex;
    }
    if (targetIndex <= 1) return depth;
    return depth - (targetIndex - 1);
  }

  static void navigateTo(
    BuildContext context, {
    required List<ProjectDocumentsBreadcrumb> trail,
    required int targetIndex,
    ProjectDocumentsCubit? cubit,
  }) {
    if (targetIndex < 0 || targetIndex >= trail.length) return;
    if (targetIndex == trail.length - 1) return;
    if (!context.mounted) return;

    ProjectDocumentsCubit? docsCubit = cubit;
    if (docsCubit == null) {
      try {
        docsCubit = context.read<ProjectDocumentsCubit>();
      } catch (_) {}
    }

    final navigator = Navigator.of(context);
    final pops = _popsToTarget(trail, targetIndex);

    for (var i = 0; i < pops; i++) {
      if (!navigator.canPop()) break;
      navigator.pop();
    }

    if (docsCubit == null) return;

    final target = trail[targetIndex];
    if (targetIndex == 0) {
      if (isUploaderTrail(trail)) {
        docsCubit.switchView(ProjectDocumentsView.uploadedBy);
      } else {
        docsCubit.switchView(ProjectDocumentsView.dashboard);
      }
      return;
    }

    if (targetIndex == 1) {
      if (target.type == ProjectDocumentsBreadcrumbType.kind &&
          target.kind != null) {
        docsCubit.openFolderFromDashboard(target.kind!);
      } else if (target.type == ProjectDocumentsBreadcrumbType.uploader) {
        docsCubit.switchView(ProjectDocumentsView.uploadedBy);
      }
    }
  }
}

List<ProjectDocumentsBreadcrumb> projectDocumentsTrailForShell(
  ProjectDocumentsState state,
) {
  return switch (state.activeView) {
    ProjectDocumentsView.dashboard => const [ProjectDocumentsBreadcrumb.home],
    ProjectDocumentsView.folderProjects => [
        ProjectDocumentsBreadcrumb.home,
        ProjectDocumentsBreadcrumb.kind(state.selectedKind),
      ],
    ProjectDocumentsView.files => const [ProjectDocumentsBreadcrumb.home],
    ProjectDocumentsView.uploadedBy => const [
        ProjectDocumentsBreadcrumb.home,
        ProjectDocumentsBreadcrumb(
          label: 'Uploaded by',
          type: ProjectDocumentsBreadcrumbType.uploader,
        ),
      ],
  };
}

List<ProjectDocumentsBreadcrumb> projectDocumentsTrailForProject({
  required ProjectDocumentHubKind kind,
  required String projectName,
  List<ProjectDocumentsBreadcrumb> parentFolders = const [],
}) {
  return [
    ProjectDocumentsBreadcrumb.home,
    ProjectDocumentsBreadcrumb.kind(kind),
    ProjectDocumentsBreadcrumb.project(projectName),
    ...parentFolders,
  ];
}

List<ProjectDocumentsBreadcrumb> projectDocumentsTrailForUploader(
  String uploaderName, {
  int? employeeId,
}) {
  return [
    ProjectDocumentsBreadcrumb.home,
    ProjectDocumentsBreadcrumb.uploader(uploaderName, employeeId: employeeId),
  ];
}

List<ProjectDocumentsBreadcrumb> projectDocumentsTrailForUploaderProject({
  required String uploaderName,
  required String projectName,
  int? employeeId,
}) {
  return [
    ProjectDocumentsBreadcrumb.home,
    ProjectDocumentsBreadcrumb.uploader(uploaderName, employeeId: employeeId),
    ProjectDocumentsBreadcrumb.project(projectName),
  ];
}
