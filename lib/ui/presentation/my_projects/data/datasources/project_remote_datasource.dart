import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/attachment_model.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/partner_model.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_expense_breakdown_model.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_expense_dashboard_model.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_expense_summary_model.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_financial_model.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_model.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/projects_paged_result.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/odoo_field_parsers.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_api_coordinator.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_list_ordering.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_list_pagination.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_scurve_model.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_manager_filter_item.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/user_project_model.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/user_projects_response.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/folder_model.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_document_item_model.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/projects_group_hub_filters.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_group_hub_filter_applier.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_group_list_builder.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/projects_dashboard_summary_model.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:el_race/utils/urll_utils.dart';

abstract class ProjectRemoteDataSourceImpl {
  Future<ProjectsPagedResult> fetchProjectsPage({
    int limit = kProjectsBulkFetchPageSize,
    int offset = 0,
    String? keyword,
    int? year,
    int? month,
    String? projectStatusCompute,
    String? woRefNo,
    String? woTypeNoOffice,
    String? nameSearch,
    bool portfolio = false,
  });

  /// Loads up to [maxItems] in-progress projects (paginated on the server).
  Future<List<ProjectModel>> fetchProjects({int maxItems = kProjectsDashboardMaxProjects});

  /// Portfolio-scoped in-progress projects for dashboard client bars.
  Future<List<ProjectModel>> fetchDashboardChartProjects({
    int maxItems = kProjectsDashboardMaxProjects,
    String? projectStatusCompute = 'in_progress',
  });
  Future<List<AttachmentModel>> fetchProjectAttachments(String projectId,
      {String? folderType});
  Future<List<PartnerModel>> fetchPartnerProjects(
      {int? partnerId, String? keyword});
  Future<List<ProjectModel>> fetchProjectsByPartnerId(int partnerId);
  Future<ProjectsPagedResult> fetchProjectsByFilters({
    int? agreementId,
    int? partnerId,
    int? projectManagerId,
    int? cityId,
    String? keyword,
    ProjectsGroupHubFilters? hubFilters,
    int limit = kProjectsListPageSize,
    int offset = 0,
  });
  Future<List<FolderModel>> fetchProjectFolders();
  Future<UserProjectsResponse> fetchClientsList();
  Future<ProjectsDashboardSummaryModel> fetchProjectsDashboardSummary();
  Future<List<ProjectManagerFilterItem>> fetchProjectManagersList({
    ProjectsGroupHubFilters? filters,
  });
  Future<List<ProjectManagerFilterItem>> fetchClientsGroupedList({
    required String groupBy,
    ProjectsGroupHubFilters? filters,
  });
  Future<ProjectDocumentsResponse> fetchProjectDocuments(int projectId,
      {String? folderType});
  Future<FolderContentsResponse> fetchFolderContents(
      int projectId, String folderId);
  Future<FileDetailsResponse> fetchFileDetails(int projectId, String fileId);
  Future<ProjectScurveData> fetchProjectScurve(
    int projectId, {
    int rangeStart = 1,
    int rangeSize = 50,
  });
  Future<ProjectExpenseDashboardModel> fetchProjectExpenseDashboard(int projectId);
  Future<ProjectFinancialModel> fetchProjectFinancialData(
    int projectId, {
    String? dateFrom,
    String? dateTo,
  });
  Future<ProjectExpenseSummaryModel> fetchProjectExpenseSummary(int projectId);
  Future<ProjectExpenseBreakdownResult> fetchProjectExpenseBreakdown(
    int projectId,
  );
}

class ProjectRemoteDataSource implements ProjectRemoteDataSourceImpl {
  ProjectRemoteDataSource({
    http.Client? client,
    String Function()? getToken,
  })  : _client = client ?? http.Client(),
        _getToken = getToken ?? _defaultGetToken;

  static const String _v2ClientsList = 'v2/clients/list';
  static const String _v2GetProjects = 'v2/get_projects';
  static const String _v2PartnerProjects = 'v2/get_partner_projects';

  /// `null` = not probed yet; `true`/`false` after first v2 hub call.
  bool? _projectsHubV2Available;

  /// Whether the last successful hub call used v2 (false when on v1 fallback).
  bool get projectsHubV2Available => _projectsHubV2Available == true;

  static bool _isNotFoundResponse(http.Response response) {
    if (response.statusCode == 404) return true;
    try {
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map && error['code'] == 404) return true;
      }
    } catch (_) {}
    return false;
  }

  void _markProjectsHubV2Unavailable() {
    if (_projectsHubV2Available != false) {
      debugPrint(
        'Projects hub v2 API not found on server — using v1 fallback '
        '(deploy elrace_backend_apis v2 routes to enable filters).',
      );
    }
    _projectsHubV2Available = false;
  }

  void _markProjectsHubV2Available() {
    _projectsHubV2Available = true;
  }

  Future<http.Response> _jsonGetTryV2({
    required Uri v2Url,
    required Uri v1Url,
    required Map<String, String> headers,
    required String body,
  }) async {
    if (_projectsHubV2Available == false) {
      return _jsonGetWithBody(v1Url, headers, body);
    }
    var response = await _jsonGetWithBody(v2Url, headers, body);
    if (_isNotFoundResponse(response)) {
      _markProjectsHubV2Unavailable();
      response = await _jsonGetWithBody(v1Url, headers, body);
    } else if (response.statusCode == 200) {
      _markProjectsHubV2Available();
    }
    return response;
  }

  Future<http.Response> _jsonPostTryV2({
    required Uri v2Url,
    required Uri v1Url,
    required Map<String, String> headers,
    required String body,
  }) async {
    if (_projectsHubV2Available == false) {
      return _runQueued(
        () => _client.post(v1Url, headers: headers, body: body).timeout(_apiTimeout),
      );
    }
    var response = await _runQueued(
      () => _client.post(v2Url, headers: headers, body: body).timeout(_apiTimeout),
    );
    if (_isNotFoundResponse(response)) {
      _markProjectsHubV2Unavailable();
      response = await _runQueued(
        () => _client.post(v1Url, headers: headers, body: body).timeout(_apiTimeout),
      );
    } else if (response.statusCode == 200) {
      _markProjectsHubV2Available();
    }
    return response;
  }

  static const Duration _apiTimeout = Duration(seconds: 90);

  final http.Client _client;
  final String Function() _getToken;

  Future<T> _runQueued<T>(Future<T> Function() action) =>
      ProjectsApiCoordinator.instance.run(action);

  static String _defaultGetToken() {
    return SharedPref.getLoginData().result?.token ?? '';
  }

  /// Odoo JSON routes on live ERP expect GET with a JSON body (POST returns 405).
  Future<http.Response> _jsonGetWithBody(
    Uri url,
    Map<String, String> headers,
    String body,
  ) {
    return _runQueued(() async {
      final request = http.Request('GET', url)
        ..headers.addAll(headers)
        ..body = body;
      final streamedResponse =
          await _client.send(request).timeout(_apiTimeout);
      return http.Response.fromStream(streamedResponse);
    });
  }

  /// Loads in-progress portfolio projects for the dashboard client bars.
  /// Uses v2 portfolio domain (management = full portfolio; staff = scoped).
  @override
  Future<List<ProjectModel>> fetchDashboardChartProjects({
    int maxItems = kProjectsDashboardMaxProjects,
    String? projectStatusCompute = 'in_progress',
  }) async {
    final accumulated = <ProjectModel>[];
    var offset = 0;

    while (accumulated.length < maxItems) {
      final remaining = maxItems - accumulated.length;
      final pageSize = remaining < kProjectsBulkFetchPageSize
          ? remaining
          : kProjectsBulkFetchPageSize;

      final page = await fetchProjectsPage(
        limit: pageSize,
        offset: offset,
        portfolio: true,
        projectStatusCompute: projectStatusCompute,
      );

      if (page.projects.isEmpty) break;
      accumulated.addAll(page.projects);
      offset += page.projects.length;
      if (!page.hasMore) break;
    }

    return ProjectsListOrdering.sortModelsDesc(accumulated);
  }

  @override
  Future<List<ProjectModel>> fetchProjects({
    int maxItems = kProjectsDashboardMaxProjects,
  }) async {
    final accumulated = <ProjectModel>[];
    var offset = 0;

    while (accumulated.length < maxItems) {
      final remaining = maxItems - accumulated.length;
      final pageSize = remaining < kProjectsBulkFetchPageSize
          ? remaining
          : kProjectsBulkFetchPageSize;

      final page = await fetchProjectsPage(
        limit: pageSize,
        offset: offset,
      );

      if (page.projects.isEmpty) break;
      accumulated.addAll(page.projects);
      offset += page.projects.length;

      if (!page.hasMore) break;
    }

    return ProjectsListOrdering.sortModelsDesc(accumulated);
  }

  /// Loads projects for group-by hub (higher cap, optional hub filters).
  Future<List<ProjectModel>> fetchProjectsForGroupHub({
    ProjectsGroupHubFilters? filters,
    int maxItems = kProjectsGroupHubMaxProjects,
  }) async {
    final accumulated = <ProjectModel>[];
    var offset = 0;
    final f = filters ?? const ProjectsGroupHubFilters();

    while (accumulated.length < maxItems) {
      final remaining = maxItems - accumulated.length;
      final pageSize = remaining < kProjectsBulkFetchPageSize
          ? remaining
          : kProjectsBulkFetchPageSize;

      final page = await fetchProjectsPage(
        limit: pageSize,
        offset: offset,
        year: f.year,
        month: f.month,
        projectStatusCompute: f.projectStatusCompute,
        woRefNo: f.woRefNo,
        woTypeNoOffice: f.woTypeNoOffice,
        nameSearch: f.searchName,
        portfolio: true,
      );

      if (page.projects.isEmpty) break;
      accumulated.addAll(page.projects);
      offset += page.projects.length;
      if (!page.hasMore) break;
    }

    return ProjectsListOrdering.sortModelsDesc(accumulated);
  }

  static void _applyGroupHubFilters(
    Map<String, dynamic> params,
    ProjectsGroupHubFilters? filters,
  ) {
    if (filters == null) return;
    params.addAll(filters.toApiParams());
  }

  @override
  Future<ProjectsPagedResult> fetchProjectsPage({
    int limit = kProjectsBulkFetchPageSize,
    int offset = 0,
    String? keyword,
    int? year,
    int? month,
    String? projectStatusCompute,
    String? woRefNo,
    String? woTypeNoOffice,
    String? nameSearch,
    bool portfolio = false,
  }) async {
    final token = _getToken();

    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };

    final params = <String, dynamic>{
      "limit": limit,
      "offset": offset,
    };
    ProjectsListOrdering.applyApiOrderParams(params);
    if (portfolio) {
      params['portfolio'] = 1;
      params['scope'] = 'portfolio';
    }
    if (keyword != null && keyword.trim().isNotEmpty) {
      params["keyword"] = keyword.trim();
    }
    if (year != null) params['year'] = year;
    if (month != null) params['month'] = month;
    if (projectStatusCompute != null &&
        projectStatusCompute.trim().isNotEmpty) {
      params['project_status_compute'] = projectStatusCompute.trim();
    }
    final wo = woRefNo?.trim();
    if (wo != null && wo.isNotEmpty) params['wo_ref_no'] = wo;
    if (woTypeNoOffice != null && woTypeNoOffice.trim().isNotEmpty) {
      params['wo_type_no_office'] = woTypeNoOffice.trim();
    }
    final nameQ = nameSearch?.trim();
    if (nameQ != null && nameQ.isNotEmpty) {
      params['name'] = nameQ;
      params['search_name'] = nameQ;
    }

    final body = jsonEncode({
      "jsonrpc": "2.0",
      "params": params,
    });

    final v2Url = Uri.parse("${UrlUtil.baseUrl}$_v2GetProjects");
    final v1Url = Uri.parse("${UrlUtil.baseUrl}get_projects");

    final http.Response response;
    if (portfolio) {
      response = await _jsonGetTryV2(
        v2Url: v2Url,
        v1Url: v1Url,
        headers: headers,
        body: body,
      );
    } else {
      final request = http.Request('GET', v1Url)
        ..headers.addAll(headers)
        ..body = body;
      response = await _runQueued(() async {
        final streamedResponse =
            await _client.send(request).timeout(_apiTimeout);
        return http.Response.fromStream(streamedResponse);
      });
    }

    debugPrint(
      'fetchProjectsPage: limit=$limit offset=$offset portfolio=$portfolio '
      'v2=${_projectsHubV2Available} '
      'status=${response.statusCode} bytes=${response.body.length}',
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final result = Map<String, dynamic>.from(decoded['result'] as Map);
      final List data = result['data'] as List;
      final projects = ProjectsListOrdering.sortModelsDesc(
        data
            .map((e) => ProjectModel.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ))
            .where((p) => !p.isGeneralWo),
      );
      return _parsePagedPartnerProjects(result, projects, limit, offset);
    } else {
      throw Exception('Failed to load projects: ${response.statusCode}');
    }
  }

  @override
  Future<List<AttachmentModel>> fetchProjectAttachments(String projectId,
      {String? folderType}) async {
    debugPrint(
        "🔶 fetchProjectAttachments CALLED with projectId: $projectId, folderType: $folderType");
    final token = _getToken();

    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };

    final url = Uri.parse("${UrlUtil.baseUrl}get_project_attachments");

    // Build params with optional folder_type
    final params = <String, dynamic>{
      "project_id": int.tryParse(projectId) ?? 0,
    };
    if (folderType != null) {
      params["folder_type"] = folderType;
    }

    final body = jsonEncode({
      "jsonrpc": "2.0",
      "params": params,
    });

    debugPrint("===============================");
    debugPrint("fetchProjectAttachments REQUEST:");
    debugPrint("URL: $url");
    debugPrint("Body: $body");
    debugPrint("===============================");

    final response = await _client.post(url, headers: headers, body: body);

    debugPrint("fetchProjectAttachments RESPONSE: ${response.statusCode}");
    debugPrint("fetchProjectAttachments: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);

      // Check for success status
      if (decoded['result'] != null &&
          decoded['result']['status'] == 'success' &&
          decoded['result']['data'] != null) {
        final List data = decoded['result']['data'];
        return data.map((e) => AttachmentModel.fromJson(e)).toList();
      } else {
        throw Exception('Invalid response format');
      }
    } else {
      throw Exception('Failed to load attachments: ${response.statusCode}');
    }
  }

  @override
  Future<List<PartnerModel>> fetchPartnerProjects(
      {int? partnerId, String? keyword}) async {
    final token = _getToken();

    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };

    final url = Uri.parse("${UrlUtil.baseUrl}get_partner_projects");

    final body = jsonEncode({
      "jsonrpc": "2.0",
      "params": {
        "partner_id": partnerId,
        "keyword": keyword,
      },
    });

    final response = await _client.post(url, headers: headers, body: body);

    debugPrint("fetchPartnerProjects: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final List data = decoded['result']['data'];
      return data.map((e) => PartnerModel.fromJson(e)).toList();
    } else {
      throw Exception(
          'Failed to load partner projects: ${response.statusCode}');
    }
  }

  @override
  Future<List<ProjectModel>> fetchProjectsByPartnerId(int partnerId) async {
    final page = await fetchProjectsByFilters(
      partnerId: partnerId,
      limit: kProjectsListPageSize,
      offset: 0,
    );
    return page.projects;
  }

  static List<ProjectModel> _flattenGroupedProjects(List<dynamic> data) {
    final List<ProjectModel> allProjects = [];
    for (final partnerData in data) {
      if (partnerData is! Map) continue;

      final partnerMap = Map<String, dynamic>.from(partnerData);
      final projectsList = partnerMap['projects'];
      if (projectsList is List) {
        // Inherit partner/agreement labels when nested rows omit them.
        final parentPartnerId =
            partnerMap['partner_id'] ?? partnerMap['partner'];
        final parentPartnerName = partnerMap['partner_name'] ??
            partnerMap['client_name'] ??
            OdooFieldParsers.parseMany2oneName(parentPartnerId);
        final parentAgreement =
            partnerMap['agreement_id'] ?? partnerMap['agreement'];
        final parentPhoto =
            partnerMap['icon'] ?? partnerMap['partner_photo'] ?? partnerMap['photo_url'];

        for (final projectJson in projectsList) {
          if (projectJson is! Map) continue;
          final row = Map<String, dynamic>.from(projectJson);
          row.putIfAbsent('partner_id', () => parentPartnerId);
          if (parentPartnerName != null &&
              parentPartnerName.toString().trim().isNotEmpty) {
            row.putIfAbsent('partner_name', () => parentPartnerName);
          }
          if (parentAgreement != null) {
            row.putIfAbsent('agreement_id', () => parentAgreement);
          }
          if (parentPhoto != null) {
            row.putIfAbsent('client_image', () => parentPhoto);
          }
          allProjects.add(ProjectModel.fromJson(row));
        }
      } else if (partnerMap.containsKey('project_id') ||
          partnerMap.containsKey('id')) {
        allProjects.add(ProjectModel.fromJson(partnerMap));
      }
    }
    return ProjectsListOrdering.sortModelsDesc(
      allProjects.where((p) => !p.isGeneralWo),
    );
  }

  static ProjectsPagedResult _parsePagedPartnerProjects(
    Map<String, dynamic> result,
    List<ProjectModel> projects,
    int limit,
    int offset,
  ) {
    final ordered = ProjectsListOrdering.sortModelsDesc(projects);
    final pagination = result['pagination'];
    if (pagination is Map) {
      final p = Map<String, dynamic>.from(pagination);
      final total = _asInt(p['total'], ordered.length);
      final lim = _asInt(p['limit'], limit);
      final off = _asInt(p['offset'], offset);
      final hasMore = p['has_more'] == true ||
          (p['has_more'] == null && (off + ordered.length) < total);
      return ProjectsPagedResult(
        projects: ordered,
        total: total,
        limit: lim,
        offset: off,
        hasMore: hasMore,
      );
    }

    return ProjectsPagedResult(
      projects: ordered,
      total: ordered.length,
      limit: limit,
      offset: offset,
      hasMore: false,
    );
  }

  static int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  @override
  Future<ProjectsPagedResult> fetchProjectsByFilters({
    int? agreementId,
    int? partnerId,
    int? projectManagerId,
    int? cityId,
    String? keyword,
    ProjectsGroupHubFilters? hubFilters,
    int limit = kProjectsListPageSize,
    int offset = 0,
  }) async {
    final token = _getToken();

    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };

    final useV2 = hubFilters != null;
    final v2Url = Uri.parse("${UrlUtil.baseUrl}$_v2PartnerProjects");
    final v1Url = Uri.parse("${UrlUtil.baseUrl}get_partner_projects");

    final params = <String, dynamic>{
      "agreement": agreementId,
      "agreement_id": agreementId,
      "partner_id": partnerId,
      "project_manager_id": projectManagerId,
      "city_id": cityId,
      "limit": limit,
      "offset": offset,
    };
    ProjectsListOrdering.applyApiOrderParams(params);
    // Partner/agreement drill-down must stay newest-first even if a caller
    // pre-seeded a conflicting order key.
    params['order'] = ProjectsListOrdering.apiOrder;
    params['sort'] = 'desc';
    if (keyword != null && keyword.trim().isNotEmpty) {
      params["keyword"] = keyword.trim();
    }
    if (useV2) {
      _applyGroupHubFilters(params, hubFilters);
    }

    final body = jsonEncode({
      "jsonrpc": "2.0",
      "method": "call",
      "params": params,
    });

    final http.Response response;
    if (useV2) {
      response = await _jsonPostTryV2(
        v2Url: v2Url,
        v1Url: v1Url,
        headers: headers,
        body: body,
      );
    } else {
      response = await _runQueued(
        () => _client.post(v1Url, headers: headers, body: body).timeout(_apiTimeout),
      );
    }

    debugPrint(
      "fetchProjectsByFilters: limit=$limit offset=$offset "
      "v2=${_projectsHubV2Available} "
      "status=${response.statusCode} bytes=${response.body.length}",
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);

      if (decoded['result'] != null &&
          decoded['result']['status'] == 'success' &&
          decoded['result']['data'] != null) {
        final result = Map<String, dynamic>.from(decoded['result'] as Map);
        final List data = result['data'] as List;
        final projects = _flattenGroupedProjects(data);
        return _parsePagedPartnerProjects(result, projects, limit, offset);
      } else {
        throw Exception('Invalid response format');
      }
    } else {
      throw Exception(
          'Failed to load filtered projects: ${response.statusCode}');
    }
  }

  @override
  Future<List<FolderModel>> fetchProjectFolders() async {
    final token = _getToken();

    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };

    final url = Uri.parse("${UrlUtil.baseUrl}project_folders");

    final body = jsonEncode({
      "jsonrpc": "2.0",
      "id": null,
    });

    final request = http.Request('GET', url)
      ..headers.addAll(headers)
      ..body = body;

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    debugPrint("fetchProjectFolders: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);

      if (decoded['result'] != null &&
          decoded['result']['status'] == 'success' &&
          decoded['result']['data'] != null) {
        final List data = decoded['result']['data'];
        return data.map((e) => FolderModel.fromJson(e)).toList();
      } else {
        throw Exception('Invalid response format');
      }
    } else {
      throw Exception('Failed to load folders: ${response.statusCode}');
    }
  }

  @override
  Future<UserProjectsResponse> fetchClientsList() async {
    final token = _getToken();

    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };

    final v1Url = Uri.parse("${UrlUtil.baseUrl}clients/list");
    final v2Url = Uri.parse("${UrlUtil.baseUrl}$_v2ClientsList");

    final body = jsonEncode({
      "jsonrpc": "2.0",
      "params": {
        "group_by": "agreement",
      },
    });

    final response = await _jsonGetTryV2(
      v2Url: v2Url,
      v1Url: v1Url,
      headers: headers,
      body: body,
    );

    debugPrint(
      'fetchClientsList: status=${response.statusCode} '
      'bytes=${response.body.length}',
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body) as Map<String, dynamic>;
      final result = decoded['result'] as Map<String, dynamic>?;

      if (result != null && result['status'] == 'success') {
        final clientsJson = result['data'] as List<dynamic>? ?? [];
        final projects =
            clientsJson.map((e) => UserProjectModel.fromJson(e)).toList();

        return UserProjectsResponse(
          success: true,
          employeeId: 0,
          projects: projects,
        );
      }

      throw Exception('Invalid response format');
    } else {
      throw Exception('Failed to load clients list: ${response.statusCode}');
    }
  }

  @override
  Future<ProjectsDashboardSummaryModel> fetchProjectsDashboardSummary() async {
    final token = _getToken();

    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };

    final url = Uri.parse("${UrlUtil.baseUrl}projects/dashboard_summary");

    final body = jsonEncode({
      "jsonrpc": "2.0",
      "params": {},
    });

    final request = http.Request('GET', url)
      ..headers.addAll(headers)
      ..body = body;

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    debugPrint(
      "fetchProjectsDashboardSummary: ${request.url} status=${response.statusCode}",
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load dashboard summary: ${response.statusCode}',
      );
    }

    final decoded = json.decode(response.body) as Map<String, dynamic>;
    final result = decoded['result'] as Map<String, dynamic>?;

    if (result == null || result['status'] != 'success') {
      throw Exception(
        result?['message']?.toString() ?? 'Invalid dashboard summary response',
      );
    }

    final data = result['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid dashboard summary data format');
    }

    return ProjectsDashboardSummaryModel.fromJson(data);
  }

  @override
  Future<List<ProjectManagerFilterItem>> fetchProjectManagersList({
    ProjectsGroupHubFilters? filters,
  }) async {
    // Project-first grouping — never use v1 clients/list (id=0 "No Manager" bucket).
    final projects = await fetchProjectsForGroupHub(
      filters: filters,
      maxItems: kProjectsGroupHubMaxProjects,
    );
    final filtered = ProjectsGroupHubFilterApplier.apply(
      projects,
      filters ?? const ProjectsGroupHubFilters(),
    );
    return ProjectsGroupListBuilder.fromProjects(
      filtered,
      ProjectsGroupByMode.projectManager,
      allowNameFallback: true,
    );
  }

  @override
  Future<List<ProjectManagerFilterItem>> fetchClientsGroupedList({
    required String groupBy,
    ProjectsGroupHubFilters? filters,
  }) async {
    final token = _getToken();

    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };

    final v2Url = Uri.parse("${UrlUtil.baseUrl}$_v2ClientsList");
    final v1Url = Uri.parse("${UrlUtil.baseUrl}clients/list");

    final params = <String, dynamic>{
      "group_by": groupBy,
    };
    _applyGroupHubFilters(params, filters);

    final body = jsonEncode({
      "jsonrpc": "2.0",
      "method": "call",
      "params": params,
    });

    final response = await _jsonGetTryV2(
      v2Url: v2Url,
      v1Url: v1Url,
      headers: headers,
      body: body,
    );

    debugPrint(
      'fetchClientsGroupedList($groupBy): status=${response.statusCode} '
      'v2=${_projectsHubV2Available} bytes=${response.body.length}',
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load grouped clients: ${response.statusCode}');
    }

    final decoded = json.decode(response.body) as Map<String, dynamic>;
    final result = decoded['result'] as Map<String, dynamic>?;
    if (result == null || result['status'] != 'success') {
      throw Exception('Invalid grouped clients response format');
    }

    var list = (result['data'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((e) =>
            ProjectManagerFilterItem.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);

    return list;
  }

  @override
  Future<ProjectDocumentsResponse> fetchProjectDocuments(int projectId,
      {String? folderType}) async {
    final token = _getToken();

    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };

    final url = Uri.parse("${UrlUtil.baseUrl}projects/documents");

    // Only include folder_type if provided
    final params = <String, dynamic>{
      "project_id": projectId,
    };
    if (folderType != null) {
      params["folder_type"] = folderType;
    }

    final body = jsonEncode({
      "jsonrpc": "2.0",
      "params": params,
    });

    debugPrint("===============================");
    debugPrint("fetchProjectDocuments REQUEST:");
    debugPrint("URL: $url");
    debugPrint("Body: $body");
    debugPrint("===============================");

    // Use GET request with body
    final request = http.Request('GET', url)
      ..headers.addAll(headers)
      ..body = body;

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    debugPrint("fetchProjectDocuments RESPONSE: ${response.statusCode}");
    debugPrint("fetchProjectDocuments: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body) as Map<String, dynamic>;
      return ProjectDocumentsResponse.fromJson(decoded);
    } else {
      throw Exception(
          'Failed to load project documents: ${response.statusCode}');
    }
  }

  @override
  Future<FolderContentsResponse> fetchFolderContents(
      int projectId, String folderId) async {
    final token = _getToken();

    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };

    final url =
        Uri.parse("${UrlUtil.baseUrl}projects/documents/folder");

    final body = jsonEncode({
      "jsonrpc": "2.0",
      "params": {
        "project_id": projectId,
        "folder_id": folderId,
      },
    });

    debugPrint("===============================");
    debugPrint("fetchFolderContents REQUEST:");
    debugPrint("URL: $url");
    debugPrint("Body: $body");
    debugPrint("===============================");

    // Use GET request with body
    final request = http.Request('GET', url)
      ..headers.addAll(headers)
      ..body = body;

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    debugPrint("fetchFolderContents RESPONSE: ${response.statusCode}");
    debugPrint("fetchFolderContents: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body) as Map<String, dynamic>;
      return FolderContentsResponse.fromJson(decoded);
    } else {
      throw Exception('Failed to load folder contents: ${response.statusCode}');
    }
  }

  @override
  Future<FileDetailsResponse> fetchFileDetails(
      int projectId, String fileId) async {
    final token = _getToken();

    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };

    final url = Uri.parse("${UrlUtil.baseUrl}projects/documents/file");

    final body = jsonEncode({
      "jsonrpc": "2.0",
      "params": {
        "project_id": projectId,
        "file_id": fileId,
      },
    });

    debugPrint("===============================");
    debugPrint("fetchFileDetails REQUEST:");
    debugPrint("URL: $url");
    debugPrint("Body: $body");
    debugPrint("===============================");

    // Use GET request with body
    final request = http.Request('GET', url)
      ..headers.addAll(headers)
      ..body = body;

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    debugPrint("fetchFileDetails RESPONSE: ${response.statusCode}");
    debugPrint("fetchFileDetails: ${response.body}");

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body) as Map<String, dynamic>;
      return FileDetailsResponse.fromJson(decoded);
    } else {
      throw Exception('Failed to load file details: ${response.statusCode}');
    }
  }

  @override
  Future<ProjectScurveData> fetchProjectScurve(
    int projectId, {
    int rangeStart = 1,
    int rangeSize = 500,
  }) async {
    final token = _getToken();
    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };
    const endpoint = "${UrlUtil.baseUrl}project/scurve";
    final url = Uri.parse(endpoint);
    final response = await _client.post(
      url,
      headers: headers,
      body: jsonEncode({
        "jsonrpc": "2.0",
        "id": null,
        "params": {
          "project_id": projectId,
          "range_start": rangeStart,
          "range_size": rangeSize,
        },
      }),
    );
    debugPrint("fetchProjectScurve [$endpoint]: ${response.statusCode}");
    debugPrint("fetchProjectScurve body: ${response.body}");

    if (response.statusCode != 200) {
      throw Exception('Failed to load project analytics (${response.statusCode})');
    }

    final decoded = json.decode(response.body) as Map<String, dynamic>;
    final result = decoded['result'] as Map<String, dynamic>?;
    if (result == null) {
      return ProjectScurveData.empty();
    }
    if (result['status'] != 'success' || result['data'] == null) {
      return ProjectScurveData.empty(
        projectName: result['project']?.toString() ?? '',
      );
    }

    var data = ProjectScurveData.fromJson(
      (result['data'] as Map).cast<String, dynamic>(),
    );

    // Ensure we fetch all weeks, not only the default window.
    final totalWeeks = data.totalWeeks;
    if (totalWeeks > data.series.length) {
      final fullResponse = await _client.post(
        url,
        headers: headers,
        body: jsonEncode({
          "jsonrpc": "2.0",
          "id": null,
          "params": {
            "project_id": projectId,
            "range_start": 1,
            "range_size": totalWeeks,
          },
        }),
      );
      if (fullResponse.statusCode == 200) {
        final fullDecoded = json.decode(fullResponse.body) as Map<String, dynamic>;
        final fullResult = fullDecoded['result'] as Map<String, dynamic>?;
        if (fullResult != null &&
            fullResult['status'] == 'success' &&
            fullResult['data'] != null) {
          data = ProjectScurveData.fromJson(
            (fullResult['data'] as Map).cast<String, dynamic>(),
          );
        }
      }
    }

    return data;
  }

  @override
  Future<ProjectExpenseDashboardModel> fetchProjectExpenseDashboard(
    int projectId,
  ) async {
    final token = _getToken();
    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };
    const endpoint = "${UrlUtil.baseUrl}project/expense/dashboard";
    final response = await _client.post(
      Uri.parse(endpoint),
      headers: headers,
      body: jsonEncode({
        "jsonrpc": "2.0",
        "id": null,
        "params": {
          "project_id": projectId,
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load expense dashboard (${response.statusCode})',
      );
    }

    final decoded = json.decode(response.body) as Map<String, dynamic>;
    final result = decoded['result'] as Map<String, dynamic>?;
    if (result == null || result['status'] != 'success') {
      throw Exception(
        result?['message']?.toString() ?? 'Invalid expense dashboard response',
      );
    }
    final payload = result['data'] is Map
        ? (result['data'] as Map).cast<String, dynamic>()
        : result;
    return ProjectExpenseDashboardModel.fromJson(
      payload,
    );
  }

  @override
  Future<ProjectFinancialModel> fetchProjectFinancialData(
    int projectId, {
    String? dateFrom,
    String? dateTo,
  }) async {
    final token = _getToken();
    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };
    final params = <String, dynamic>{"project_id": projectId};
    if ((dateFrom ?? '').isNotEmpty && (dateTo ?? '').isNotEmpty) {
      params['date_from'] = dateFrom;
      params['date_to'] = dateTo;
    }

    const endpoint = "${UrlUtil.baseUrl}project/financial";
    final response = await _client.post(
      Uri.parse(endpoint),
      headers: headers,
      body: jsonEncode({
        "jsonrpc": "2.0",
        "id": null,
        "params": params,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load financial statement (${response.statusCode})',
      );
    }

    final decoded = json.decode(response.body) as Map<String, dynamic>;
    final result = decoded['result'] as Map<String, dynamic>?;
    if (result == null || result['status'] != 'success') {
      throw Exception(
        result?['message']?.toString() ?? 'Invalid financial statement response',
      );
    }
    final payload = result['data'] is Map
        ? (result['data'] as Map).cast<String, dynamic>()
        : result;
    return ProjectFinancialModel.fromJson(
      payload,
    );
  }

  Future<Map<String, dynamic>> _postJsonSuccess(
    String endpoint,
    Map<String, dynamic> params,
    String errorLabel,
  ) async {
    final token = _getToken();
    final headers = {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "Authorization": "Bearer $token",
    };
    final response = await _runQueued(
      () => _client
          .post(
            Uri.parse(endpoint),
            headers: headers,
            body: jsonEncode({
              "jsonrpc": "2.0",
              "id": null,
              "params": params,
            }),
          )
          .timeout(_apiTimeout),
    );

    if (response.statusCode != 200) {
      throw Exception('$errorLabel (${response.statusCode})');
    }

    final decoded = json.decode(response.body) as Map<String, dynamic>;
    final result = decoded['result'] as Map<String, dynamic>?;
    if (result == null || result['status'] != 'success') {
      throw Exception(
        result?['message']?.toString() ?? 'Invalid $errorLabel response',
      );
    }

    if (result['data'] is Map) {
      return Map<String, dynamic>.from(result['data'] as Map);
    }
    return result;
  }

  @override
  Future<ProjectExpenseSummaryModel> fetchProjectExpenseSummary(
    int projectId,
  ) async {
    final payload = await _postJsonSuccess(
      '${UrlUtil.baseUrl}project/expense/summary',
      {'project_id': projectId},
      'expense summary',
    );
    return ProjectExpenseSummaryModel.fromJson(payload);
  }

  @override
  Future<ProjectExpenseBreakdownResult> fetchProjectExpenseBreakdown(
    int projectId,
  ) async {
    final payload = await _postJsonSuccess(
      '${UrlUtil.baseUrl}project/expense/breakdown',
      {'project_id': projectId},
      'expense breakdown',
    );
    return ProjectExpenseBreakdownResult.fromJson(payload);
  }
}
