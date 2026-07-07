import 'package:el_race/core/timesheet/network/timesheet_odoo_employee.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/face_recognition/tm_face_capture_notice_tile.dart';
import 'package:flutter/material.dart';

export 'tm_face_capture_notice_tile.dart' show TmFaceCaptureNoticeKind;

/// Green success card after a real session capture.
class TmFaceCaptureSuccessTile extends StatelessWidget {
  const TmFaceCaptureSuccessTile({
    super.key,
    required this.employee,
    required this.matchScore,
    this.autoDismissSeconds = 3,
    this.onDismissed,
  });

  final TimesheetOdooEmployee employee;
  final double matchScore;
  final int autoDismissSeconds;
  final VoidCallback? onDismissed;

  @override
  Widget build(BuildContext context) {
    return TmFaceCaptureNoticeTile(
      key: key,
      employee: employee,
      kind: TmFaceCaptureNoticeKind.captured,
      matchScore: matchScore,
      autoDismissSeconds: autoDismissSeconds,
      onDismissed: onDismissed,
    );
  }
}
