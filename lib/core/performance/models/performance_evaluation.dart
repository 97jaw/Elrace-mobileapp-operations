/// Module 3 — Performance evaluation (Odoo-aligned fields).
library performance_evaluation;

/// Extended employee profile for card + popup.
class PerformanceEmployeeProfile {
  const PerformanceEmployeeProfile({
    this.employeeName = '',
    this.employeeId = '',
    this.jobPosition = '',
    this.department = '',
    this.managerName = '',
    this.dateOfJoining = '',
    this.nationalityCountry = '',
    this.dateOfBirth = '',
    this.visaExpireDate = '',
    this.visaDaysToExpire = '',
    this.lengthOfServiceLine = '',
    this.evaluationDateTime = '',
    this.email = '',
    this.phone = '',
    this.workLocation = '',
  });

  final String employeeName;
  final String employeeId;
  final String jobPosition;
  final String department;
  final String managerName;
  final String dateOfJoining;
  final String nationalityCountry;
  final String dateOfBirth;
  final String visaExpireDate;
  final String visaDaysToExpire;
  final String lengthOfServiceLine;
  final String evaluationDateTime;
  final String email;
  final String phone;
  final String workLocation;
}

class PerformancePlanningInfo {
  const PerformancePlanningInfo({
    required this.title,
    required this.launchDateLabel,
    required this.cycleMonthLabel,
    required this.message,
  });

  final String title;
  final String launchDateLabel;
  final String cycleMonthLabel;
  final String message;
}

/// One row in the Personal Competencies grid.
class PersonalCompetencyRow {
  const PersonalCompetencyRow({
    required this.lineId,
    required this.index,
    required this.descriptionEn,
    required this.userScore,
    required this.maxScore,
    required this.ratingValueEnAr,
    required this.descriptionAr,
  });

  final String lineId;
  final int index;
  final String descriptionEn;
  final int userScore;
  final int maxScore;
  final String ratingValueEnAr;
  final String descriptionAr;

  String get scorePercentLabel => '$userScore/$maxScore%';
}

/// List tile for evaluation manager — team queue.
class PerformanceEvaluationSummary {
  const PerformanceEvaluationSummary({
    required this.id,
    required this.pepReference,
    required this.employeeName,
    required this.employeeId,
    required this.jobPosition,
    required this.uiStatus,
    this.uiStatusLabel,
    required this.finalScorePercent,
    required this.evaluationYear,
  });

  final String id;
  final String pepReference;
  final String employeeName;
  final String employeeId;
  final String jobPosition;
  final String uiStatus;
  final String? uiStatusLabel;
  final int finalScorePercent;
  final int evaluationYear;
}

/// Full manager detail view — metadata + competencies.
class PerformanceEvaluationDetail {
  const PerformanceEvaluationDetail({
    required this.summary,
    required this.employeeName,
    required this.employeeId,
    required this.dateOfJoining,
    required this.nationalityCountry,
    required this.managerName,
    required this.jobPosition,
    required this.lengthOfServiceLine,
    required this.evaluationDateTime,
    required this.competencies,
    required this.profile,
    this.visaExpireDate,
    this.visaDaysToExpire,
  });

  final PerformanceEvaluationSummary summary;
  final String employeeName;
  final String employeeId;
  final String dateOfJoining;
  final String nationalityCountry;
  final String managerName;
  final String jobPosition;
  final String lengthOfServiceLine;
  final String? visaExpireDate;
  final String? visaDaysToExpire;
  final String evaluationDateTime;
  final List<PersonalCompetencyRow> competencies;
  final PerformanceEmployeeProfile profile;

  String get pepReference => summary.pepReference;
  String get uiStatus => summary.uiStatus;
  int get finalScorePercent => summary.finalScorePercent;
}
