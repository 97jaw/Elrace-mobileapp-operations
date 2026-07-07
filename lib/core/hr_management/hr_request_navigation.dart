import 'package:el_race/core/hr_management/models/hr_request_summary.dart';
import 'package:el_race/ui/presentation/Email%20Approval/screens/hr_details_screen.dart';
import 'package:flutter/material.dart';

/// Opens the existing approval HR form ([HrDetailsScreen]) for list taps.
///
/// Uses `/api/get_hr_request_details` — same as My Approvals / Email Approval.
/// [summary.type] is only a hint; the screen resolves the form from API payload.
Future<void> openHrRequestDetail(
  BuildContext context,
  HrRequestSummary summary, {
  bool managerContext = false,
}) {
  final id = summary.id.trim();
  if (id.isEmpty) return Future.value();

  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => HrDetailsScreen(
        requestId: id,
        type: _typeHint(summary.type, managerContext: managerContext),
        showApprovalActions: false,
      ),
    ),
  );
}

String _typeHint(String type, {required bool managerContext}) {
  final t = type.toLowerCase();
  if (t.contains('sick')) return 'sick';
  if (t.contains('short')) return 'short';
  if (t.contains('annual')) return 'annual';
  if (t.contains('maternity')) return 'maternity';
  if (t.contains('parental')) return 'parental';
  if (t.contains('job mission') || t.contains('mission')) return 'job_mission';
  if (t.contains('temporary') || t.contains('permission')) {
    return 'temporary_permission';
  }
  if (t.contains('effective')) return 'effective_date';
  if (t.contains('clearance')) return 'clearance';
  if (t.contains('certificate')) return 'salary_certificate';
  if (t.contains('loan')) return 'loan';
  if (t.contains('promotion')) return 'promotion';
  if (t.contains('increment')) return 'increment';
  if (t.contains('resignation')) return 'resignation';
  if (t.contains('termination')) return 'termination';
  if (t.contains('transfer')) return 'transfer';
  if (t.contains('passport')) return 'passport';
  if (t.contains('encashment')) return 'leave_encashment';
  if (t.contains('car rent') || t.contains('car rent')) return 'car_rent';
  if (t.contains('sim')) return 'sim';
  return managerContext ? 'hr' : 'generic';
}
