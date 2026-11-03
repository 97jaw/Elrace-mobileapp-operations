import 'package:el_race/core/timesheet/models/timesheet_approval.dart';
import 'package:flutter_test/flutter_test.dart';

TimesheetApproval _doc({
  required List<String> pendingUids,
  TimesheetApprovalStatus status = TimesheetApprovalStatus.pending,
}) {
  return TimesheetApproval(
    id: 'ta-1',
    ownerUid: 'foreman',
    ownerName: 'Foreman',
    fileName: 'Timesheet.pdf',
    projectId: 'p1',
    projectName: 'Site A',
    pageCount: 1,
    pdfPath: 'timesheet_approvals/foreman/ta-1/original.pdf',
    approvers: {
      'se-uid': const TimesheetApproverEntry(
        role: TimesheetApproverRole.siteEngineer,
        name: 'SE',
        status: TimesheetApproverStatus.pending,
      ),
      'pm-uid': const TimesheetApproverEntry(
        role: TimesheetApproverRole.projectsManager,
        name: 'PM',
        status: TimesheetApproverStatus.pending,
      ),
    },
    approverUids: const ['se-uid', 'pm-uid'],
    pendingUids: pendingUids,
    status: status,
    cells: const [],
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  test('pending for me → Approve/Reject actions', () {
    final doc = _doc(pendingUids: const ['se-uid', 'pm-uid']);
    expect(doc.showsApproverActionsFor('se-uid'), isTrue);
    expect(doc.showsApproverActionsFor('pm-uid'), isTrue);
  });

  test('already acted or not pending → read-only', () {
    final afterSe = _doc(pendingUids: const ['pm-uid']);
    expect(afterSe.showsApproverActionsFor('se-uid'), isFalse);
    expect(afterSe.showsApproverActionsFor('pm-uid'), isTrue);

    final done = _doc(
      pendingUids: const [],
      status: TimesheetApprovalStatus.approved,
    );
    expect(done.showsApproverActionsFor('se-uid'), isFalse);
    expect(done.showsApproverActionsFor('pm-uid'), isFalse);
    expect(done.showsApproverActionsFor('stranger'), isFalse);
  });
}
