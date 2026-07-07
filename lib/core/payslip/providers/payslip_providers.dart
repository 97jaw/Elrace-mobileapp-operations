import 'package:el_race/core/hr_management/hr_effective_view.dart';
import 'package:el_race/core/hr_management/hr_module_manager_access.dart';
import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/payslip/models/payslip_models.dart';
import 'package:el_race/core/payslip/network/payslip_api_client.dart';
import 'package:el_race/core/payslip/payslip_json_parsers.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// HR payslip team access — login `hr_module_manager.payslip` (supervisor / management).
final payslipHrAccessProvider = Provider<bool>((ref) {
  ref.watch(loginSessionRevisionProvider);
  final data = SharedPref.getLoginData().result?.data;
  if (data == null) return false;
  return hrServerManagerForModule(data, HrManagedModule.payslip);
});

final payslipApiClientProvider = Provider<PayslipApiClient>((ref) {
  ref.watch(loginSessionRevisionProvider);
  return PayslipApiClient(ref.watch(hrDioProvider));
});

final payslipRecordProvider =
    FutureProvider.autoDispose.family<PayslipRecord?, String>((ref, id) async {
  ref.watch(loginSessionRevisionProvider);
  final client = ref.watch(payslipApiClientProvider);
  final env = await client.fetchPayslipDetail(id);
  if (env.success && env.data != null) {
    return recordFromJson(env.data!);
  }
  throw Exception(env.error ?? 'Could not load payslip');
});

final payslipEmployeeFilterMonthProvider = NotifierProvider<
    PayslipEmployeeFilterMonthNotifier, DateTime>(
  PayslipEmployeeFilterMonthNotifier.new,
);

class PayslipEmployeeFilterMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, 1);
  }

  void setMonth(DateTime firstDayOfMonth) =>
      state = DateTime(firstDayOfMonth.year, firstDayOfMonth.month, 1);
}

final payslipListProvider =
    AsyncNotifierProvider<PayslipListNotifier, List<PayslipSummary>>(
  PayslipListNotifier.new,
);

class PayslipListNotifier extends AsyncNotifier<List<PayslipSummary>> {
  int _page = 1;
  static const _pageSize = 30;
  int? _filterYear;
  int? _filterMonth;
  String? _keyword;

  @override
  Future<List<PayslipSummary>> build() async {
    ref.watch(loginSessionRevisionProvider);
    _page = 1;
    return _fetch(page: 1, append: false);
  }

  Future<void> setFilters({int? year, int? month, String? keyword}) async {
    _filterYear = year;
    _filterMonth = month;
    _keyword = keyword;
    _page = 1;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetch(page: 1, append: false),
    );
  }

  Future<void> loadMore() async {
    final current = _currentList;
    final next = _page + 1;
    final more = await _fetch(page: next, append: true);
    if (more.length <= current.length) return;
    _page = next;
    state = AsyncData(more);
  }

  List<PayslipSummary> get _currentList => state.when(
        data: (list) => list,
        loading: () => const <PayslipSummary>[],
        error: (_, __) => const <PayslipSummary>[],
      );

  Future<void> refresh() async {
    _page = 1;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetch(page: 1, append: false),
    );
  }

  Future<List<PayslipSummary>> _fetch({
    required int page,
    required bool append,
  }) async {
    final client = ref.read(payslipApiClientProvider);
    final env = await client.fetchPayslips(
      page: page,
      limit: _pageSize,
      year: _filterYear,
      month: _filterMonth,
      keyword: _keyword,
    );
    if (!env.success || env.data == null) {
      throw Exception(env.error ?? 'Could not load payslips');
    }
    final batch = env.data!.map(summaryFromJson).toList();
    if (!append || page == 1) return batch;
    final prev = _currentList;
    final ids = prev.map((e) => e.id).toSet();
    return [...prev, ...batch.where((e) => !ids.contains(e.id))];
  }
}

/// Payslip for the employee's selected filter month.
final payslipEmployeeMonthProvider =
    FutureProvider.autoDispose<List<PayslipSummary>>((ref) async {
  ref.watch(loginSessionRevisionProvider);
  final filter = ref.watch(payslipEmployeeFilterMonthProvider);
  final client = ref.watch(payslipApiClientProvider);
  final env = await client.fetchPayslips(
    page: 1,
    limit: 5,
    year: filter.year,
    month: filter.month,
  );
  if (env.success && env.data != null) {
    return env.data!.map(summaryFromJson).toList();
  }
  throw Exception(env.error ?? 'Could not load payslips');
});

/// Last five pay periods (no month filter).
final payslipEmployeeRecentProvider =
    FutureProvider.autoDispose<List<PayslipSummary>>((ref) async {
  ref.watch(loginSessionRevisionProvider);
  final client = ref.watch(payslipApiClientProvider);
  final env = await client.fetchPayslips(page: 1, limit: 5);
  if (env.success && env.data != null) {
    return env.data!.map(summaryFromJson).toList();
  }
  throw Exception(env.error ?? 'Could not load payslips');
});

/// Last 24 months for employee month filter dropdown.
List<DateTime> payslipMonthFilterOptions() {
  final now = DateTime.now();
  return List.generate(24, (i) {
    final m = DateTime(now.year, now.month - i, 1);
    return DateTime(m.year, m.month, 1);
  });
}
