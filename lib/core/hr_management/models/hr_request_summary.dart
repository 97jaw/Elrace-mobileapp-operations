/// List row for HR requests — E1 / mock API (SRD §3.1).
class HrRequestSummary {
  const HrRequestSummary({
    required this.id,
    required this.referenceNumber,
    required this.type,
    required this.uiStatus,
    this.submittedAtLabel,
    this.secondaryLine,
    this.relativeSubmittedLabel,
    this.sequence = 0,
    this.employeeName,
    this.employeeRoleLine,
    this.employeeNumber,
    this.department,
  });

  final String id;
  final String referenceNumber;
  final String type;
  final String uiStatus;
  final String? submittedAtLabel;

  /// e.g. "12 May → 16 May (5 days)" — SRD request card.
  final String? secondaryLine;

  /// e.g. "Submitted 2d ago"
  final String? relativeSubmittedLabel;

  /// Higher = newer for mock sorting when API has no dates.
  final int sequence;

  /// Team list (M1) — optional.
  final String? employeeName;
  final String? employeeRoleLine;
  final String? employeeNumber;
  final String? department;

  factory HrRequestSummary.fromJson(Map<String, dynamic> json) {
    return HrRequestSummary(
      id: json['id']?.toString() ?? '',
      referenceNumber:
          json['reference']?.toString() ?? json['referenceNumber']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      uiStatus: json['ui_status']?.toString() ?? 'PENDING',
      submittedAtLabel: json['submitted_at']?.toString(),
      secondaryLine: json['secondary_line']?.toString(),
      relativeSubmittedLabel: json['relative_submitted']?.toString(),
      sequence: json['sequence'] is int ? json['sequence'] as int : int.tryParse(json['sequence']?.toString() ?? '') ?? 0,
      employeeName: json['employee_name']?.toString(),
      employeeRoleLine: json['employee_role_line']?.toString(),
      employeeNumber: json['employee_number']?.toString(),
      department: json['department']?.toString(),
    );
  }
}
