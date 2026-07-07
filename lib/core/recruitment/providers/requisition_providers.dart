import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/recruitment/models/recruitment_entities.dart';
import 'package:el_race/core/recruitment/models/requisition.dart';
import 'package:el_race/core/recruitment/network/recruitment_api_client.dart';
import 'package:el_race/core/recruitment/recruitment_json_parsers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final recruitmentApiClientProvider = Provider<RecruitmentApiClient>((ref) {
  ref.watch(loginSessionRevisionProvider);
  return RecruitmentApiClient(ref.watch(hrDioProvider), useMock: false);
});

final requisitionsListProvider =
    AsyncNotifierProvider<RequisitionsListNotifier, List<Requisition>>(
  RequisitionsListNotifier.new,
);

class RequisitionsListNotifier extends AsyncNotifier<List<Requisition>> {
  @override
  Future<List<Requisition>> build() async {
    ref.watch(loginSessionRevisionProvider);
    final client = ref.watch(recruitmentApiClientProvider);
    final env = await client.fetchRequisitions();
    if (env.success && env.data != null) {
      return env.data!.map(requisitionFromJson).toList();
    }
    throw Exception(env.error ?? 'Could not load requisitions');
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final client = ref.read(recruitmentApiClientProvider);
      final env = await client.fetchRequisitions();
      if (env.success && env.data != null) {
        return env.data!.map(requisitionFromJson).toList();
      }
      throw Exception(env.error ?? 'Could not load requisitions');
    });
  }
}

final recruitmentKpisProvider =
    FutureProvider.autoDispose<Map<String, int>>((ref) async {
  ref.watch(loginSessionRevisionProvider);
  final client = ref.watch(recruitmentApiClientProvider);
  final env = await client.fetchKpis();
  if (env.success && env.data != null) {
    final d = env.data!;
    return {
      'open': (d['open'] as num?)?.toInt() ?? 0,
      'pipeline': (d['pipeline'] as num?)?.toInt() ?? 0,
      'offers': (d['offers'] as num?)?.toInt() ?? 0,
    };
  }
  throw Exception(env.error ?? 'Could not load KPIs');
});

final recruitmentDashboardProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(loginSessionRevisionProvider);
  final client = ref.watch(recruitmentApiClientProvider);
  final env = await client.fetchDashboard();
  if (env.success && env.data != null) {
    return env.data!;
  }
  throw Exception(env.error ?? 'Could not load dashboard');
});

final requisitionDetailProvider =
    FutureProvider.family<RequisitionDetailModel, String>((ref, id) async {
  ref.watch(loginSessionRevisionProvider);
  final client = ref.watch(recruitmentApiClientProvider);
  final env = await client.fetchRequisitionDetail(id);
  if (env.success && env.data != null) {
    return requisitionDetailFromJson(env.data!);
  }
  throw Exception(env.error ?? 'Could not load requisition');
});

final allRecruitmentCandidatesProvider =
    FutureProvider<List<RecruitmentCandidate>>((ref) async {
  ref.watch(loginSessionRevisionProvider);
  final client = ref.watch(recruitmentApiClientProvider);
  final env = await client.fetchCandidates();
  if (env.success && env.data != null) {
    return env.data!.map(candidateFromJson).toList();
  }
  throw Exception(env.error ?? 'Could not load candidates');
});

final recruitmentCandidateProvider =
    FutureProvider.family<RecruitmentCandidate, String>((ref, id) async {
  ref.watch(loginSessionRevisionProvider);
  final client = ref.watch(recruitmentApiClientProvider);
  final env = await client.fetchCandidateDetail(id);
  if (env.success && env.data != null) {
    return candidateFromJson(env.data!);
  }
  throw Exception(env.error ?? 'Could not load candidate');
});

final recruitmentAssessmentDetailProvider =
    FutureProvider.family<RecruitmentAssessmentDetail, String>((ref, id) async {
  ref.watch(loginSessionRevisionProvider);
  final client = ref.watch(recruitmentApiClientProvider);
  final env = await client.fetchAssessmentDetail(id);
  if (env.success && env.data != null) {
    return assessmentDetailFromJson(env.data!);
  }
  throw Exception(env.error ?? 'Could not load assessment');
});

final recruitmentOfferDetailProvider =
    FutureProvider.family<RecruitmentOfferDetail, String>((ref, id) async {
  ref.watch(loginSessionRevisionProvider);
  final client = ref.watch(recruitmentApiClientProvider);
  final env = await client.fetchOfferDetail(id);
  if (env.success && env.data != null) {
    return offerDetailFromJson(env.data!);
  }
  throw Exception(env.error ?? 'Could not load offer');
});
