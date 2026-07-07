import 'package:el_race/core/performance/models/performance_employee_option.dart';
import 'package:el_race/core/performance/models/performance_evaluation.dart';

PerformanceEvaluationSummary summaryFromJson(Map<String, dynamic> json) {
  return PerformanceEvaluationSummary(
    id: json['id']?.toString() ?? '',
    pepReference: json['pep_reference']?.toString() ?? '',
    employeeName: json['employee_name']?.toString() ?? '',
    employeeId: json['employee_id']?.toString() ?? '',
    jobPosition: json['job_position']?.toString() ?? '',
    uiStatus: json['ui_status']?.toString() ?? 'DRAFT',
    uiStatusLabel: json['ui_status_label'] as String?,
    finalScorePercent: (json['final_score_percent'] as num?)?.toInt() ?? 0,
    evaluationYear: (json['evaluation_year'] as num?)?.toInt() ??
        DateTime.now().year,
  );
}

PerformanceEmployeeProfile profileFromJson(Map<String, dynamic>? json) {
  if (json == null) return const PerformanceEmployeeProfile();
  return PerformanceEmployeeProfile(
    employeeName: json['employee_name']?.toString() ?? '',
    employeeId: json['employee_id']?.toString() ?? '',
    jobPosition: json['job_position']?.toString() ?? '',
    department: json['department']?.toString() ?? '',
    managerName: json['manager_name']?.toString() ?? '',
    dateOfJoining: json['date_of_joining']?.toString() ?? '',
    nationalityCountry: json['nationality_country']?.toString() ?? '',
    dateOfBirth: json['date_of_birth']?.toString() ?? '',
    visaExpireDate: json['visa_expire_date']?.toString() ?? '',
    visaDaysToExpire: json['visa_days_to_expire']?.toString() ?? '',
    lengthOfServiceLine: json['length_of_service_line']?.toString() ?? '',
    evaluationDateTime: json['evaluation_date_time']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    phone: json['phone']?.toString() ?? '',
    workLocation: json['work_location']?.toString() ?? '',
  );
}

PersonalCompetencyRow competencyFromJson(Map<String, dynamic> json) {
  return PersonalCompetencyRow(
    lineId: json['id']?.toString() ?? '',
    index: (json['index'] as num?)?.toInt() ?? 0,
    descriptionEn: json['description_en']?.toString() ?? '',
    descriptionAr: json['description_ar']?.toString() ?? '',
    userScore: (json['user_score'] as num?)?.toInt() ?? 0,
    maxScore: (json['max_score'] as num?)?.toInt() ?? 5,
    ratingValueEnAr: json['rating_value_en_ar']?.toString() ?? '',
  );
}

PerformanceEvaluationDetail detailFromJson(Map<String, dynamic> json) {
  final summaryJson = json['summary'] as Map<String, dynamic>? ?? json;
  final summary = summaryFromJson(summaryJson);
  final comps = (json['competencies'] as List? ?? [])
      .whereType<Map>()
      .map((e) => competencyFromJson(Map<String, dynamic>.from(e)))
      .toList();
  return PerformanceEvaluationDetail(
    summary: summary,
    employeeName: json['employee_name']?.toString() ?? summary.employeeName,
    employeeId: json['employee_id']?.toString() ?? summary.employeeId,
    dateOfJoining: json['date_of_joining']?.toString() ?? '',
    nationalityCountry: json['nationality_country']?.toString() ?? '',
    managerName: json['manager_name']?.toString() ?? '',
    jobPosition: json['job_position']?.toString() ?? summary.jobPosition,
    lengthOfServiceLine: json['length_of_service_line']?.toString() ?? '',
    evaluationDateTime: json['evaluation_date_time']?.toString() ?? '',
    competencies: comps,
    visaExpireDate: json['visa_expire_date']?.toString(),
    visaDaysToExpire: json['visa_days_to_expire']?.toString(),
    profile: profileFromJson(
      json['profile'] as Map<String, dynamic>?,
    ),
  );
}

PerformanceEmployeeOption employeeOptionFromJson(Map<String, dynamic> json) {
  return PerformanceEmployeeOption(
    id: json['id']?.toString() ?? '',
    employeeName: json['employee_name']?.toString() ?? '',
    employeeNumber: json['employee_number']?.toString() ?? '',
    jobPosition: json['job_position']?.toString() ?? '',
    department: json['department']?.toString() ?? '',
  );
}

PerformancePlanningInfo planningFromJson(Map<String, dynamic> json) {
  return PerformancePlanningInfo(
    title: json['title']?.toString() ?? 'Under planning',
    launchDateLabel: json['launch_date_label']?.toString() ?? '',
    cycleMonthLabel: json['cycle_month_label']?.toString() ?? '',
    message: json['message']?.toString() ?? '',
  );
}
