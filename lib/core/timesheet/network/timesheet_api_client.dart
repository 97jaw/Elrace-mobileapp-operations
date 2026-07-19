import 'package:dio/dio.dart';
import 'package:el_race/core/timesheet/models/timesheet_foreman_summary.dart';
import 'package:el_race/core/timesheet/models/timesheet_model_parsers.dart'
    show tmIntOrNullFromJson;
import 'package:el_race/core/timesheet/models/timesheet_team_member.dart';
import 'package:el_race/core/timesheet/models/timesheet_models.dart';
import 'package:el_race/core/timesheet/models/timesheet_print_report_result.dart';
import 'package:el_race/core/timesheet/models/timesheet_submit_request.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:flutter/foundation.dart';

import 'timesheet_api_envelope.dart';
import '../models/timesheet_hr_mapping.dart';
import '../providers/timesheet_role_provider.dart';
import '../services/timesheet_project_access_service.dart';
import '../timesheet_defaults.dart';
import 'timesheet_odoo_api_catalog.dart';
import 'timesheet_odoo_employee.dart';
import 'timesheet_odoo_mappers.dart';
import 'timesheet_odoo_transport.dart';

/// Module 6 Odoo bridge — **Phase A** uses existing production controllers.
class TimesheetApiClient {
  TimesheetApiClient({
    Dio? dio,
    TimesheetOdooTransport? transport,
    this.useMockData = false,
    this.useMockSubmit = false,
    this.fallbackToMockOnError = true,
    this.baseUrl = 'https://erp.elrace.com/api',
  }) : _transport = transport ??
            TimesheetOdooTransport(
              dio: dio ?? Dio(),
              baseUrl: baseUrl,
            );

  final TimesheetOdooTransport _transport;
  final bool useMockData;
  final bool useMockSubmit;
  final bool fallbackToMockOnError;
  final String baseUrl;

  List<Project>? _projectsCache;
  int _siteCompletedCount = 0;
  List<TimesheetProjectAccessRow>? _projectAccessRows;
  List<Task>? _tasksCache;
  List<TimesheetOdooEmployee>? _employeesCache;
  TimesheetHrEmployeeScope? _hrScopeCache;
  String? _cachedProjectsRole;
  DateTime? _cacheAt;
  static const _cacheTtl = Duration(minutes: 2);

  bool get _useLiveOdoo => !useMockData && _transport.hasSession;

  bool get hasLiveSession => _transport.hasSession;

  Dio get dio => _transport.dio;

  // ---------------------------------------------------------------------------
  // Projects
  // ---------------------------------------------------------------------------

  int get siteCompletedProjectCount => _siteCompletedCount;

  Future<TimesheetApiEnvelope<List<Project>>> getProjects({
    required String role,
    bool hrWideScope = false,
    String status = 'in_progress',
  }) async {
    if (!_useLiveOdoo) {
      return _ok(_mockProjects(hrWideScope: hrWideScope));
    }
    try {
      await _ensureProjectsLoaded(
        role: role,
        hrWideScope: hrWideScope,
        status: status,
      );
      final projects = _projectsCache ?? const <Project>[];
      return _ok(projects);
    } catch (error, stack) {
      return _handleError(
        'getProjects',
        error,
        stack,
        fallback: () => _mockProjects(hrWideScope: hrWideScope),
      );
    }
  }

  Future<TimesheetApiEnvelope<Project>> getProject(String projectId) async {
    if (!_useLiveOdoo) {
      return _ok(
        _mockProjects(hrWideScope: true).firstWhere(
          (p) => p.id == projectId,
          orElse: () => _mockProjects(hrWideScope: true).first,
        ),
      );
    }
    try {
      await _ensureProjectsLoaded(hrWideScope: true);
      final match = _projectsCache?.where((p) => p.id == projectId);
      if (match != null && match.isNotEmpty) return _ok(match.first);
      return TimesheetApiEnvelope(
        success: false,
        data: null,
        error: 'Project not found',
        uiStatus: 'NOT_FOUND',
      );
    } catch (error, stack) {
      return _handleError(
        'getProject',
        error,
        stack,
        fallback: () => _mockProjects(hrWideScope: true).first,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Tasks
  // ---------------------------------------------------------------------------

  Future<TimesheetApiEnvelope<List<Task>>> getProjectTasks({
    required String projectId,
    String foremanId = '',
  }) async {
    if (!_useLiveOdoo) {
      return _ok(
        _mockTasks().where((task) => task.projectId == projectId).toList(),
      );
    }
    try {
      await _ensureTasksLoaded();
      final tasks = (_tasksCache ?? const <Task>[])
          .where((task) => task.projectId == projectId)
          .toList();
      return _ok(tasks);
    } catch (error, stack) {
      return _handleError(
        'getProjectTasks',
        error,
        stack,
        fallback: () =>
            _mockTasks().where((t) => t.projectId == projectId).toList(),
      );
    }
  }

  Future<TimesheetApiEnvelope<Task>> getTask(String taskId) async {
    if (!_useLiveOdoo) {
      return _ok(
        _mockTasks().firstWhere(
          (t) => t.id == taskId,
          orElse: () => _mockTasks().first,
        ),
      );
    }
    try {
      await _ensureTasksLoaded();
      final match = _tasksCache?.where((t) => t.id == taskId);
      if (match != null && match.isNotEmpty) return _ok(match.first);
      return TimesheetApiEnvelope(
        success: false,
        data: null,
        error: 'Task not found',
        uiStatus: 'NOT_FOUND',
      );
    } catch (error, stack) {
      return _handleError(
        'getTask',
        error,
        stack,
        fallback: () => _mockTasks().firstWhere(
          (t) => t.id == taskId,
          orElse: () => _mockTasks().first,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Workers & attendance (existing read APIs)
  // ---------------------------------------------------------------------------

  Future<List<TimesheetOdooEmployee>> fetchEmployeeRoster() async {
    if (!_useLiveOdoo) return const [];
    await _ensureEmployeesLoaded();
    return List<TimesheetOdooEmployee>.from(_employeesCache ?? const []);
  }

  /// Labors for timesheet report — ``/timesheet/labor_list`` then ``/employee/list``.
  ///
  /// [cancelToken] lets a caller (e.g. a tab that's been dismissed) abort
  /// both the primary and legacy-fallback attempt instead of letting either
  /// complete pointlessly in the background. Per FIX_IMPLEMENTATION_PLAN.md
  /// Phase 3.2 — this is the specific fetch behind TmProjectFaceEnrollTab's
  /// roster load.
  Future<List<TimesheetOdooEmployee>> fetchLaborEmployeesForReport({
    String? projectId,
    bool includeDrivers = true,
    bool useHrScopeWhenNoProject = true,
    CancelToken? cancelToken,
  }) async {
    if (!_useLiveOdoo) {
      throw TimesheetOdooException(
        'Not connected to Odoo API (missing login session)',
      );
    }

    final parsedProjectId = projectId?.trim();
    final hasProject =
        parsedProjectId != null && parsedProjectId.isNotEmpty;
    final params = <String, dynamic>{
      'include_drivers': includeDrivers,
      if (hasProject)
        'project_id': int.tryParse(parsedProjectId!) ?? parsedProjectId,
      if (!hasProject && useHrScopeWhenNoProject) 'use_hr_scope': true,
    };

    try {
      final fromTimesheet = await _fetchLaborListFromEndpoint(
        TimesheetOdooApiCatalog.timesheetLaborList,
        params: params,
        debugLabel: 'timesheet/labor_list',
        cancelToken: cancelToken,
      );
      if (fromTimesheet.isNotEmpty) return fromTimesheet;
    } catch (error, stack) {
      debugPrint(
        'TimesheetApiClient.fetchLaborEmployeesForReport '
        '(timesheet/labor_list): $error\n$stack',
      );
    }

    try {
      final fromLegacy = await _fetchLaborListFromEndpoint(
        TimesheetOdooApiCatalog.employeeList,
        params: const {},
        debugLabel: 'employee/list',
        cancelToken: cancelToken,
      );
      if (fromLegacy.isNotEmpty) return fromLegacy;
    } catch (error, stack) {
      debugPrint(
        'TimesheetApiClient.fetchLaborEmployeesForReport '
        '(employee/list): $error\n$stack',
      );
      throw TimesheetOdooException(
        'Labor list API failed. Deploy /api/timesheet/labor_list on server '
        'or fix POST /api/employee/list. ($error)',
      );
    }

    throw TimesheetOdooException(
      'Labor list API returned no employees',
    );
  }

  Future<List<TimesheetOdooEmployee>> _fetchLaborListFromEndpoint(
    String path, {
    required Map<String, dynamic> params,
    required String debugLabel,
    CancelToken? cancelToken,
  }) async {
    final body =
        await _transport.postJsonRpc(path, params: params, cancelToken: cancelToken);
    final result = _transport.parseResult(body, debugLabel: debugLabel);
    final data = _unwrapOdooSuccessMap(result);
    final rows = _transport.parseMapList(
      data ?? result,
      key: 'employees',
    );
    final employees = rows.map(TimesheetOdooEmployee.fromJson).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    debugPrint(
      'TimesheetApiClient._fetchLaborListFromEndpoint($debugLabel): '
      '${employees.length} labors',
    );
    return employees;
  }

  /// Staff assigned to a project (`staff_list_ids` + `supervisor_ids`).
  Future<List<TimesheetTeamMember>> fetchProjectStaff(String projectId) async {
    if (!_useLiveOdoo || projectId.trim().isEmpty) return const [];
    try {
      final body = await _transport.postJsonRpc(
        TimesheetOdooApiCatalog.projectStaff,
        params: {'project_id': int.tryParse(projectId) ?? projectId},
      );
      final result = _transport.parseResult(body, debugLabel: 'project_staff');
      final data = _unwrapOdooSuccessMap(result);
      if (data == null) return const [];
      final staff = data['staff'];
      if (staff is! List) return const [];
      return TimesheetHrMapping.teamMembersFromJson(staff);
    } catch (error, stack) {
      debugPrint('TimesheetApiClient.fetchProjectStaff failed: $error\n$stack');
      return const [];
    }
  }

  /// Per-foreman submission summary for a project (Site Management monitor).
  ///
  /// Backed by the new `/timesheet/project_foremen_summary` endpoint. Returns an
  /// empty list (never throws) when the endpoint is unavailable so the UI can
  /// render a graceful empty state.
  Future<List<TimesheetForemanSummary>> fetchProjectForemenSummary(
    String projectId,
  ) async {
    if (!_useLiveOdoo || projectId.trim().isEmpty) return const [];
    try {
      final body = await _transport.postJsonRpc(
        TimesheetOdooApiCatalog.projectForemenSummary,
        params: {'project_id': int.tryParse(projectId) ?? projectId},
      );
      final result =
          _transport.parseResult(body, debugLabel: 'project_foremen_summary');
      final data = _unwrapOdooSuccessMap(result);
      final rows = _transport.parseMapList(data ?? result, key: 'foremen');
      return rows
          .map(TimesheetForemanSummary.fromJson)
          .toList(growable: false);
    } catch (error, stack) {
      debugPrint(
        'TimesheetApiClient.fetchProjectForemenSummary failed: $error\n$stack',
      );
      return const [];
    }
  }

  /// Render employee timesheet PDF for a date range (Odoo print wizard).
  Future<TimesheetPrintReportResult?> printTimesheetReport({
    required List<int> employeeIds,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    if (!_useLiveOdoo || employeeIds.isEmpty) return null;
    try {
      final body = await _transport.postJsonRpc(
        TimesheetOdooApiCatalog.printReport,
        params: {
          'employee_ids': employeeIds,
          'from_date':
              '${fromDate.year.toString().padLeft(4, '0')}-${fromDate.month.toString().padLeft(2, '0')}-${fromDate.day.toString().padLeft(2, '0')}',
          'to_date':
              '${toDate.year.toString().padLeft(4, '0')}-${toDate.month.toString().padLeft(2, '0')}-${toDate.day.toString().padLeft(2, '0')}',
        },
      );
      final result = _transport.parseResult(body, debugLabel: 'print_report');
      final data = _unwrapOdooSuccessMap(result);
      if (data == null) return null;
      return TimesheetPrintReportResult.fromApiData(data);
    } catch (error, stack) {
      debugPrint('TimesheetApiClient.printTimesheetReport failed: $error\n$stack');
      return null;
    }
  }

  Future<List<TimesheetProjectAccessRow>> fetchProjectAccessRows() async {
    if (!_useLiveOdoo) return const [];
    await _ensureProjectsLoaded();
    return List<TimesheetProjectAccessRow>.from(_projectAccessRows ?? const []);
  }

  Future<TimesheetApiEnvelope<List<Worker>>> getTaskWorkers(
    String taskId, {
    Set<int>? allowedLaborEmployeeIds,
  }) async {
    if (!_useLiveOdoo) {
      return _ok(_mockWorkers());
    }
    try {
      final taskEnv = await getTask(taskId);
      final task = taskEnv.data;
      if (task == null) {
        return TimesheetApiEnvelope(
          success: false,
          data: null,
          error: taskEnv.error ?? 'Task not found',
          uiStatus: taskEnv.uiStatus,
        );
      }
      await _ensureEmployeesLoaded();
      final now = DateTime.now();
      final rows = await _fetchTaskTimesheetRows(
        taskId: taskId,
        fromDate: now,
        toDate: now,
        filterToSingleDay: now,
      );
      final workers = TimesheetOdooMappers.workersForTask(
        task: task,
        roster: _employeesCache ?? const [],
        timesheetRows: rows,
        allowedLaborEmployeeIds: allowedLaborEmployeeIds,
      );
      return _ok(workers);
    } catch (error, stack) {
      return _handleError(
        'getTaskWorkers',
        error,
        stack,
        fallback: () => _mockWorkers(),
      );
    }
  }

  /// Today's timesheet rows for one task → FM3 attendance dots.
  Future<List<Map<String, dynamic>>> fetchProjectTimesheetRows({
    required String projectId,
    required DateTime date,
    Set<int>? allowedLaborEmployeeIds,
  }) async {
    await _ensureTasksLoaded();
    final projectTasks = (_tasksCache ?? const <Task>[])
        .where((task) => task.projectId == projectId)
        .toList();
    final allRows = <Map<String, dynamic>>[];
    for (final task in projectTasks) {
      if (!TimesheetDefaults.isOdooIntegerId(task.id)) continue;
      final rows = await _fetchTaskTimesheetRows(
        taskId: task.id,
        fromDate: date,
        toDate: date,
        filterToSingleDay: date,
      );
      allRows.addAll(rows);
    }
    if (allowedLaborEmployeeIds == null || allowedLaborEmployeeIds.isEmpty) {
      return allRows;
    }
    return allRows.where((row) {
      final id = tmIntOrNullFromJson(
        row['employee_id'] ?? row['emp_id'] ?? row['employee'],
      );
      return id != null && allowedLaborEmployeeIds.contains(id);
    }).toList();
  }

  Future<TimesheetApiEnvelope<List<AttendanceRecord>>> getTaskAttendance({
    required String projectId,
    required String taskId,
    required DateTime date,
    Set<int>? allowedLaborEmployeeIds,
  }) async {
    if (!_useLiveOdoo) {
      return _ok(_mockAttendance(projectId: projectId, date: date)
          .where((r) => r.taskId == taskId)
          .toList());
    }
    try {
      final rows = await _fetchTaskTimesheetRows(
        taskId: taskId,
        fromDate: date,
        toDate: date,
        filterToSingleDay: date,
      );
      var filteredRows = rows;
      if (allowedLaborEmployeeIds != null &&
          allowedLaborEmployeeIds.isNotEmpty) {
        filteredRows = rows.where((row) {
          final id = tmIntOrNullFromJson(
            row['employee_id'] ?? row['emp_id'] ?? row['employee'],
          );
          return id != null && allowedLaborEmployeeIds.contains(id);
        }).toList();
      }
      final records = TimesheetOdooMappers.attendanceFromTimesheetRows(
        projectId: projectId,
        taskId: taskId,
        rows: filteredRows,
        date: date,
      );
      return _ok(records);
    } catch (error, stack) {
      return _handleError(
        'getTaskAttendance',
        error,
        stack,
        fallback: () => _mockAttendance(projectId: projectId, date: date)
            .where((r) => r.taskId == taskId)
            .toList(),
      );
    }
  }

  Future<TimesheetApiEnvelope<List<AttendanceRecord>>> getAttendance({
    required String projectId,
    required DateTime date,
    Set<int>? allowedLaborEmployeeIds,
  }) async {
    if (!_useLiveOdoo) {
      return _ok(_mockAttendance(projectId: projectId, date: date));
    }
    try {
      await _ensureTasksLoaded();
      final projectTasks = (_tasksCache ?? const <Task>[])
          .where((task) => task.projectId == projectId)
          .toList();
      final allRecords = <AttendanceRecord>[];
      for (final task in projectTasks) {
        if (!TimesheetDefaults.isOdooIntegerId(task.id)) continue;
        final env = await getTaskAttendance(
          projectId: projectId,
          taskId: task.id,
          date: date,
        );
        allRecords.addAll(env.data ?? const []);
      }
      if (allowedLaborEmployeeIds != null &&
          allowedLaborEmployeeIds.isNotEmpty) {
        allRecords.removeWhere((record) {
          final id = TimesheetOdooMappers.employeeIdFromWorkerId(
            record.workerId,
          );
          return id == null || !allowedLaborEmployeeIds.contains(id);
        });
      }
      return _ok(allRecords);
    } catch (error, stack) {
      return _handleError(
        'getAttendance',
        error,
        stack,
        fallback: () => _mockAttendance(projectId: projectId, date: date),
      );
    }
  }

  Future<TimesheetApiEnvelope<Worker>> createWorker(Worker worker) async {
    if (!_useLiveOdoo) {
      await Future<void>.delayed(const Duration(milliseconds: 220));
      return _ok(worker);
    }
    // Phase B: POST /api/timesheet/workers
    return TimesheetApiEnvelope(
      success: false,
      data: null,
      error: 'POST /api/timesheet/workers not implemented (Phase B)',
      uiStatus: 'NOT_IMPLEMENTED',
    );
  }

  // ---------------------------------------------------------------------------
  // Submit — attendance write
  // ---------------------------------------------------------------------------

  Future<TimesheetSubmitResult> submitTimesheet(
    TimesheetSubmitRequest request,
  ) async {
    if (useMockSubmit || !_transport.hasSession) {
      await Future<void>.delayed(const Duration(milliseconds: 280));
      return TimesheetSubmitResult(
        success: true,
        message: useMockSubmit
            ? 'Timesheet recorded (mock)'
            : 'Timesheet recorded (offline mock — no token)',
      );
    }

    final token = SharedPref.getLoginData().result?.token;
    if (token == null || token.isEmpty) {
      return const TimesheetSubmitResult(
        success: false,
        message: 'Authentication token is missing',
      );
    }

    try {
      final response = await _transport.postJsonRpc(
        TimesheetOdooApiCatalog.submitTimesheet,
        params: request.toJsonRpcParams(),
      );
      final result = _transport.parseResult(response, debugLabel: 'submit');
      if (result is Map && result['success'] == true) {
        return TimesheetSubmitResult(
          success: true,
          message: result['message']?.toString(),
        );
      }
      final message = result is Map
          ? result['message']?.toString()
          : response['error']?.toString();
      return TimesheetSubmitResult(
        success: false,
        message: message ?? 'Submission failed',
      );
    } catch (error) {
      debugPrint('TimesheetApiClient.submitTimesheet failed: $error');
      return TimesheetSubmitResult(
        success: false,
        message: error.toString(),
      );
    }
  }

  /// Foreman assignment task for this project (Postman `task_id`), else Maintenance.
  Future<TimesheetApiEnvelope<Task>> getTimesheetTaskForProject(
    String projectId, {
    int? odooUserId,
    String? displayName,
  }) async {
    final tasksEnv = await getProjectTasks(projectId: projectId);
    final tasks = tasksEnv.data ?? const <Task>[];
    final foreman = TimesheetDefaults.tryResolveForemanTask(
      projectId: projectId,
      projectTasks: tasks,
      odooUserId: odooUserId ?? _transport.odooUserId,
      displayName: displayName,
    );
    if (foreman != null) return _ok(foreman);

    final maintenance = TimesheetDefaults.tryResolveMaintenanceTask(
      projectId: projectId,
      projectTasks: tasks,
    );
    if (maintenance != null) return _ok(maintenance);
    return TimesheetApiEnvelope(
      success: true,
      data: TimesheetDefaults.resolveMaintenanceTask(
        projectId: projectId,
        projectTasks: tasks,
      ),
      error: null,
      uiStatus: 'NO_TIMESHEET_TASK',
    );
  }

  /// Default **Maintenance** task for capture/submit on a project.
  Future<TimesheetApiEnvelope<Task>> getMaintenanceTask(String projectId) async {
    return getTimesheetTaskForProject(projectId);
  }

  /// Live day rows for task calendar (legacy task-sheet shape).
  Future<TimesheetApiEnvelope<List<TimesheetDayCountRow>>> getTaskDayCounts({
    required String taskId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (!TimesheetDefaults.isOdooIntegerId(taskId)) {
      return _ok(_mockDayCounts(startDate, endDate));
    }
    if (!_useLiveOdoo) {
      return _ok(_mockDayCounts(startDate, endDate));
    }
    try {
      final dates = <String>[];
      var cursor = DateTime(startDate.year, startDate.month, startDate.day);
      final end = DateTime(endDate.year, endDate.month, endDate.day);
      while (!cursor.isAfter(end)) {
        dates.add(_formatDate(cursor));
        cursor = cursor.add(const Duration(days: 1));
      }
      final rows = await _transport.fetchTimesheetCountsByDays(
        taskId: taskId,
        dateList: dates,
      );
      final mapped = rows.map(TimesheetDayCountRow.fromOdooJson).toList();
      return _ok(mapped);
    } catch (error, stack) {
      return _handleError(
        'getTaskDayCounts',
        error,
        stack,
        fallback: () => _mockDayCounts(startDate, endDate),
      );
    }
  }

  Future<TimesheetApiEnvelope<SiteReport>> submitReport(
    SiteReport report,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    return _ok(report);
  }

  // ---------------------------------------------------------------------------
  // Live Odoo loaders
  // ---------------------------------------------------------------------------

  /// Live `hr.employee` x_labor_ids / x_foreman_ids (+ member cards).
  Future<TimesheetHrEmployeeScope> fetchMyHrScope() async {
    if (!_useLiveOdoo) {
      return const TimesheetHrEmployeeScope(
        loginEmployeeId: null,
        laborEmployeeIds: {},
        foremanEmployeeIds: {},
      );
    }
    if (_isCacheFresh && _hrScopeCache != null) return _hrScopeCache!;

    try {
      final body = await _transport.postJsonRpc(
        TimesheetOdooApiCatalog.myHrScope,
        params: const {},
      );
      final result = _transport.parseResult(body, debugLabel: 'my_hr_scope');
      final map = _unwrapOdooSuccessMap(result);
      if (map != null) {
        final laborRaw = map['x_labor_ids'];
        final foremanRaw = map['x_foreman_ids'];
        final scope = TimesheetHrEmployeeScope(
          loginEmployeeId: tmIntOrNullFromJson(map['employee_id']),
          laborEmployeeIds:
              TimesheetHrMapping.employeeIdsFromJson(laborRaw).toSet(),
          foremanEmployeeIds:
              TimesheetHrMapping.employeeIdsFromJson(foremanRaw).toSet(),
          laborMembers: TimesheetHrMapping.teamMembersFromJson(laborRaw),
          foremanMembers: TimesheetHrMapping.teamMembersFromJson(foremanRaw),
        );
        if (scope.hasLaborScope || scope.hasForemanScope) {
          _hrScopeCache = scope;
          _touchCache();
          return scope;
        }
        debugPrint(
          'TimesheetApiClient.fetchMyHrScope: empty scope for employee '
          '${map['employee_id']}',
        );
      }
    } catch (error) {
      debugPrint('TimesheetApiClient.fetchMyHrScope: $error');
    }

    return _hrScopeFromRosterFallback();
  }

  Future<TimesheetHrEmployeeScope> _hrScopeFromRosterFallback() async {
    final login = SharedPref.getLoginDataOrNull()?.result?.data;
    var laborIds = TimesheetHrMapping.employeeIdsFromJson(login?.xLaborIdsRaw);
    var foremanIds =
        TimesheetHrMapping.employeeIdsFromJson(login?.xForemanIdsRaw);
    final loginEmployeeId = TimesheetProjectAccessService.loginEmployeeId();

    await _ensureEmployeesLoaded();
    TimesheetOdooEmployee? self;
    if (loginEmployeeId != null) {
      for (final member in _employeesCache ?? const []) {
        if (member.employeeId == loginEmployeeId) {
          self = member;
          break;
        }
      }
    }
    if (laborIds.isEmpty && self != null && self.laborIds.isNotEmpty) {
      laborIds = self.laborIds;
    }
    if (foremanIds.isEmpty && self != null && self.foremanIds.isNotEmpty) {
      foremanIds = self.foremanIds;
    }

    _hrScopeCache = TimesheetHrEmployeeScope(
      loginEmployeeId: loginEmployeeId,
      laborEmployeeIds: laborIds.toSet(),
      foremanEmployeeIds: foremanIds.toSet(),
      laborMembers: _membersFromIds(laborIds),
      foremanMembers: _membersFromIds(foremanIds),
    );
    _touchCache();
    return _hrScopeCache!;
  }

  List<TimesheetTeamMember> _membersFromIds(List<int> ids) {
    final roster = _employeesCache ?? const [];
    final members = <TimesheetTeamMember>[];
    for (final id in ids) {
      TimesheetOdooEmployee? match;
      for (final employee in roster) {
        if (employee.employeeId == id) {
          match = employee;
          break;
        }
      }
      if (match != null) {
        members.add(TimesheetTeamMember.fromEmployee(match));
      } else {
        members.add(
          TimesheetTeamMember(
            employeeId: id,
            name: 'Employee #$id',
            fileId: id.toString(),
          ),
        );
      }
    }
    return members;
  }

  Future<void> _ensureProjectsLoaded({
    String role = 'foreman',
    bool hrWideScope = false,
    String status = 'in_progress',
  }) async {
    final cacheKey = '$role|$status';
    if (_isCacheFresh &&
        _projectsCache != null &&
        _cachedProjectsRole == cacheKey) {
      return;
    }

    final resolution = tmRoleResolutionFromData(
      SharedPref.getLoginDataOrNull()?.result?.data,
    );
    final effectiveHrWide = hrWideScope || resolution.hrWideScope;

    // Prefer new Site Management API (server-side supervisor_ids / staff lines).
    if (_useLiveOdoo && !effectiveHrWide) {
      try {
        final body = await _transport.postJsonRpc(
          TimesheetOdooApiCatalog.siteProjects,
          params: {'status': status},
        );
        final result =
            _transport.parseResult(body, debugLabel: 'site_projects');
        final rows = _transport.parseMapList(result, key: 'data');
        if (result is Map && status == 'in_progress') {
          _siteCompletedCount =
              tmIntOrNullFromJson(result['completed_count']) ?? 0;
        }
        _projectsCache = rows
            .map((row) => TimesheetOdooMappers.projectFromGetProjects(row))
            .toList();
        _projectAccessRows = rows
            .map(TimesheetProjectAccessService.parseAccessRow)
            .toList();
        _cachedProjectsRole = cacheKey;
        _touchCache();
        return;
      } catch (error) {
        debugPrint('TimesheetApiClient.site_projects fallback: $error');
      }
    }

    final body = await _transport.getJsonRpc(
      TimesheetOdooApiCatalog.getProjects,
    );
    final result = _transport.parseResult(body, debugLabel: 'get_projects');
    final rows = _transport.parseMapList(result, key: 'data');
    final accessRows =
        rows.map(TimesheetProjectAccessService.parseAccessRow).toList();

    final scoped = effectiveHrWide
        ? accessRows
        : TimesheetProjectAccessService.filterForRole(
            rows: accessRows,
            resolution: TimesheetRoleResolution(
              role: role == 'pm'
                  ? TimesheetEffectiveRole.pm
                  : TimesheetEffectiveRole.foreman,
              hrWideScope: false,
            ),
            employeeId: TimesheetProjectAccessService.loginEmployeeId(),
          );

    _projectAccessRows = scoped;
    _projectsCache = scoped
        .map((row) => TimesheetOdooMappers.projectFromGetProjects(row.raw))
        .toList();
    _cachedProjectsRole = cacheKey;
    _touchCache();
  }

  Future<List<Project>> fetchCompletedSiteProjects() async {
    if (!_useLiveOdoo) {
      return _mockProjects(hrWideScope: false)
          .where((p) => p.status.toLowerCase().contains('complete'))
          .toList();
    }
    final body = await _transport.postJsonRpc(
      TimesheetOdooApiCatalog.siteProjects,
      params: {'status': 'completed'},
    );
    final result = _transport.parseResult(body, debugLabel: 'site_projects_completed');
    final rows = _transport.parseMapList(result, key: 'data');
    return rows.map(TimesheetOdooMappers.projectFromGetProjects).toList();
  }

  Future<void> _ensureTasksLoaded() async {
    if (_isCacheFresh && _tasksCache != null) return;
    final userId = _transport.odooUserId;
    if (userId == null) {
      throw TimesheetOdooException('Odoo user id is missing from session');
    }
    final body = await _transport.postJsonRpc(
      TimesheetOdooApiCatalog.tasksList,
      params: {'user_id': userId},
    );
    final result = _transport.parseResult(body, debugLabel: 'tasks/list');
    final rows = _transport.parseMapList(result, key: 'tasks');
    _tasksCache = TimesheetOdooMappers.tasksFromOdooList(rows);
    _touchCache();
  }

  Future<void> _ensureEmployeesLoaded() async {
    if (_isCacheFresh && _employeesCache != null) return;
    Object? lastError;
    try {
      _employeesCache = await _transport.fetchEmployees();
      _touchCache();
      return;
    } catch (error) {
      lastError = error;
      debugPrint('TimesheetApiClient._ensureEmployeesLoaded: $error');
    }

    try {
      final body = await _transport.postJsonRpc(
        TimesheetOdooApiCatalog.employeeList,
        params: const {},
      );
      final result = _transport.parseResult(body, debugLabel: 'employee/list');
      final rows = _transport.parseMapList(result, key: 'employees');
      _employeesCache = rows.map(TimesheetOdooEmployee.fromJson).toList();
      _touchCache();
      return;
    } catch (error) {
      lastError = error;
      debugPrint('TimesheetApiClient._ensureEmployeesLoaded fallback: $error');
    }

    throw TimesheetOdooException(
      lastError?.toString() ?? 'employee list failed',
    );
  }

  /// Raw rows for `EmptyShiftPage`-style day list.
  Future<List<Map<String, dynamic>>> fetchTaskTimesheetRowsForDate({
    required String taskId,
    required DateTime date,
  }) async {
    if (!_useLiveOdoo) return const [];
    if (!TimesheetDefaults.isOdooIntegerId(taskId)) return const [];
    return _fetchTaskTimesheetRows(
      taskId: taskId,
      fromDate: date,
      toDate: date,
      filterToSingleDay: date,
    );
  }

  /// Rows for a date range (home “Show all” / recent browse).
  Future<List<Map<String, dynamic>>> fetchTaskTimesheetRowsForRange({
    required String taskId,
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    if (!_useLiveOdoo) return const [];
    if (!TimesheetDefaults.isOdooIntegerId(taskId)) return const [];
    return _fetchTaskTimesheetRows(
      taskId: taskId,
      fromDate: fromDate,
      toDate: toDate,
    );
  }

  /// Rows for a date range across **all** integer-id tasks of a project.
  /// More robust than resolving a single maintenance/foreman task (which can
  /// yield a non-integer placeholder id and return nothing).
  Future<List<Map<String, dynamic>>> fetchProjectTimesheetRowsForRange({
    required String projectId,
    required DateTime fromDate,
    required DateTime toDate,
    Set<int>? allowedLaborEmployeeIds,
  }) async {
    if (!_useLiveOdoo) return const [];
    final tasksEnv = await getProjectTasks(projectId: projectId);
    final tasks = tasksEnv.data ?? const <Task>[];
    final allRows = <Map<String, dynamic>>[];
    final seenTaskIds = <String>{};
    for (final task in tasks) {
      if (!TimesheetDefaults.isOdooIntegerId(task.id)) continue;
      if (!seenTaskIds.add(task.id)) continue;
      try {
        final rows = await _fetchTaskTimesheetRows(
          taskId: task.id,
          fromDate: fromDate,
          toDate: toDate,
        );
        allRows.addAll(rows);
      } catch (_) {
        // Skip a task that fails; keep collecting from the rest.
      }
    }
    if (allowedLaborEmployeeIds == null || allowedLaborEmployeeIds.isEmpty) {
      return allRows;
    }
    return allRows.where((row) {
      final id = tmIntOrNullFromJson(
        row['employee_id'] ?? row['emp_id'] ?? row['employee'],
      );
      return id != null && allowedLaborEmployeeIds.contains(id);
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchTaskTimesheetRows({
    required String taskId,
    required DateTime fromDate,
    required DateTime toDate,
    DateTime? filterToSingleDay,
  }) async {
    if (!TimesheetDefaults.isOdooIntegerId(taskId)) return const [];
    final taskIdParam = int.parse(taskId);
    final body = await _transport.postJsonRpc(
      TimesheetOdooApiCatalog.taskTimesheetsList,
      params: {
        'task_id': taskIdParam,
        'from_date': _formatDate(fromDate),
        'to_date': _formatDate(toDate),
      },
    );
    final result =
        _transport.parseResult(body, debugLabel: 'task/timesheets/list');
    final rows = _transport.parseMapList(result, key: 'timesheets');
    if (filterToSingleDay != null) {
      return TimesheetOdooMappers.filterTimesheetRowsByWorkDate(
        rows,
        filterToSingleDay,
      );
    }
    return rows;
  }

  bool get _isCacheFresh {
    if (_cacheAt == null) return false;
    return DateTime.now().difference(_cacheAt!) < _cacheTtl;
  }

  void _touchCache() => _cacheAt = DateTime.now();

  List<TimesheetDayCountRow> _mockDayCounts(DateTime start, DateTime end) {
    final rows = <TimesheetDayCountRow>[];
    var cursor = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    while (!cursor.isAfter(endDay)) {
      rows.add(
        TimesheetDayCountRow(
          date: cursor,
          inProgress: 0,
          submitted: 0,
          approved: 0,
        ),
      );
      cursor = cursor.add(const Duration(days: 1));
    }
    return rows.reversed.toList();
  }

  Map<String, dynamic>? _unwrapOdooSuccessMap(Object? result) {
    if (result is! Map) return null;
    final outer = Map<String, dynamic>.from(result);
    if (outer['status']?.toString() == 'error') {
      throw TimesheetOdooException(
        outer['message']?.toString() ?? 'Odoo API error',
      );
    }
    if (outer['data'] is Map) {
      return Map<String, dynamic>.from(outer['data'] as Map);
    }
    return outer;
  }

  void clearCache() {
    _projectsCache = null;
    _projectAccessRows = null;
    _tasksCache = null;
    _employeesCache = null;
    _hrScopeCache = null;
    _cachedProjectsRole = null;
    _cacheAt = null;
  }

  static String _formatDate(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  // ---------------------------------------------------------------------------
  // Envelope helpers
  // ---------------------------------------------------------------------------

  TimesheetApiEnvelope<T> _ok<T>(T data) {
    return TimesheetApiEnvelope(
      success: true,
      data: data,
      error: null,
      uiStatus: 'OK',
    );
  }

  TimesheetApiEnvelope<T> _handleError<T>(
    String label,
    Object error,
    StackTrace stack, {
    required T Function() fallback,
  }) {
    debugPrint('TimesheetApiClient.$label failed: $error\n$stack');
    if (fallbackToMockOnError) {
      return _ok(fallback());
    }
    return TimesheetApiEnvelope(
      success: false,
      data: null,
      error: error.toString(),
      uiStatus: 'ERROR',
    );
  }

  // ---------------------------------------------------------------------------
  // Mock data (Phase 1 fallback / offline)
  // ---------------------------------------------------------------------------

  List<Project> _mockProjects({required bool hrWideScope}) {
    return [
      Project.fromJson({
        'id': 'p_midtown',
        'name': 'Midtown Tower Project',
        'code': 'MT-001',
        'client': 'Pandora Developments',
        'start': '2026-05-01',
        'end': '2026-12-30',
        'status': 'IN_PROGRESS',
        'address': '810 Grand Ave, NW York',
        'hero_image_url': '',
        'progress_pct': 56,
        'budget_min': 1200000,
        'budget_max': 2500000,
        'geofence_lat': 25.2048,
        'geofence_lon': 55.2708,
        'geofence_radius_m': 120,
        'pm_id': 'pm_001',
        'foreman_ids': ['fm_001'],
        'chat_room_id': 'project_p_midtown',
      }),
      if (hrWideScope)
        Project.fromJson({
          'id': 'p_harbor',
          'name': 'Harbor Fitout Works',
          'code': 'HF-014',
          'client': 'Harbor Group',
          'start': '2026-04-15',
          'end': '2026-09-10',
          'status': 'PLANNED',
          'address': 'Dubai Harbor Site B',
          'hero_image_url': '',
          'progress_pct': 18,
          'budget_min': 800000,
          'budget_max': 1400000,
          'geofence_lat': 25.0896,
          'geofence_lon': 55.1479,
          'geofence_radius_m': 100,
          'pm_id': 'pm_002',
          'foreman_ids': ['fm_002'],
          'chat_room_id': 'project_p_harbor',
        }),
    ];
  }

  List<Task> _mockTasks() {
    return [
      Task.fromJson({
        'id': 't_inspection',
        'project_id': 'p_midtown',
        'name': "Site's Inspection",
        'description': 'Daily site safety and progress inspection.',
        'planned_start': '2026-05-11T10:00:00',
        'planned_end': '2026-05-11T12:00:00',
        'status': 'IN_PROGRESS',
        'percent_complete': 64,
        'assigned_foreman_id': 'fm_001',
        'worker_ids': ['emp_101', 'emp_102'],
      }),
      Task.fromJson({
        'id': 't_concrete',
        'project_id': 'p_midtown',
        'name': 'Concrete Pouring',
        'description': 'Pour foundation concrete sections A1-A4.',
        'planned_start': '2026-05-11T13:00:00',
        'planned_end': '2026-05-11T18:00:00',
        'status': 'PLANNED',
        'percent_complete': 20,
        'assigned_foreman_id': 'fm_001',
        'worker_ids': ['emp_101', 'emp_103'],
      }),
    ];
  }

  List<Worker> _mockWorkers() {
    return [
      Worker.fromJson({
        'id': 'emp_101',
        'project_id': 'p_midtown',
        'name': 'Ahmed Khan',
        'trade': 'Concrete Foreman',
        'contact': '+971 50 111 2222',
        'hourly_rate': 45,
        'status': 'ACTIVE',
        'face_id': 'mock_face_w_ahmed',
        'ref_photo_urls': const [],
        'odoo_employee_id': 101,
      }),
      Worker.fromJson({
        'id': 'emp_102',
        'project_id': 'p_midtown',
        'name': 'Bilal Ali',
        'trade': 'Concrete Worker',
        'contact': '+971 50 333 4444',
        'hourly_rate': 25,
        'status': 'ACTIVE',
        'face_id': 'mock_face_w_bilal',
        'ref_photo_urls': const [],
        'odoo_employee_id': 102,
      }),
      Worker.fromJson({
        'id': 'emp_103',
        'project_id': 'p_midtown',
        'name': 'Carlos Rodriguez',
        'trade': 'Crane Operator',
        'contact': '+971 50 555 6666',
        'hourly_rate': 35,
        'status': 'ACTIVE',
        'face_id': 'mock_face_w_carlos',
        'ref_photo_urls': const [],
        'odoo_employee_id': 103,
      }),
    ];
  }

  List<AttendanceRecord> _mockAttendance({
    required String projectId,
    required DateTime date,
  }) {
    return [
      AttendanceRecord.fromJson({
        'id': 'att_${projectId}_${date.toIso8601String()}_1',
        'project_id': projectId,
        'task_id': 't_inspection',
        'worker_id': 'emp_101',
        'foreman_id': 'fm_001',
        'event': 'checkIn',
        'timestamp': date.toIso8601String(),
        'lat': 25.2048,
        'lon': 55.2708,
        'gps_accuracy_m': 12,
        'similarity': 97.4,
        'audit_photo_url': '',
        'outside_geofence': false,
        'manual_override': false,
        'device_id': 'mock_device',
        'sync_state': 'synced',
      }),
    ];
  }
}
