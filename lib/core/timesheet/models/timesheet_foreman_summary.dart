/// Per-foreman monitoring summary for a project (Site Management).
///
/// Sourced from the new `/timesheet/project_foremen_summary` endpoint, which
/// aggregates `account.analytic.line` submissions per foreman.
class TimesheetForemanSummary {
  const TimesheetForemanSummary({
    required this.employeeId,
    required this.name,
    required this.fileId,
    this.imageUrl,
    this.totalHours = 0,
    this.lastSubmitDate,
  });

  final int employeeId;
  final String name;
  final String fileId;
  final String? imageUrl;

  /// Total hours submitted by this foreman on the project.
  final double totalHours;

  /// Most recent timesheet submit date for this foreman on the project.
  final DateTime? lastSubmitDate;

  factory TimesheetForemanSummary.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    DateTime? toDate(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      return DateTime.tryParse(s.replaceFirst(' ', 'T'));
    }

    final id = toInt(json['employee_id'] ?? json['id']);
    return TimesheetForemanSummary(
      employeeId: id,
      name: json['name']?.toString() ??
          json['employee_name']?.toString() ??
          '',
      fileId: (json['file_id'] ?? json['emp_code'] ?? json['file_no'] ?? id)
          .toString(),
      imageUrl: (json['image'] ?? json['photo'] ?? json['image_url'])
          ?.toString(),
      totalHours: toDouble(
        json['total_hours'] ?? json['hours'] ?? json['unit_amount'],
      ),
      lastSubmitDate: toDate(
        json['last_submit_date'] ?? json['last_date'] ?? json['last_active'],
      ),
    );
  }
}
