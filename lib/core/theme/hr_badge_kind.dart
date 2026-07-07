/// Distinguishes which color map applies to a normalized `ui_status` string.
///
/// Module 1 HR requests use [request]. Module 2 recruitment uses the others
/// (SRD §4, TASKS F.1).
enum HrBadgeKind {
  request,
  requisition,
  candidate,
  offer,
  /// Module 3 — performance evaluation pipeline (Odoo `ui_status`).
  performanceEvaluation,
}
