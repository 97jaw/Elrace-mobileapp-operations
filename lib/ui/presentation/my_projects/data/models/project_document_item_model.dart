/// Model for project document items (folders and files) from the cloud API
class ProjectDocumentItem {
  final String id;
  final String name;
  final String type; // 'folder' or 'file'
  final String? downloadUrl;
  final String? driveId;

  const ProjectDocumentItem({
    required this.id,
    required this.name,
    required this.type,
    this.downloadUrl,
    this.driveId,
  });

  bool get isFolder => type == 'folder';
  bool get isFile => type == 'file';

  /// Get file extension from name
  String get fileExtension {
    if (!isFile) return '';
    final parts = name.split('.');
    if (parts.length > 1) {
      return parts.last.toLowerCase();
    }
    return '';
  }

  /// Check if file is PDF
  bool get isPdf => fileExtension == 'pdf';

  /// Check if file is Excel
  bool get isExcel =>
      fileExtension == 'xlsx' ||
      fileExtension == 'xls' ||
      fileExtension == 'csv';

  /// Check if file is Word document
  bool get isWord => fileExtension == 'doc' || fileExtension == 'docx';

  /// Check if file is image
  bool get isImage =>
      fileExtension == 'jpg' ||
      fileExtension == 'jpeg' ||
      fileExtension == 'png' ||
      fileExtension == 'gif' ||
      fileExtension == 'webp';

  factory ProjectDocumentItem.fromJson(Map<String, dynamic> json) {
    return ProjectDocumentItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? 'file',
      downloadUrl: json['download_url']?.toString(),
      driveId: json['drive_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'download_url': downloadUrl,
        'drive_id': driveId,
      };

  @override
  String toString() =>
      'ProjectDocumentItem(id: $id, name: $name, type: $type, driveId: $driveId)';
}

Map<String, dynamic> _resultData(Map<String, dynamic> json) {
  final result = json['result'] as Map<String, dynamic>? ?? json;
  if (result['data'] is Map) {
    return Map<String, dynamic>.from(result['data'] as Map);
  }
  return result;
}

String _resultStatus(Map<String, dynamic> json) {
  final result = json['result'] as Map<String, dynamic>? ?? json;
  return result['status']?.toString() ?? 'error';
}

String? _resultMessage(Map<String, dynamic> json) {
  final result = json['result'] as Map<String, dynamic>? ?? json;
  return result['message']?.toString();
}

/// Response model for project documents API
class ProjectDocumentsResponse {
  final String status;
  final int projectId;
  final String? driveId;
  final List<ProjectDocumentItem> items;
  final String? nextLink;
  final String? message;

  const ProjectDocumentsResponse({
    required this.status,
    required this.projectId,
    required this.items,
    this.driveId,
    this.nextLink,
    this.message,
  });

  bool get isSuccess => status == 'success';

  factory ProjectDocumentsResponse.fromJson(Map<String, dynamic> json) {
    final data = _resultData(json);
    final itemsList = data['items'] as List<dynamic>? ?? [];

    return ProjectDocumentsResponse(
      status: _resultStatus(json),
      message: _resultMessage(json),
      projectId: data['project_id'] as int? ?? 0,
      driveId: data['drive_id']?.toString(),
      items: itemsList
          .map((e) => ProjectDocumentItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextLink: data['next_link']?.toString(),
    );
  }
}

/// Response model for folder contents API
class FolderContentsResponse {
  final String status;
  final int projectId;
  final String folderId;
  final String? driveId;
  final List<ProjectDocumentItem> items;
  final String? nextLink;
  final String? message;

  const FolderContentsResponse({
    required this.status,
    required this.projectId,
    required this.folderId,
    required this.items,
    this.driveId,
    this.nextLink,
    this.message,
  });

  bool get isSuccess => status == 'success';

  factory FolderContentsResponse.fromJson(Map<String, dynamic> json) {
    final data = _resultData(json);
    final itemsList = data['items'] as List<dynamic>? ?? [];

    return FolderContentsResponse(
      status: _resultStatus(json),
      message: _resultMessage(json),
      projectId: data['project_id'] as int? ?? 0,
      folderId: data['folder_id']?.toString() ?? '',
      driveId: data['drive_id']?.toString(),
      items: itemsList
          .map((e) => ProjectDocumentItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextLink: data['next_link']?.toString(),
    );
  }
}

/// Response model for file details API
class FileDetailsResponse {
  final String status;
  final int projectId;
  final String fileId;
  final String? driveId;
  final String name;
  final String viewUrl;
  final String downloadUrl;
  final String? message;

  const FileDetailsResponse({
    required this.status,
    required this.projectId,
    required this.fileId,
    required this.name,
    required this.viewUrl,
    required this.downloadUrl,
    this.driveId,
    this.message,
  });

  bool get isSuccess => status == 'success';

  factory FileDetailsResponse.fromJson(Map<String, dynamic> json) {
    final data = _resultData(json);

    return FileDetailsResponse(
      status: _resultStatus(json),
      message: _resultMessage(json),
      projectId: data['project_id'] as int? ?? 0,
      fileId: data['file_id']?.toString() ?? '',
      driveId: data['drive_id']?.toString(),
      name: data['name']?.toString() ?? '',
      viewUrl: data['view_url']?.toString() ?? '',
      downloadUrl: data['download_url']?.toString() ?? '',
    );
  }
}
