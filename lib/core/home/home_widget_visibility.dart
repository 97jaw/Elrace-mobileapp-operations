import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';

/// v7 home dashboard widget codes — align with login `default_widgets` keys.
enum HomeWidgetCode {
  attendance,
  hrms,
  timesheet,
  myProjects,
  siteManagement,
  myReports,
  clients,
  vendors,
  subContractors,
  lpo,
  taskManagement,
  notes,
  tickets,
  pettyCash,
  myDocuments,
  media,
}

/// Resolves visibility from login `default_widgets.*.is_disabled`.
///
/// Backend: `is_disabled: true` → hidden on home.
class HomeWidgetVisibility {
  const HomeWidgetVisibility(this._data);

  final WidgetsData? _data;

  factory HomeWidgetVisibility.fromLoginPref() {
    return HomeWidgetVisibility(
      SharedPref.getLoginData().result?.data?.defaultWidgets?.data,
    );
  }

  /// Visible when not explicitly disabled. Missing widget info defaults to visible.
  bool isVisible(HomeWidgetCode code) {
    if (code == HomeWidgetCode.vendors) {
      return _isVendorsVisible();
    }
    // Sub-Contractors merged into Vendors — never show a separate card.
    if (code == HomeWidgetCode.subContractors) {
      return false;
    }
    final info = _widgetInfo(code);
    if (info == null) return true;
    return info.isDisabled != true;
  }

  /// Vendors card: use vendors_widget; fall back to legacy sub_contractors_widget
  /// when an older login payload only enabled Subs.
  bool _isVendorsVisible() {
    final vendors = _data?.vendorsWidget;
    if (vendors != null) return vendors.isDisabled != true;
    final legacySubs = _data?.subContractorsWidget;
    if (legacySubs != null) return legacySubs.isDisabled != true;
    return true;
  }

  bool get hasVisibleHr =>
      isVisible(HomeWidgetCode.attendance) ||
      isVisible(HomeWidgetCode.hrms) ||
      isVisible(HomeWidgetCode.timesheet);

  bool get hasVisibleProjects =>
      isVisible(HomeWidgetCode.myProjects) ||
      isVisible(HomeWidgetCode.siteManagement) ||
      isVisible(HomeWidgetCode.myReports);

  /// Clients & Vendors — prefer login `is_disabled`; fall back to management
  /// role until backend keys are present on older sessions.
  bool get hasVisibleClientsVendors {
    final configured = _data?.clientsWidget != null ||
        _data?.vendorsWidget != null ||
        _data?.subContractorsWidget != null;
    if (!configured) return _isManagementFallback();
    return isVisible(HomeWidgetCode.clients) ||
        isVisible(HomeWidgetCode.vendors);
  }

  bool get hasVisiblePurchase => isVisible(HomeWidgetCode.lpo);

  bool get hasVisibleProductivity =>
      isVisible(HomeWidgetCode.taskManagement) ||
      isVisible(HomeWidgetCode.notes) ||
      isVisible(HomeWidgetCode.tickets);

  bool get hasVisibleFinance => isVisible(HomeWidgetCode.pettyCash);

  bool get hasVisibleLibrary =>
      isVisible(HomeWidgetCode.myDocuments) ||
      isVisible(HomeWidgetCode.media);

  WidgetInfo? _widgetInfo(HomeWidgetCode code) {
    switch (code) {
      case HomeWidgetCode.attendance:
        return _data?.attendanceWidget;
      case HomeWidgetCode.hrms:
        return _data?.hrmsWidget;
      case HomeWidgetCode.timesheet:
        return _data?.timesheetWidget;
      case HomeWidgetCode.myProjects:
        return _data?.myProjectsWidget;
      case HomeWidgetCode.siteManagement:
        return _data?.siteManagementWidget;
      case HomeWidgetCode.myReports:
        return _data?.myReportsWidget;
      case HomeWidgetCode.clients:
        return _data?.clientsWidget;
      case HomeWidgetCode.vendors:
        return _data?.vendorsWidget;
      case HomeWidgetCode.subContractors:
        return _data?.subContractorsWidget;
      case HomeWidgetCode.lpo:
        return _data?.lpoWidget;
      case HomeWidgetCode.taskManagement:
        return _data?.taskManagementWidget;
      case HomeWidgetCode.notes:
        return _data?.myNotesWidget;
      case HomeWidgetCode.tickets:
        return _data?.ticketsWidget;
      case HomeWidgetCode.pettyCash:
        return _data?.pettyCashWidget;
      case HomeWidgetCode.myDocuments:
        return _data?.myDocumentsWidget;
      case HomeWidgetCode.media:
        return _data?.mediaWidget;
    }
  }

  bool _isManagementFallback() {
    final data = SharedPref.getLoginData().result?.data;
    if (data == null) return false;
    if (data.isManagement == true) return true;
    final caps = data.roleCapabilities;
    return caps != null && caps['x_is_management'] == true;
  }
}
