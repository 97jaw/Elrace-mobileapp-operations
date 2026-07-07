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
  });

  final bool isPurchaseRep;
  final bool isPurchaseManager;
  final bool isCostControlOrManagement;
  final bool isDocController;

  /// "own" | "department" | "all" | "receiving" | "none"
  final String scope;

  bool get hasAnyAccess =>
      isPurchaseRep || isPurchaseManager || isDocController;

  bool get canSeeInvoiceReceiving =>
      isDocController || (isPurchaseRep && !isPurchaseManager);

  List<PurchaseTab> get allowedTabs {
    final tabs = <PurchaseTab>[];
    if (isPurchaseRep || isPurchaseManager) {
      tabs.add(PurchaseTab.mr);
      tabs.add(PurchaseTab.rfq);
    }
    if (canSeeInvoiceReceiving) {
      tabs.add(PurchaseTab.invoice);
    }
    return tabs;
  }

  bool get canSeeDraftInvoices =>
      isPurchaseManager || isCostControlOrManagement;

  bool get canCreateInvoice => isDocController;

  bool get canReceiveInvoice =>
      isPurchaseRep && !isPurchaseManager;

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
  );
}

PurchaseAccess purchaseAccessFromLoginPref() {
  final data = SharedPref.getLoginData().result?.data;
  return purchaseAccessFromData(data);
}
