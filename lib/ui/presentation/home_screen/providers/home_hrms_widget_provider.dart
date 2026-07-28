import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_widget_api_client.dart';
import 'package:el_race/ui/presentation/home_screen/providers/home_widget_session_cache.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeHrmsWidgetData {
  const HomeHrmsWidgetData({
    required this.isManagerScope,
    required this.headlineCount,
    required this.headlineLabel,
    required this.trendLabel,
    required this.departmentName,
    required this.sectionName,
    required this.pendingRequests,
  });

  final bool isManagerScope;
  final int headlineCount;
  final String headlineLabel;
  final String trendLabel;
  final String? departmentName;
  final String? sectionName;
  final int pendingRequests;

  static HomeHrmsWidgetData? fromLoginCache() {
    final record = SharedPref.getLoginData()
        .result
        ?.data
        ?.defaultWidgets
        ?.data
        ?.hrmsWidget
        ?.hrmsRecord;
    if (record != null) return _fromHrmsRecord(record);

    // Pre-deploy login: pending + my_request only (no network).
    final login = SharedPref.getLoginDataOrNull()?.result?.data;
    final pending = _readInt(login
        ?.defaultWidgets
        ?.data
        ?.myRequestWidget
        ?.recordMap?['waiting_for_approval_count']);
    if (pending <= 0) return null;

    return HomeHrmsWidgetData(
      isManagerScope: false,
      headlineCount: pending,
      headlineLabel: 'REQUESTS',
      trendLabel: pending == 1 ? '1 pending request' : '$pending pending requests',
      departmentName: null,
      sectionName: null,
      pendingRequests: pending,
    );
  }

  static HomeHrmsWidgetData? fromApiMap(Map<String, dynamic> map) {
    final scope = map['scope']?.toString() ?? 'employee';
    final isManagement = scope == 'management';
    final isManager = scope == 'manager';
    final isManagerScope = isManagement || isManager;
    final direct = _readInt(map['direct_reports_count']);
    final allStaff = _readInt(map['all_staff_count']);
    final pending = _readInt(map['pending_requests_count']);
    final headlineRaw = _readInt(map['headline_count']);

    // Foreman / employee: never surface company headcount on the home card.
    final login = SharedPref.getLoginDataOrNull()?.result?.data;
    final isForeman = login?.isForeman == true ||
        (login?.roleCapabilities?['x_is_foreman'] == true);
    final isManagementUser = login?.isManagement == true ||
        (login?.roleCapabilities?['x_is_management'] == true);
    final forceEmployeeScope = isForeman && !isManagementUser;

    final headline = forceEmployeeScope
        ? pending
        : (headlineRaw > 0
            ? headlineRaw
            : (isManagement
                ? (allStaff > 0 ? allStaff : direct)
                : (isManager ? direct : pending)));

    final label = (isManagement || (isManager && !forceEmployeeScope))
        ? 'EMPLOYEES'
        : 'REQUESTS';

    return HomeHrmsWidgetData(
      isManagerScope: isManagerScope && !forceEmployeeScope,
      headlineCount: headline,
      headlineLabel: label,
      trendLabel: map['trend_label']?.toString() ??
          (forceEmployeeScope
              ? (pending == 1
                  ? '1 pending request'
                  : pending > 0
                      ? '$pending pending requests'
                      : 'No pending requests')
              : (isManagement
                  ? '$headline staff company-wide'
                  : (isManager
                      ? '$direct under your team'
                      : (pending == 1
                          ? '1 pending request'
                          : pending > 0
                              ? '$pending pending requests'
                              : 'No pending requests')))),
      departmentName: _stringOrNull(map['department_name']),
      sectionName: _stringOrNull(map['section_name']),
      pendingRequests: pending,
    );
  }

  static HomeHrmsWidgetData empty() => const HomeHrmsWidgetData(
        isManagerScope: false,
        headlineCount: 0,
        headlineLabel: 'REQUESTS',
        trendLabel: 'Workforce overview',
        departmentName: null,
        sectionName: null,
        pendingRequests: 0,
      );
}

final homeHrmsWidgetProvider =
    NotifierProvider<HomeHrmsWidgetNotifier, HomeHrmsWidgetData>(
  HomeHrmsWidgetNotifier.new,
);

class HomeHrmsWidgetNotifier extends Notifier<HomeHrmsWidgetData> {
  @override
  HomeHrmsWidgetData build() {
    ref.keepAlive();
    final instant = _instantData();
    Future.microtask(_refreshInBackground);
    return instant;
  }

  HomeHrmsWidgetData _instantData() {
    return HomeHrmsWidgetData.fromLoginCache() ??
        HomeWidgetSessionCache.hrmsRaw?.let(HomeHrmsWidgetData.fromApiMap) ??
        HomeHrmsWidgetData.empty();
  }

  Future<void> _refreshInBackground() async {
    await HomeWidgetApiClient.refreshIfStale(
      force: !HomeWidgetSessionCache.isFresh,
    );
    final raw = HomeWidgetSessionCache.hrmsRaw;
    if (raw == null) return;
    final fresh = HomeHrmsWidgetData.fromApiMap(raw);
    if (fresh == null) return;
    state = fresh;
  }
}

HomeHrmsWidgetData _fromHrmsRecord(HrmsWidgetRecord record) {
  final login = SharedPref.getLoginDataOrNull()?.result?.data;
  final isForeman = login?.isForeman == true ||
      (login?.roleCapabilities?['x_is_foreman'] == true);
  final isManagementUser = login?.isManagement == true ||
      (login?.roleCapabilities?['x_is_management'] == true);
  final forceEmployee = isForeman && !isManagementUser;
  // Login cache may still carry a headcount for foremen; never show it.
  if (forceEmployee || !record.isManagerScope) {
    final pending = record.pendingRequestsCount;
    return HomeHrmsWidgetData(
      isManagerScope: false,
      headlineCount: pending,
      headlineLabel: 'REQUESTS',
      trendLabel: pending == 1
          ? '1 pending request'
          : pending > 0
              ? '$pending pending requests'
              : (record.trendLabel.isNotEmpty
                  ? record.trendLabel
                  : 'No pending requests'),
      departmentName: record.departmentName,
      sectionName: record.sectionName,
      pendingRequests: pending,
    );
  }
  return HomeHrmsWidgetData(
    isManagerScope: record.isManagerScope,
    headlineCount: record.headlineCount,
    headlineLabel: 'EMPLOYEES',
    trendLabel: record.trendLabel,
    departmentName: record.departmentName,
    sectionName: record.sectionName,
    pendingRequests: record.pendingRequestsCount,
  );
}

extension _Let<T> on T {
  R? let<R>(R? Function(T value) fn) => fn(this);
}

String? _stringOrNull(dynamic value) {
  if (value == null || value == false) return null;
  final s = value.toString().trim();
  return s.isEmpty ? null : s;
}

int _readInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
