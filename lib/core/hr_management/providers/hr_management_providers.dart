import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:el_race/core/hr_management/hr_effective_view.dart';
import 'package:el_race/core/hr_management/models/hr_request_detail.dart';
import 'package:el_race/core/hr_management/models/hr_request_summary.dart';
import 'package:el_race/core/hr_management/network/hr_api_client.dart';
import 'package:el_race/services/api_client.dart' show AuthInterceptor, AuthErrorInterceptor, RetryInterceptor;
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
  } catch (e) {
    // Per FIX_IMPLEMENTATION_PLAN.md Phase 6.2 — this file was touched by
    // Phase 4.3(3), so its swallowed errors get a minimum debugPrint rather
    // than staying silent.
    debugPrint('⚠️ [hr_management_providers] bumpLoginSessionRiverpod: swallowed $e');
  }
}

/// Dio for HR module — Bearer token from login (same as Postman / rest of app).
///
/// Kept as its own Dio (baseUrl without the /api suffix — HrApiClient's own
/// path constants already include a leading '/api/...') rather than pointed
/// at lib/services/api_client.dart's ApiClient, whose baseUrl already ends
/// in '/api/' and would double that prefix. What's shared instead: the same
/// AuthInterceptor/AuthErrorInterceptor/RetryInterceptor classes from
/// api_client.dart, replacing the bespoke auth-header InterceptorsWrapper
/// that used to live here — one source of truth for token attachment, 401
/// handling, and retry across both. Per FIX_IMPLEMENTATION_PLAN.md Phase
/// 4.3(3) — this is one of the providers backing Phase 3's project/
/// timesheet tabs.
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

  dio.interceptors.addAll([
    AuthInterceptor(),
    AuthErrorInterceptor(),
    RetryInterceptor(dio),
  ]);

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
