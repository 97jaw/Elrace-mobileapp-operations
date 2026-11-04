/// Waiting / progress approval pushes: show the banner, never save locally.
///
/// Used by every FCM → Notification Center write path (foreground, tap,
/// initial message, background isolate). Timesheet skips stay beside this.
bool isPushOnlyApproval(Map<String, dynamic>? data) {
  if (data == null || data.isEmpty) return false;

  final type = _text(data['type']).toLowerCase();
  // v1 dispatcher payloads (`nv` set): type is the notify type code.
  if (type == 'approval.waiting' || type == 'approval.progress') {
    return true;
  }

  // Legacy Odoo FCM from elrace_dashboard (validate_tier / tier_review /
  // _notify_pending_reviewer / HR status update). Match model + status only;
  // keep rejected (and any other status) stored.
  const models = <String>{
    'employee.requests',
    'purchase.order',
    'account.move',
    'hr.expense.sheet',
    'it.hardware.request',
  };
  const statuses = <String>{
    'pending',
    'approved',
    'approved_final',
  };
  final model = _text(data['model']).toLowerCase();
  final status = _text(data['status']).toLowerCase();
  return models.contains(model) && statuses.contains(status);
}

String _text(dynamic value) => (value ?? '').toString().trim();
