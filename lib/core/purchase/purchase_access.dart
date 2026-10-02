import 'package:el_race/core/access/feature_access.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';

/// Resolved Purchase Management access for the logged-in user.
///
/// Role-line booleans on Odoo `res.users.role` (OR across role lines):
///   `x_purchase_officer` — purchase user, non-manager (MR + RFQ, own scope)
///   `x_purchase_manager_role` — purchase manager (all tabs, department scope)
///   `x_is_management` — cost control / management (all tabs, company-wide)
///   `x_is_dc_role` — document controller (invoice receiving)
class PurchaseAccess {
  const PurchaseAccess({
    required this.isPurchaseRep,
    required this.isPurchaseManager,
    required this.isCostControlOrManagement,
    required this.isDocController,
    required this.scope,
    this.features,
  });

  final bool isPurchaseRep;
  final bool isPurchaseManager;
  final bool isCostControlOrManagement;
  final bool isDocController;

  /// "own" | "department" | "all" | "receiving" | "none"
  final String scope;

  /// Mobile Role Access codes; null keeps the role-flag rules below.
  final List<String>? features;

  bool _feature(String code, {required bool legacy}) =>
      features == null ? legacy : features!.contains(code);

  bool get hasAnyAccess => _feature(
        AppFeature.purchaseHub,
        legacy: isPurchaseRep ||
            isPurchaseManager ||
            isDocController ||
            isCostControlOrManagement,
      );

  bool get _legacyMrRfq =>
      isPurchaseRep || isPurchaseManager || isCostControlOrManagement;

  bool get canSeeMr => _feature(AppFeature.purchaseMrTab, legacy: true);

  bool get canSeeRfq => _feature(AppFeature.purchaseRfqTab, legacy: true);

  bool get canSeeRecentInvoices =>
      _feature(AppFeature.purchaseRecentInvoices, legacy: true);

  bool get canSeeInvoiceReceiving => _feature(
        AppFeature.purchaseInvoiceReceivingTab,
        legacy: isDocController || (isPurchaseRep && !isPurchaseManager),
      );

  List<PurchaseTab> get allowedTabs {
    final tabs = <PurchaseTab>[];
    if (_feature(AppFeature.purchaseMrTab, legacy: _legacyMrRfq)) {
      tabs.add(PurchaseTab.mr);
    }
    if (_feature(AppFeature.purchaseRfqTab, legacy: _legacyMrRfq)) {
      tabs.add(PurchaseTab.rfq);
    }
    if (canSeeInvoiceReceiving) {
      tabs.add(PurchaseTab.invoice);
    }
    return tabs;
  }

  bool get canSeeDraftInvoices =>
      isPurchaseManager || isCostControlOrManagement;

  bool get canCreateInvoice =>
      _feature(AppFeature.purchaseInvoiceCreate, legacy: isDocController);

  bool get canReceiveInvoice => isPurchaseRep && !isPurchaseManager;

  bool canSeeTab(PurchaseTab tab) => allowedTabs.contains(tab);

  String get scopeLabel => switch (scope) {
        'all' => 'Company-wide',
        'department' => 'Department',
        'own' => 'My records',
        'receiving' => 'Invoice receiving',
        _ => '',
      };

  static const none = PurchaseAccess(
    isPurchaseRep: false,
    isPurchaseManager: false,
    isCostControlOrManagement: false,
    isDocController: false,
    scope: 'none',
  );

  @override
  String toString() =>
      'PurchaseAccess(rep=$isPurchaseRep, mgr=$isPurchaseManager, mgmt=$isCostControlOrManagement, dc=$isDocController, scope=$scope)';
}

enum PurchaseTab { mr, rfq, invoice }

extension PurchaseTabX on PurchaseTab {
  String get label => switch (this) {
        PurchaseTab.mr => 'Requisitions',
        PurchaseTab.rfq => 'RFQ / LPO',
        PurchaseTab.invoice => 'Invoice Receiving',
      };

  String get labelAr => switch (this) {
        PurchaseTab.mr => 'طلبات المواد',
        PurchaseTab.rfq => 'عرض الأسعار / أمر الشراء',
        PurchaseTab.invoice => 'استلام الفواتير',
      };

  static PurchaseTab? fromApiKey(String key) => switch (key) {
        'mr' => PurchaseTab.mr,
        'rfq' => PurchaseTab.rfq,
        'invoice' => PurchaseTab.invoice,
        _ => null,
      };
}

PurchaseAccess purchaseAccessFromData(Data? data) {
  if (data == null) return PurchaseAccess.none;

  final caps = data.roleCapabilities ?? {};

  final hasManagement = data.isCostControlOrManagement == true ||
      data.isManagement == true ||
      caps['x_is_management'] == true;

  final hasManagerRole = caps['x_purchase_manager_role'] == true ||
      caps['x_purchaes_manager_role'] == true;

  final hasOfficerFlag = caps['x_purchase_officer'] == true;

  final isPurchaseManager = data.isPurchaseManager == true ||
      caps['x_is_purchase_manager'] == true ||
      hasManagement ||
      hasManagerRole;

  final isPurchaseRep = (data.isPurchaseRep == true ||
          caps['x_is_purchase_rep'] == true ||
          hasOfficerFlag) &&
      !isPurchaseManager;

  final isDocController = data.isDocController == true ||
      caps['x_is_dc_role'] == true ||
      caps['x_is_doc_controller'] == true;

  var scope = data.purchaseScope ?? 'none';
  if (scope == 'none') {
    if (hasManagement) {
      scope = 'all';
    } else if (hasManagerRole || data.isPurchaseManager == true) {
      scope = 'department';
    } else if (isPurchaseRep) {
      scope = 'own';
    } else if (isDocController) {
      scope = 'receiving';
    }
  }

  return PurchaseAccess(
    isPurchaseRep: isPurchaseRep,
    isPurchaseManager: isPurchaseManager,
    isCostControlOrManagement: hasManagement,
    isDocController: isDocController,
    scope: scope,
    features: FeatureAccess.codesOf(data),
  );
}

PurchaseAccess purchaseAccessFromLoginPref() {
  final data = SharedPref.getLoginData().result?.data;
  return purchaseAccessFromData(data);
}
