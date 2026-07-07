/// Top-level project document buckets on the documents hub.
enum ProjectDocumentHubKind {
  workOrder,
  estimation,
  cloud,
}

extension ProjectDocumentHubKindX on ProjectDocumentHubKind {
  String get title => switch (this) {
        ProjectDocumentHubKind.workOrder => 'Workorders',
        ProjectDocumentHubKind.estimation => 'Estimation',
        ProjectDocumentHubKind.cloud => 'SharePoint',
      };

  String? get assetPath => switch (this) {
        ProjectDocumentHubKind.workOrder =>
          'assets/png/project_docs/wo_icon.png',
        ProjectDocumentHubKind.cloud =>
          'assets/png/project_docs/sharepoint_icon.png',
        ProjectDocumentHubKind.estimation =>
          'assets/png/project_docs/estimation_icon.png',
      };

  /// API folder_type for Odoo attachments (cloud uses SharePoint API).
  String? get attachmentFolderType => switch (this) {
        ProjectDocumentHubKind.workOrder => 'wo',
        ProjectDocumentHubKind.estimation => 'estimation',
        ProjectDocumentHubKind.cloud => null,
      };
}

/// Row for a top-level folder on the documents hub.
class ProjectDocumentHubFolderItem {
  const ProjectDocumentHubFolderItem({
    required this.kind,
    required this.fileCount,
    required this.projectCount,
    required this.lastUpdatedLabel,
    required this.updatedBy,
    this.previewFileNames = const [],
  });

  final ProjectDocumentHubKind kind;
  final int fileCount;
  final int projectCount;
  final String lastUpdatedLabel;
  final String updatedBy;
  final List<String> previewFileNames;

  static List<ProjectDocumentHubFolderItem> dummySet() => const [
        ProjectDocumentHubFolderItem(
          kind: ProjectDocumentHubKind.workOrder,
          fileCount: 14,
          projectCount: 6,
          lastUpdatedLabel: '12 Mar 2026',
          updatedBy: 'Sara Khan',
        ),
        ProjectDocumentHubFolderItem(
          kind: ProjectDocumentHubKind.estimation,
          fileCount: 8,
          projectCount: 4,
          lastUpdatedLabel: '08 Mar 2026',
          updatedBy: 'Omar Hassan',
        ),
        ProjectDocumentHubFolderItem(
          kind: ProjectDocumentHubKind.cloud,
          fileCount: 24,
          projectCount: 9,
          lastUpdatedLabel: 'Today',
          updatedBy: 'SharePoint',
        ),
      ];
}
