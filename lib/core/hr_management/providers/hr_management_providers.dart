import 'package:dio/dio.dart';
import 'package:el_race/core/hr_management/hr_effective_view.dart';
import 'package:el_race/core/hr_management/hr_dashboard_local.dart';
import 'package:el_race/core/hr_management/models/hr_dashboard_data.dart';
import 'package:el_race/core/hr_management/models/hr_request_detail.dart';
import 'package:el_race/core/hr_management/models/hr_request_summary.dart';
import 'package:el_race/core/hr_management/network/hr_api_client.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bumped after login persistence or logout so Riverpod re-reads [SharedPref] login
/// snapshot (otherwise [hrEffectiveViewProvider] stays cached for the previous user).
class LoginSessionRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final loginSessionRevisionProvider =
    NotifierProvider<LoginSessionRevision, int>(LoginSessionRevision.new);

void bumpLoginSessionRiverpod(ProviderContainer container) {
  try {
    container.read(loginSessionRevisionProvider.notifier).bump();
  } catch (_) {}
}

/// Dio for HR module — Bearer token from login (same as Postman / rest of app).
final hrDioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://erp.elrace.com',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = SharedPref.getLoginDataOrNull()?.result?.token;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ),
  );

  return dio;
});

final hrApiClientProvider = Provider<HrApiClient>((ref) {
  ref.watch(loginSessionRevisionProvider);
  return HrApiClient(ref.watch(hrDioProvider), useMock: false);
});

/// Dev-only session override — TASKS F.4 / SRD §1.4 dev note.
final hrDevViewOverrideProvider =
    NotifierProvider<HrDevViewOverrideNotifier, HrEffectiveView?>(
  HrDevViewOverrideNotifier.new,
);

class HrDevViewOverrideNotifier extends Notifier<HrEffectiveView?> {
  @override
  HrEffectiveView? build() => null;

  void setOverride(HrEffectiveView? view) => state = view;
}

/// Effective view after applying dev override over login flags.
final hrEffectiveViewProvider = Provider<HrEffectiveView>((ref) {
  ref.watch(loginSessionRevisionProvider);
  final override = ref.watch(hrDevViewOverrideProvider);
  if (override != null) return override;
  return hrEffectiveViewFromLoginPref();
});

final hrRequestListProvider =
    AsyncNotifierProvider<HrRequestListNotifier, List<HrRequestSummary>>(
  HrRequestListNotifier.new,
);

class HrRequestListNotifier extends AsyncNotifier<List<HrRequestSummary>> {
  @override
  Future<List<HrRequestSummary>> build() async {
    ref.watch(loginSessionRevisionProvider);
    final client = ref.watch(hrApiClientProvider);
    final env = await client.fetchMyRequests();
    if (env.success && env.data != null) {
      return env.data!.map(HrRequestSummary.fromJson).toList();
    }
    throw Exception(env.error ?? 'Could not load my requests');
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final client = ref.read(hrApiClientProvider);
      final env = await client.fetchMyRequests();
      if (env.success && env.data != null) {
        return env.data!.map(HrRequestSummary.fromJson).toList();
      }
      throw Exception(env.error ?? 'Could not load my requests');
    });
  }
}

/// Dashboard period keys: week | month | last_month | quarter | year
String hrDashboardPeriodFromIndex(int index) {
  switch (index) {
    case 0:
      return 'week';
    case 1:
      return 'month';
    case 2:
      return 'last_month';
    case 3:
      return 'quarter';
    case 4:
      return 'year';
    default:
      return 'month';
  }
}

final hrTeamKpisProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  ref.watch(loginSessionRevisionProvider);
  final client = ref.watch(hrApiClientProvider);
  final env = await client.fetchTeamKpis(period: 'month');
  if (env.success && env.data != null) {
    final d = env.data!;
    return {
      'pending': (d['pending'] as num?)?.toInt() ?? 0,
      'approved': (d['approved'] as num?)?.toInt() ?? 0,
      'total': (d['total'] as num?)?.toInt() ?? 0,
    };
  }
  throw Exception(env.error ?? 'Could not load KPIs');
});

final hrDashboardProvider = FutureProvider.autoDispose
    .family<HrDashboardData, String>((ref, period) async {
  ref.watch(loginSessionRevisionProvider);
  final client = ref.watch(hrApiClientProvider);

  final env = await client.fetchDashboard(period: period);
  if (env.success && env.data != null) {
    return HrDashboardData.fromJson(env.data!);
  }

  final team = await client.fetchTeamRequests(status: 'all', limit: 500);
  if (team.success && team.data != null) {
    return buildLocalDashboardFromTeamRows(team.data!);
  }
  throw Exception(team.error ?? 'Could not load dashboard');
});

final hrTeamRequestListProvider =
    AsyncNotifierProvider<HrTeamRequestListNotifier, List<HrRequestSummary>>(
  HrTeamRequestListNotifier.new,
);

class HrTeamRequestListNotifier extends AsyncNotifier<List<HrRequestSummary>> {
  @override
  Future<List<HrRequestSummary>> build() async {
    ref.watch(loginSessionRevisionProvider);
    final client = ref.watch(hrApiClientProvider);
    final env = await client.fetchTeamRequests();
    if (env.success && env.data != null) {
      return env.data!.map(HrRequestSummary.fromJson).toList();
    }
    throw Exception(env.error ?? 'Could not load team requests');
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final client = ref.read(hrApiClientProvider);
      final env = await client.fetchTeamRequests();
      if (env.success && env.data != null) {
        return env.data!.map(HrRequestSummary.fromJson).toList();
      }
      throw Exception(env.error ?? 'Could not load team requests');
    });
  }
}

/// Legacy mock detail provider — unused; HR Management opens [HrDetailsScreen] instead.
@Deprecated('Use openHrRequestDetail → HrDetailsScreen')
final hrRequestDetailProvider = FutureProvider.autoDispose
    .family<HrRequestDetail, HrDetailQuery>((ref, q) async {
  throw UnsupportedError(
    'HR detail uses HrDetailsScreen and /api/get_hr_request_details',
  );
});
