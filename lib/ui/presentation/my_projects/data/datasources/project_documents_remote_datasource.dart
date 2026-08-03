import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_documents_models.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/project_document_hub_kind.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/projects_group_hub_filters.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_api_coordinator.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_list_ordering.dart';
import 'package:el_race/utils/urll_utils.dart';
import 'package:http/http.dart' as http;

class ProjectDocumentsRemoteDataSource {
  ProjectDocumentsRemoteDataSource({
    http.Client? client,
    String Function()? getToken,
  })  : _client = client ?? http.Client(),
        _getToken = getToken ?? _defaultGetToken;

  static const Duration _timeout = Duration(seconds: 60);

  final http.Client _client;
  final String Function() _getToken;

  static String _defaultGetToken() =>
      SharedPref.getLoginData().result?.token ?? '';

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer ${_getToken()}',
      };

  Future<http.Response> _get(String path, Map<String, dynamic> params) {
    final url = Uri.parse('${UrlUtil.baseUrl}$path');
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'params': params,
    });
    return ProjectsApiCoordinator.instance.run(() async {
      final request = http.Request('GET', url)
        ..headers.addAll(_headers)
        ..body = body;
      final streamed = await _client.send(request).timeout(_timeout);
      return http.Response.fromStream(streamed);
    });
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode == 404) {
      throw ProjectDocumentsApiException(
        'Documents API not deployed. Deploy elrace_backend_apis v2 document routes.',
        notFound: true,
      );
    }
    if (response.statusCode != 200) {
      throw ProjectDocumentsApiException(
        'Request failed (${response.statusCode})',
      );
    }
    final decoded = json.decode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw ProjectDocumentsApiException('Invalid response');
    }
    final result = decoded['result'];
    if (result is Map<String, dynamic> && result['status'] == 'error') {
      throw ProjectDocumentsApiException(
        result['message']?.toString() ?? 'API error',
      );
    }
    return decoded;
  }

  Map<String, dynamic> _withFilters(
    ProjectsGroupHubFilters filters, {
    Map<String, dynamic>? extra,
  }) {
    return {
      ...filters.toApiParams(),
      if (extra != null) ...extra,
    };
  }

  Future<ProjectDocumentsDashboardData> fetchDashboard(
    ProjectsGroupHubFilters filters,
  ) async {
    final response = await _get(
      'v2/documents/dashboard',
      _withFilters(filters),
    );
    return ProjectDocumentsDashboardData.fromJson(_decode(response));
  }

  Future<({List<ProjectDocumentFolderProject> projects, int total, bool hasMore})>
      fetchFolderProjects({
    required ProjectDocumentHubKind kind,
    required ProjectsGroupHubFilters filters,
    String? keyword,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _get(
      'v2/documents/folder_projects',
      _withFilters(
        filters,
        extra: {
          'kind': hubKindToApi(kind),
          if (keyword != null && keyword.trim().isNotEmpty)
            'keyword': keyword.trim(),
          'limit': limit,
          'offset': offset,
          'order': ProjectsListOrdering.apiOrder,
          'sort': 'desc',
        },
      ),
    );
    final decoded = _decode(response);
    final result = decoded['result'] as Map<String, dynamic>?;
    final data = result?['data'] ?? decoded['data'];
    final map = Map<String, dynamic>.from(data as Map);
    final list = ProjectsListOrdering.sortDocumentProjectsDesc(
      (map['projects'] as List<dynamic>? ?? []).map(
        (e) => ProjectDocumentFolderProject.fromJson(
          Map<String, dynamic>.from(e as Map),
        ),
      ),
    );
    final pagination = result?['pagination'] as Map<String, dynamic>?;
    final total = pagination?['total'] as int? ?? map['total'] as int? ?? list.length;
    final hasMore = pagination?['has_more'] as bool? ??
        (list.length >= limit && offset + list.length < total);
    return (projects: list, total: total, hasMore: hasMore);
  }

  Future<ProjectDocumentsPagedFiles> fetchFiles({
    required ProjectsGroupHubFilters filters,
    ProjectDocumentHubKind? kind,
    int? projectId,
    String? fileName,
    int? uploaderId,
    int limit = 30,
    int offset = 0,
  }) async {
    final response = await _get(
      'v2/documents/files',
      _withFilters(
        filters,
        extra: {
          if (kind != null) 'kind': hubKindToApi(kind),
          if (projectId != null) 'project_id': projectId,
          if (fileName != null && fileName.trim().isNotEmpty)
            'file_name': fileName.trim(),
          if (uploaderId != null) 'uploader_id': uploaderId,
          'limit': limit,
          'offset': offset,
        },
      ),
    );
    final decoded = _decode(response);
    final result = decoded['result'] as Map<String, dynamic>?;
    final data = result?['data'] ?? decoded['data'];
    final map = Map<String, dynamic>.from(data as Map);
    final files = (map['files'] as List<dynamic>? ?? [])
        .map((e) => ProjectDocumentFileItem.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
    final pagination = result?['pagination'] as Map<String, dynamic>?;
    final total = pagination?['total'] as int? ?? map['total'] as int? ?? files.length;
    final hasMore = pagination?['has_more'] as bool? ??
        (files.length >= limit && offset + files.length < total);
    return ProjectDocumentsPagedFiles(
      files: files,
      total: total,
      hasMore: hasMore,
    );
  }

  Future<ProjectDocumentsPagedFiles> fetchProjectFiles({
    required int projectId,
    required ProjectDocumentHubKind kind,
    ProjectsGroupHubFilters filters = const ProjectsGroupHubFilters(),
    String? fileName,
    int? uploaderId,
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _get(
      'v2/documents/project_files',
      _withFilters(
        filters,
        extra: {
          'project_id': projectId,
          'kind': hubKindToApi(kind),
          if (fileName != null && fileName.trim().isNotEmpty)
            'file_name': fileName.trim(),
          if (uploaderId != null) 'uploader_id': uploaderId,
          'limit': limit,
          'offset': offset,
        },
      ),
    );
    final decoded = _decode(response);
    final data = decoded['result']?['data'] ?? decoded['data'];
    final map = Map<String, dynamic>.from(data as Map);
    if (map['cloud'] == true) {
      return const ProjectDocumentsPagedFiles(files: [], total: 0, hasMore: false);
    }
    final files = (map['files'] as List<dynamic>? ?? [])
        .map((e) => ProjectDocumentFileItem.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
    final total = map['total'] as int? ?? files.length;
    return ProjectDocumentsPagedFiles(
      files: files,
      total: total,
      hasMore: offset + files.length < total,
    );
  }

  Future<ProjectDocumentsPagedUploaders> fetchUploaders({
    required ProjectsGroupHubFilters filters,
    String? keyword,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _get(
      'v2/documents/uploaders',
      _withFilters(
        filters,
        extra: {
          if (keyword != null && keyword.trim().isNotEmpty)
            'keyword': keyword.trim(),
          'limit': limit,
          'offset': offset,
        },
      ),
    );
    final decoded = _decode(response);
    final result = decoded['result'] as Map<String, dynamic>?;
    final data = result?['data'] ?? decoded['data'];
    final map = Map<String, dynamic>.from(data as Map);
    final list = (map['uploaders'] as List<dynamic>? ?? [])
        .map((e) => ProjectDocumentsUploaderItem.fromJson(
              Map<String, dynamic>.from(e as Map),
            ))
        .toList();
    final pagination = result?['pagination'] as Map<String, dynamic>?;
    final total = pagination?['total'] as int? ?? map['total'] as int? ?? list.length;
    final hasMore = pagination?['has_more'] as bool? ??
        (list.length >= limit && offset + list.length < total);
    return ProjectDocumentsPagedUploaders(
      uploaders: list,
      total: total,
      hasMore: hasMore,
    );
  }

  Future<({List<ProjectDocumentFolderProject> projects, int total, bool hasMore})>
      fetchUploaderProjects({
    required int employeeId,
    required ProjectsGroupHubFilters filters,
    String? keyword,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _get(
      'v2/documents/uploader_projects',
      _withFilters(
        filters,
        extra: {
          'employee_id': employeeId,
          if (keyword != null && keyword.trim().isNotEmpty)
            'keyword': keyword.trim(),
          'limit': limit,
          'offset': offset,
          'order': ProjectsListOrdering.apiOrder,
          'sort': 'desc',
        },
      ),
    );
    final decoded = _decode(response);
    final result = decoded['result'] as Map<String, dynamic>?;
    final data = result?['data'] ?? decoded['data'];
    final map = Map<String, dynamic>.from(data as Map);
    final list = ProjectsListOrdering.sortDocumentProjectsDesc(
      (map['projects'] as List<dynamic>? ?? []).map(
        (e) => ProjectDocumentFolderProject.fromJson(
          Map<String, dynamic>.from(e as Map),
        ),
      ),
    );
    final pagination = result?['pagination'] as Map<String, dynamic>?;
    final total = pagination?['total'] as int? ?? map['total'] as int? ?? list.length;
    final hasMore = pagination?['has_more'] as bool? ??
        (list.length >= limit && offset + list.length < total);
    return (projects: list, total: total, hasMore: hasMore);
  }
}

class ProjectDocumentsApiException implements Exception {
  ProjectDocumentsApiException(this.message, {this.notFound = false});
  final String message;
  final bool notFound;

  @override
  String toString() => message;
}
