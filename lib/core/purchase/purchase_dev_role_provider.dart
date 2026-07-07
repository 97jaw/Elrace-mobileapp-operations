import 'package:el_race/core/purchase/purchase_access.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dev-only role simulation for Purchase Management (single test account).
enum PurchaseDevTestRole {
  officer,
  manager,
  management,
}

extension PurchaseDevTestRoleX on PurchaseDevTestRole {
  String get label => switch (this) {
        PurchaseDevTestRole.officer => 'Officer',
        PurchaseDevTestRole.manager => 'Manager',
        PurchaseDevTestRole.management => 'Management',
      };

  /// Sent to Odoo as `test_purchase_role` to apply matching record domains.
  String get apiValue => switch (this) {
        PurchaseDevTestRole.officer => 'officer',
        PurchaseDevTestRole.manager => 'manager',
        PurchaseDevTestRole.management => 'management',
      };
}

/// Debug-only override; cleared on reset. Also exposed for [PurchaseRepository].
final purchaseDevRoleOverrideProvider =
    NotifierProvider<PurchaseDevRoleOverrideNotifier, PurchaseDevTestRole?>(
  PurchaseDevRoleOverrideNotifier.new,
);

class PurchaseDevRoleOverrideNotifier extends Notifier<PurchaseDevTestRole?> {
  @override
  PurchaseDevTestRole? build() => null;

  void setOverride(PurchaseDevTestRole? role) => state = role;
}

/// Active test role param for API calls (debug builds only).
String? purchaseDevTestRoleApiParam(PurchaseDevTestRole? override) {
  if (!kDebugMode || override == null) return null;
  return override.apiValue;
}

PurchaseAccess purchaseAccessForDevRole(PurchaseDevTestRole role) {
  return switch (role) {
    PurchaseDevTestRole.officer => const PurchaseAccess(
        isPurchaseRep: true,
        isPurchaseManager: false,
        isCostControlOrManagement: false,
        isDocController: false,
        scope: 'own',
      ),
    PurchaseDevTestRole.manager => const PurchaseAccess(
        isPurchaseRep: false,
        isPurchaseManager: true,
        isCostControlOrManagement: false,
        isDocController: false,
        scope: 'department',
      ),
    PurchaseDevTestRole.management => const PurchaseAccess(
        isPurchaseRep: false,
        isPurchaseManager: true,
        isCostControlOrManagement: true,
        isDocController: false,
        scope: 'all',
      ),
  };
}
