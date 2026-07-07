import 'timesheet_model_parsers.dart';

/// One day row from `POST /api/count/timesheets/by/days`.
class TimesheetDayCountRow {
  const TimesheetDayCountRow({
    required this.date,
    required this.inProgress,
    required this.submitted,
    required this.approved,
  });

  final DateTime date;
  final int inProgress;
  final int submitted;
  final int approved;

  bool get hasActivity => inProgress > 0 || submitted > 0 || approved > 0;

  factory TimesheetDayCountRow.fromOdooJson(Map<String, dynamic> json) {
    final dateRaw = json['date']?.toString() ?? '';
    return TimesheetDayCountRow(
      date: tmDateTimeFromJson(dateRaw) ?? DateTime.now(),
      inProgress: tmIntFromJson(json['inprogress'] ?? json['in_progress']),
      submitted: tmIntFromJson(json['submitted']),
      approved: tmIntFromJson(json['approved']),
    );
  }
}
