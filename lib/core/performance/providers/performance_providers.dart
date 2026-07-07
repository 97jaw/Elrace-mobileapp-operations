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
  @override
  Future<List<PerformanceEvaluationSummary>> build() async {
    ref.watch(loginSessionRevisionProvider);
    final client = ref.watch(performanceApiClientProvider);
    final env = await client.fetchEvaluations();
    if (env.success && env.data != null) {
      return env.data!.map(summaryFromJson).toList();
    }
    throw Exception(env.error ?? 'Could not load evaluations');
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final client = ref.read(performanceApiClientProvider);
      final env = await client.fetchEvaluations();
      if (env.success && env.data != null) {
        return env.data!.map(summaryFromJson).toList();
      }
      throw Exception(env.error ?? 'Could not load evaluations');
    });
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
