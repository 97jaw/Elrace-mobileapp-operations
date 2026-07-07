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

final purchaseAccessProvider = Provider<PurchaseAccess>((ref) {
  final data = SharedPref.getLoginData().result?.data;
  final base = purchaseAccessFromData(data);
  if (kDebugMode) {
    final override = ref.watch(purchaseDevRoleOverrideProvider);
    if (override != null) {
      return purchaseAccessForDevRole(override);
    }
  }
  return base;
});

final purchaseOverviewProvider =
    FutureProvider.autoDispose<PurchaseOverview>((ref) async {
  ref.watch(purchaseDevRoleOverrideProvider);
  final repo = ref.read(purchaseRepositoryProvider);
  final testRole = ref.read(purchaseDevRoleOverrideProvider);
  return repo.fetchOverview(testRole: testRole);
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

final invoiceDetailProvider =
    FutureProvider.autoDispose
        .family<InvoiceReceivingDetail?, int>((ref, invoiceId) async {
  ref.watch(purchaseDevRoleOverrideProvider);
  final repo = ref.read(purchaseRepositoryProvider);
  final testRole = ref.read(purchaseDevRoleOverrideProvider);
  return repo.fetchInvoiceReceivingDetails(invoiceId, testRole: testRole);
});
