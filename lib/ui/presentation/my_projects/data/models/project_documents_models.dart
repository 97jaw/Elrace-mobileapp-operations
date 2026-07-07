import 'package:el_race/ui/presentation/my_projects/presentation/models/project_document_hub_kind.dart';

/// Portfolio DMS API models (v2).
class ProjectDocumentsDashboardData {
  const ProjectDocumentsDashboardData({
    required this.folders,
    required this.recentFiles,
    required this.totalProjectsInScope,
  });

  final List<ProjectDocumentsFolderSummary> folders;
  final List<ProjectDocumentFileItem> recentFiles;
  final int totalProjectsInScope;

  factory ProjectDocumentsDashboardData.fromJson(Map<String, dynamic> json) {
    final result = json['result'] as Map<String, dynamic>?;
    final data = result?['data'] ?? json['data'] ?? json;
    final map = Map<String, dynamic>.from(data as Map);
    final foldersJson = map['folders'] as List<dynamic>? ?? [];
    final recentJson = map['recent_files'] as List<dynamic>? ?? [];
    return ProjectDocumentsDashboardData(
      folders: foldersJson
          .map((e) => ProjectDocumentsFolderSummary.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList(),
      recentFiles: recentJson
          .map((e) => ProjectDocumentFileItem.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList(),
      totalProjectsInScope: map['total_projects_in_scope'] as int? ?? 0,
    );
  }
}

class ProjectDocumentsFolderSummary {
  const ProjectDocumentsFolderSummary({
    required this.kind,
    required this.fileCount,
    required this.projectCount,
    this.lastUpdated,
    this.updatedBy,
    this.previewFiles = const [],
  });

  final ProjectDocumentHubKind kind;
  final int fileCount;
  final int projectCount;
  final String? lastUpdated;
  final String? updatedBy;
  final List<ProjectDocumentPreviewFile> previewFiles;

  ProjectDocumentHubFolderItem toHubFolderItem() {
    return ProjectDocumentHubFolderItem(
      kind: kind,
      fileCount: fileCount,
      projectCount: projectCount,
      lastUpdatedLabel: formatDocumentDateLabel(lastUpdated),
      updatedBy: updatedBy ?? '—',
      previewFileNames: previewFiles.map((f) => f.name).toList(),
    );
  }

  factory ProjectDocumentsFolderSummary.fromJson(Map<String, dynamic> json) {
    return ProjectDocumentsFolderSummary(
      kind: hubKindFromApi(json['kind']?.toString()),
      fileCount: json['file_count'] as int? ?? 0,
      projectCount: json['project_count'] as int? ?? 0,
      lastUpdated: json['last_updated']?.toString(),
      updatedBy: json['updated_by']?.toString(),
      previewFiles: (json['preview_files'] as List<dynamic>? ?? [])
          .map((e) => ProjectDocumentPreviewFile.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList(),
    );
  }
}

class ProjectDocumentPreviewFile {
  const ProjectDocumentPreviewFile({
    required this.id,
    required this.name,
    this.projectId,
    this.url,
  });

  final String id;
  final String name;
  final int? projectId;
  final String? url;

  factory ProjectDocumentPreviewFile.fromJson(Map<String, dynamic> json) {
    return ProjectDocumentPreviewFile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      projectId: json['project_id'] as int?,
      url: json['url']?.toString(),
    );
  }
}

class ProjectDocumentFolderProject {
  const ProjectDocumentFolderProject({
    required this.projectId,
    required this.name,
    required this.woRefNo,
    required this.fileCount,
    this.lastUpdated,
    this.updatedBy,
    this.previewFiles = const [],
    this.hasCloud = false,
  });

  final int projectId;
  final String name;
  final String woRefNo;
  final int fileCount;
  final String? lastUpdated;
  final String? updatedBy;
  final List<ProjectDocumentPreviewFile> previewFiles;
  final bool hasCloud;

  factory ProjectDocumentFolderProject.fromJson(Map<String, dynamic> json) {
    return ProjectDocumentFolderProject(
      projectId: json['project_id'] as int? ?? 0,
      name: json['name']?.toString() ?? '',
      woRefNo: json['wo_ref_no']?.toString() ?? '',
      fileCount: json['file_count'] as int? ?? 0,
      lastUpdated: json['last_updated']?.toString(),
      updatedBy: json['updated_by']?.toString(),
      previewFiles: (json['preview_files'] as List<dynamic>? ?? [])
          .map((e) => ProjectDocumentPreviewFile.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList(),
      hasCloud: json['has_cloud'] as bool? ?? false,
    );
  }
}

class ProjectDocumentFileItem {
  const ProjectDocumentFileItem({
    required this.id,
    required this.name,
    required this.kind,
    required this.projectId,
    required this.projectName,
    required this.woRefNo,
    this.updatedAt,
    this.updatedBy,
    this.url = '',
    this.source = 'odoo',
  });

  final String id;
  final String name;
  final ProjectDocumentHubKind kind;
  final int projectId;
  final String projectName;
  final String woRefNo;
  final String? updatedAt;
  final String? updatedBy;
  final String url;
  final String source;

  bool get isCloud => kind == ProjectDocumentHubKind.cloud || source == 'sharepoint';

  factory ProjectDocumentFileItem.fromJson(Map<String, dynamic> json) {
    return ProjectDocumentFileItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      kind: hubKindFromApi(json['kind']?.toString()),
      projectId: json['project_id'] as int? ?? 0,
      projectName: json['project_name']?.toString() ?? '',
      woRefNo: json['wo_ref_no']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString(),
      updatedBy: json['updated_by']?.toString(),
      url: json['url']?.toString() ?? '',
      source: json['source']?.toString() ?? 'odoo',
    );
  }
}

class ProjectDocumentsPagedFiles {
  const ProjectDocumentsPagedFiles({
    required this.files,
    required this.total,
    required this.hasMore,
  });

  final List<ProjectDocumentFileItem> files;
  final int total;
  final bool hasMore;
}

class ProjectDocumentsUploaderItem {
  const ProjectDocumentsUploaderItem({
    required this.employeeId,
    required this.name,
    this.designation = '',
    this.photoUrl = '',
    this.totalUploads = 0,
    this.lastUploadedAt,
    this.projectCount = 0,
  });

  final int employeeId;
  final String name;
  final String designation;
  final String photoUrl;
  final int totalUploads;
  final String? lastUploadedAt;
  final int projectCount;

  factory ProjectDocumentsUploaderItem.fromJson(Map<String, dynamic> json) {
    return ProjectDocumentsUploaderItem(
      employeeId: json['employee_id'] as int? ?? 0,
      name: json['name']?.toString() ?? '',
      designation: json['designation']?.toString() ?? '',
      photoUrl: json['photo_url']?.toString() ?? '',
      totalUploads: json['total_uploads'] as int? ?? 0,
      lastUploadedAt: json['last_uploaded_at']?.toString(),
      projectCount: json['project_count'] as int? ?? 0,
    );
  }
}

class ProjectDocumentsPagedUploaders {
  const ProjectDocumentsPagedUploaders({
    required this.uploaders,
    required this.total,
    required this.hasMore,
  });

  final List<ProjectDocumentsUploaderItem> uploaders;
  final int total;
  final bool hasMore;
}

String formatDocumentDateLabel(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso;
  final months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
}

ProjectDocumentHubKind hubKindFromApi(String? value) {
  switch (value?.toLowerCase()) {
    case 'wo':
    case 'work_order':
      return ProjectDocumentHubKind.workOrder;
    case 'estimation':
    case 'est':
      return ProjectDocumentHubKind.estimation;
    case 'cloud':
      return ProjectDocumentHubKind.cloud;
    default:
      return ProjectDocumentHubKind.workOrder;
  }
}

String hubKindToApi(ProjectDocumentHubKind kind) => switch (kind) {
      ProjectDocumentHubKind.workOrder => 'wo',
      ProjectDocumentHubKind.estimation => 'estimation',
      ProjectDocumentHubKind.cloud => 'cloud',
    };
