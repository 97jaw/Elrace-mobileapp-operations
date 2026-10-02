import 'package:el_race/core/access/feature_access.dart';
import 'package:el_race/core/hr_management/hr_effective_view.dart';
import 'package:el_race/core/hr_management/hr_module_manager_access.dart';
import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/core/performance/models/performance_employee_option.dart';
import 'package:el_race/core/performance/models/performance_evaluation.dart';
import 'package:el_race/core/performance/network/performance_api_client.dart';
import 'package:el_race/core/performance/performance_json_parsers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True when login role has x_is_management or x_evaluation (team list APIs).
final performanceManagerModeProvider = Provider<bool>((ref) {
  ref.watch(loginSessionRevisionProvider);
  final data = SharedPref.getLoginData().result?.data;
  if (data == null) return false;
  if (hrServerManagerForModule(data, HrManagedModule.evaluation)) {
    return true;
  }
  final codes = FeatureAccess.codesOf(data);
  if (codes != null) return codes.contains(AppFeature.hrPerformanceManager);
  final caps = data.roleCapabilities;
  if (caps != null) {
    final mgmt = caps['x_is_management'] == true;
    final eval = caps['x_evaluation'] == true;
    if (mgmt || eval) return true;
  }
  return data.isManagement == true;
});

final performanceApiClientProvider = Provider<PerformanceApiClient>((ref) {
  ref.watch(loginSessionRevisionProvider);
  return PerformanceApiClient(ref.watch(hrDioProvider));
});

final performancePlanningProvider =
    FutureProvider.autoDispose<PerformancePlanningInfo>((ref) async {
  ref.watch(loginSessionRevisionProvider);
  final client = ref.watch(performanceApiClientProvider);
  final env = await client.fetchPlanning();
  if (env.success && env.data != null) {
    return planningFromJson(env.data!);
  }
  throw Exception(env.error ?? 'Could not load planning info');
});

final performanceEvaluationListProvider =
    AsyncNotifierProvider<PerformanceEvaluationListNotifier, List<PerformanceEvaluationSummary>>(
  PerformanceEvaluationListNotifier.new,
);

class PerformanceEvaluationListNotifier
    extends AsyncNotifier<List<PerformanceEvaluationSummary>> {
  /// Server caps each page at 30 rows.
  static const _pageSize = 30;

  int _page = 1;
  bool _hasMore = false;
  bool _loadingMore = false;

  bool get hasMore => _hasMore;

  @override
  Future<List<PerformanceEvaluationSummary>> build() async {
    ref.watch(loginSessionRevisionProvider);
    return _firstPage(ref.watch(performanceApiClientProvider));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _firstPage(ref.read(performanceApiClientProvider)),
    );
  }

  /// Appends the next page; no-op while loading or when nothing is left.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !_hasMore || _loadingMore) return;
    _loadingMore = true;
    try {
      final next = await _fetchPage(
        ref.read(performanceApiClientProvider),
        _page + 1,
      );
      _page++;
      state = AsyncData([...current, ...next]);
    } catch (_) {
      // Keep the rows already shown; scrolling again retries.
    } finally {
      _loadingMore = false;
    }
  }

  Future<List<PerformanceEvaluationSummary>> _firstPage(
    PerformanceApiClient client,
  ) async {
    _page = 1;
    _hasMore = false;
    return _fetchPage(client, 1);
  }

  Future<List<PerformanceEvaluationSummary>> _fetchPage(
    PerformanceApiClient client,
    int page,
  ) async {
    final env = await client.fetchEvaluations(page: page, limit: _pageSize);
    if (!env.success || env.data == null) {
      throw Exception(env.error ?? 'Could not load evaluations');
    }
    _hasMore = env.data!.length >= _pageSize;
    return env.data!.map(summaryFromJson).toList();
  }
}

final performanceEvaluationDetailProvider =
    FutureProvider.family<PerformanceEvaluationDetail?, String>((ref, id) async {
  ref.watch(loginSessionRevisionProvider);
  final client = ref.watch(performanceApiClientProvider);
  final env = await client.fetchEvaluationDetail(id);
  if (env.success && env.data != null) {
    return detailFromJson(env.data!);
  }
  if (env.success && env.data == null) return null;
  throw Exception(env.error ?? 'Could not load evaluation');
});

final employeePerformanceYearProvider =
    NotifierProvider<EmployeePerformanceYearNotifier, int>(
  EmployeePerformanceYearNotifier.new,
);

class EmployeePerformanceYearNotifier extends Notifier<int> {
  @override
  int build() => DateTime.now().year;

  void setYear(int year) => state = year;
}

final myPerformanceEvaluationProvider =
    FutureProvider.family<PerformanceEvaluationDetail?, int>((ref, year) async {
  ref.watch(loginSessionRevisionProvider);
  final client = ref.watch(performanceApiClientProvider);
  final env = await client.fetchMyEvaluation(year);
  if (env.success) {
    if (env.data == null) return null;
    return detailFromJson(env.data!);
  }
  throw Exception(env.error ?? 'Could not load evaluation');
});

final performanceEmployeeOptionsProvider =
    FutureProvider.autoDispose<List<PerformanceEmployeeOption>>((ref) async {
  ref.watch(loginSessionRevisionProvider);
  final client = ref.watch(performanceApiClientProvider);
  final env = await client.fetchEmployees();
  if (env.success && env.data != null) {
    return env.data!.map(employeeOptionFromJson).toList();
  }
  throw Exception(env.error ?? 'Could not load employees');
});
