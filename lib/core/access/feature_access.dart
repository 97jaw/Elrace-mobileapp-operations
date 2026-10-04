import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';

/// Mobile Role Access feature codes (Odoo `mobile.feature.code`).
abstract final class AppFeature {
  static const hrEmployeesProfile = 'hr.employees_profile';
  static const hrCompanyDocuments = 'hr.company_documents';
  static const hrRequestsManager = 'hr.requests.manager';
  static const hrRequestsHrManager = 'hr.requests.hr_manager';
  static const hrRecruitmentManager = 'hr.recruitment.manager';
  static const hrRecruitmentHrManager = 'hr.recruitment.hr_manager';
  static const hrPerformanceManager = 'hr.performance.manager';
  static const hrPayslipHrView = 'hr.payslip.hr_view';
  static const hrAttendanceTeamView = 'hr.attendance.team_view';

  static const timesheetForeman = 'timesheet.foreman';
  static const timesheetPm = 'timesheet.pm';
  static const timesheetHrWide = 'timesheet.hr_wide';
  static const timesheetActAsForeman = 'timesheet.act_as_foreman';

  static const homeDrawingStudio = 'home.drawing_studio';

  static const projectsFinancialsTab = 'projects.financials_tab';
  static const projectsAttachmentsTab = 'projects.attachments_tab';
  static const projectsDocumentsHub = 'projects.documents_hub';
  static const projectsDocumentsHubAdmin = 'projects.documents_hub.admin';
  static const projectsDocumentsWorkOrders = 'projects.documents.work_orders';
  static const projectsDocumentsEstimation = 'projects.documents.estimation';
  static const projectsDocumentsSharepoint = 'projects.documents.sharepoint';
  static const projectsDashboardAll = 'projects.dashboard_all';

  static const purchaseHub = 'purchase.hub';
  static const purchaseMrTab = 'purchase.mr_tab';
  static const purchaseRfqTab = 'purchase.rfq_tab';
  static const purchaseInvoiceReceivingTab = 'purchase.invoice_receiving_tab';
  static const purchaseInvoiceCreate = 'purchase.invoice_create';
  static const purchaseRecentInvoices = 'purchase.recent_invoices';

  static const signatureStamp = 'signature.stamp';
  static const qrSurvey = 'qr.survey';
  static const mediaProjectsTab = 'media.projects_tab';
}

/// What the app shows, from the `features` list of login / session refresh.
///
/// When the saved login has no `features` (older backend, failed resolution,
/// login cached before this build) every check returns the caller's legacy
/// rule, so access never drops because the list is missing.
/// Build with `--dart-define=ROLE_FEATURES=false` to always use legacy rules.
abstract final class FeatureAccess {
  static const _enabled =
      bool.fromEnvironment('ROLE_FEATURES', defaultValue: true);

  /// Feature codes of [data], or null when the legacy rules apply.
  static List<String>? codesOf(Data? data) => _enabled ? data?.features : null;

  static List<String>? _codes() =>
      codesOf(SharedPref.getLoginDataOrNull()?.result?.data);

  /// True when the server sent `features` for this session.
  static bool get isActive => _codes() != null;

  /// Feature check with today's rule as the fallback.
  static bool allows(String code, {required bool legacy}) {
    final codes = _codes();
    return codes == null ? legacy : codes.contains(code);
  }
}
