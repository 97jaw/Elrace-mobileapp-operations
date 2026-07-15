import 'package:el_race/core/purchase/purchase_access.dart';
import 'package:el_race/core/purchase/purchase_dev_role_provider.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_models.dart';
import 'package:el_race/ui/presentation/purchase_management/data/purchase_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final purchaseRepositoryProvider = Provider<PurchaseRepository>(
  (_) => PurchaseRepository(),
);

final purchaseOverviewProvider =
    FutureProvider.autoDispose<PurchaseOverview>((ref) async {
  ref.watch(purchaseDevRoleOverrideProvider);
  final repo = ref.read(purchaseRepositoryProvider);
  final testRole = ref.read(purchaseDevRoleOverrideProvider);
  return repo.fetchOverview(testRole: testRole);
});

/// Login-cache access, upgraded from live `/purchase/overview` when management
/// users still have stale `purchase_scope=none` after a backend deploy.
final purchaseAccessProvider = Provider<PurchaseAccess>((ref) {
  final data = SharedPref.getLoginData().result?.data;
  final base = purchaseAccessFromData(data);
  if (kDebugMode) {
    final override = ref.watch(purchaseDevRoleOverrideProvider);
    if (override != null) {
      return purchaseAccessForDevRole(override);
    }
  }

  final overview = ref.watch(purchaseOverviewProvider).asData?.value;
  if (overview != null &&
      overview.isAuthorized &&
      overview.scope != 'none' &&
      (!base.hasAnyAccess ||
          (overview.scope == 'all' && !base.isCostControlOrManagement))) {
    return PurchaseAccess(
      isPurchaseRep: base.isPurchaseRep,
      isPurchaseManager: true,
      isCostControlOrManagement:
          overview.scope == 'all' || base.isCostControlOrManagement,
      isDocController: base.isDocController,
      scope: overview.scope,
    );
  }
  return base;
});

final purchaseOverviewFullProvider =
    FutureProvider.autoDispose<PurchaseOverview>((ref) async {
  ref.watch(purchaseDevRoleOverrideProvider);
  final repo = ref.read(purchaseRepositoryProvider);
  final testRole = ref.read(purchaseDevRoleOverrideProvider);
  return repo.fetchOverview(testRole: testRole, mobile: false);
});

final mrDetailProvider =
    FutureProvider.autoDispose.family<MrDetail?, int>((ref, mrId) async {
  final repo = ref.read(purchaseRepositoryProvider);
  final testRole = ref.read(purchaseDevRoleOverrideProvider);
  return repo.fetchRequisitionDetails(mrId, testRole: testRole);
});

final draftInvoicesPreviewProvider =
    FutureProvider.autoDispose<DraftInvoicesPreview>((ref) async {
  ref.watch(purchaseDevRoleOverrideProvider);
  final repo = ref.read(purchaseRepositoryProvider);
  final testRole = ref.read(purchaseDevRoleOverrideProvider);
  return repo.fetchDraftInvoicesPreview(testRole: testRole);
});

/// Latest LPOs for the purchase hub preview section.
final lpoLatestPreviewProvider =
    FutureProvider.autoDispose<List<RfqItem>>((ref) async {
  ref.watch(purchaseDevRoleOverrideProvider);
  final repo = ref.read(purchaseRepositoryProvider);
  final testRole = ref.read(purchaseDevRoleOverrideProvider);
  final result = await repo.fetchRfqs(
    page: 1,
    limit: 5,
    status: '',
    orderDesc: true,
    testRole: testRole,
  );
  return result.items;
});

final invoiceDetailProvider =
    FutureProvider.autoDispose
        .family<InvoiceReceivingDetail?, int>((ref, invoiceId) async {
  ref.watch(purchaseDevRoleOverrideProvider);
  final repo = ref.read(purchaseRepositoryProvider);
  final testRole = ref.read(purchaseDevRoleOverrideProvider);
  return repo.fetchInvoiceReceivingDetails(invoiceId, testRole: testRole);
});
