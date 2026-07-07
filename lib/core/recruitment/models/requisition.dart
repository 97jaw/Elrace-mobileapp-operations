/// Job requisition list row — Module 2 TASKS R1 / SRD §3.1.
///
/// // TODO(backend): Parse from recruitment API; use normalized `uiStatus` only.
class Requisition {
  const Requisition({
    required this.id,
    required this.referenceNumber,
    required this.jobTitle,
    required this.department,
    required this.location,
    required this.vacancies,
    required this.candidateCount,
    required this.offerCount,
    required this.uiStatus,
    this.uiStatusLabel,
    required this.raisedBy,
    required this.openedAt,
    required this.candidatesInPipeline,
    required this.pendingOfferCount,
  });

  final String id;
  final String referenceNumber;
  final String jobTitle;
  final String department;
  final String location;
  final int vacancies;
  final int candidateCount;
  final int offerCount;
  /// Normalized requisition state (underscores), e.g. `IN_RECRUITMENT`.
  final String uiStatus;
  final String? uiStatusLabel;
  final String raisedBy;
  final DateTime openedAt;
  /// Active pipeline candidates (excludes hired / rejected / withdrawn) — mock KPI field.
  final int candidatesInPipeline;
  /// Offers in `SENT` for this requisition — mock KPI field.
  final int pendingOfferCount;
}
