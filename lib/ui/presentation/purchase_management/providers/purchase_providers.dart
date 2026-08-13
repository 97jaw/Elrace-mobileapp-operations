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
  // Always bypass client/server stale empty snapshots when opening the hub.
  return repo.fetchOverview(testRole: testRole, refresh: true);
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

/// Recent vendor bills preview for the purchase hub (all states, newest first).
final recentInvoicesPreviewProvider =
    FutureProvider.autoDispose<DraftInvoicesPreview>((ref) async {
  ref.watch(purchaseDevRoleOverrideProvider);
  final repo = ref.read(purchaseRepositoryProvider);
  final testRole = ref.read(purchaseDevRoleOverrideProvider);
  // Always refresh so we never keep a draft-only / tier-review stale cache.
  return repo.fetchInvoicesPreview(
    testRole: testRole,
    limit: 5,
    refresh: true,
  );
});

/// Legacy alias for [recentInvoicesPreviewProvider].
final draftInvoicesPreviewProvider = recentInvoicesPreviewProvider;

/// Latest confirmed LPOs (purchase/done) — kept for LPO hub use if needed.
final lpoLatestPreviewProvider =
    FutureProvider.autoDispose<List<RfqItem>>((ref) async {
  ref.watch(purchaseDevRoleOverrideProvider);
  final repo = ref.read(purchaseRepositoryProvider);
  final testRole = ref.read(purchaseDevRoleOverrideProvider);
  final result = await repo.fetchRfqs(
    page: 1,
    limit: 5,
    status: 'LPOS',
    orderDesc: true,
    testRole: testRole,
  );
  return result.items;
});

/// Invoice Receiving detail (invoice.receiving model).
final invoiceDetailProvider =
    FutureProvider.autoDispose
        .family<InvoiceReceivingDetail?, int>((ref, invoiceId) async {
  ref.watch(purchaseDevRoleOverrideProvider);
  final repo = ref.read(purchaseRepositoryProvider);
  final testRole = ref.read(purchaseDevRoleOverrideProvider);
  return repo.fetchInvoiceReceivingDetails(invoiceId, testRole: testRole);
});

/// Vendor bill (account.move) detail with payments for hub sheet.
final purchaseInvoiceDetailProvider = FutureProvider.autoDispose
    .family<PurchaseInvoiceDetail?, int>((ref, invoiceId) async {
  ref.watch(purchaseDevRoleOverrideProvider);
  final repo = ref.read(purchaseRepositoryProvider);
  final testRole = ref.read(purchaseDevRoleOverrideProvider);
  return repo.fetchInvoiceDetails(invoiceId, testRole: testRole);
});
