import 'package:el_race/ui/presentation/my_projects/presentation/models/project_document_hub_kind.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/screens/project_documents/project_documents_shell.dart';
import 'package:flutter/material.dart';

/// Entry wrapper for the portfolio / per-project documents DMS.
class ProjectDocumentsHubScreen extends StatelessWidget {
  const ProjectDocumentsHubScreen({
    super.key,
    this.projectId,
    this.projectTitle,
    this.fromPortfolioHub = false,
  });

  final int? projectId;
  final String? projectTitle;
  final bool fromPortfolioHub;

  static Future<void> open(
    BuildContext context, {
    int? projectId,
    String? projectTitle,
    bool fromPortfolioHub = false,
  }) {
    return ProjectDocumentsShell.open(
      context,
      initialProjectId: projectId,
      initialProjectTitle: projectTitle,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProjectDocumentsShell(
      initialProjectId: projectId,
      initialProjectTitle: projectTitle,
      initialKind: fromPortfolioHub ? null : ProjectDocumentHubKind.workOrder,
    );
  }
}
