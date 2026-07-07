import 'package:el_race/core/recruitment/models/recruitment_entities.dart';
import 'package:el_race/core/recruitment/models/requisition.dart';

DateTime _parseDate(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString()) ?? DateTime.now();
}

Requisition requisitionFromJson(Map<String, dynamic> json) {
  return Requisition(
    id: json['id']?.toString() ?? '',
    referenceNumber: json['reference_number']?.toString() ?? '',
    jobTitle: json['job_title']?.toString() ?? '',
    department: json['department']?.toString() ?? '',
    location: json['location']?.toString() ?? '',
    vacancies: (json['vacancies'] as num?)?.toInt() ?? 0,
    candidateCount: (json['candidate_count'] as num?)?.toInt() ?? 0,
    offerCount: (json['offer_count'] as num?)?.toInt() ?? 0,
    uiStatus: json['ui_status']?.toString() ?? 'DRAFT',
    uiStatusLabel: json['ui_status_label'] as String?,
    raisedBy: json['raised_by']?.toString() ?? '',
    openedAt: _parseDate(json['opened_at']),
    candidatesInPipeline: (json['candidates_in_pipeline'] as num?)?.toInt() ?? 0,
    pendingOfferCount: (json['pending_offer_count'] as num?)?.toInt() ?? 0,
  );
}

RecruitmentPipelineCounts pipelineFromJson(Map<String, dynamic>? json) {
  if (json == null) {
    return const RecruitmentPipelineCounts(
      applied: 0,
      screening: 0,
      interview: 0,
      offer: 0,
      hired: 0,
    );
  }
  return RecruitmentPipelineCounts(
    applied: (json['applied'] as num?)?.toInt() ?? 0,
    screening: (json['screening'] as num?)?.toInt() ?? 0,
    interview: (json['interview'] as num?)?.toInt() ?? 0,
    offer: (json['offer'] as num?)?.toInt() ?? 0,
    hired: (json['hired'] as num?)?.toInt() ?? 0,
  );
}

RecruitmentAssessmentSummary assessmentSummaryFromJson(
  Map<String, dynamic> json,
) {
  return RecruitmentAssessmentSummary(
    id: json['id']?.toString() ?? '',
    roundName: json['round_name']?.toString() ?? 'Assessment',
    date: _parseDate(json['date']),
    interviewer: json['interviewer']?.toString() ?? '',
    overallScore: (json['overall_score'] as num?)?.toDouble() ?? 0,
    recommendation: json['recommendation']?.toString() ?? '',
    isDraft: json['is_draft'] == true,
  );
}

RecruitmentCandidate candidateFromJson(Map<String, dynamic> json) {
  final assessmentsRaw = json['assessments'];
  final assessments = assessmentsRaw is List
      ? assessmentsRaw
          .whereType<Map>()
          .map((e) => assessmentSummaryFromJson(Map<String, dynamic>.from(e)))
          .toList()
      : <RecruitmentAssessmentSummary>[];
  return RecruitmentCandidate(
    id: json['id']?.toString() ?? '',
    requisitionId: json['requisition_id']?.toString() ?? '',
    requisitionRef: json['requisition_ref']?.toString() ?? '',
    jobTitle: json['job_title']?.toString() ?? '',
    fullName: json['full_name']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    phone: json['phone']?.toString(),
    stage: json['stage']?.toString() ?? 'APPLIED',
    // stage_label available for display via badge override if needed
    appliedAt: _parseDate(json['applied_at']),
    avgScore: (json['avg_score'] as num?)?.toDouble(),
    source: json['source']?.toString(),
    yearsExperience: (json['years_experience'] as num?)?.toInt(),
    currentCompany: json['current_company']?.toString(),
    expectedSalary: json['expected_salary']?.toString(),
    noticePeriod: json['notice_period']?.toString(),
    assessments: assessments,
    offerId: json['offer_id']?.toString(),
    notesLines: (json['notes_lines'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const [],
  );
}

RequisitionDetailModel requisitionDetailFromJson(Map<String, dynamic> json) {
  final reqJson = json['requisition'] as Map?;
  final candidatesRaw = json['candidates'] as List? ?? [];
  final offersRaw = json['offers'] as List? ?? [];
  return RequisitionDetailModel(
    requisition: reqJson != null
        ? requisitionFromJson(Map<String, dynamic>.from(reqJson))
        : requisitionFromJson({}),
    jobDescription: json['job_description']?.toString() ?? '',
    keyResponsibilities: json['key_responsibilities']?.toString() ?? '',
    requiredSkills: (json['required_skills'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const [],
    salaryMinAed: (json['salary_min_aed'] as num?)?.toInt(),
    salaryMaxAed: (json['salary_max_aed'] as num?)?.toInt(),
    requiredBy: json['required_by'] != null
        ? DateTime.tryParse(json['required_by'].toString())
        : null,
    pipeline: pipelineFromJson(
      json['pipeline'] is Map
          ? Map<String, dynamic>.from(json['pipeline'] as Map)
          : null,
    ),
    candidates: candidatesRaw
        .whereType<Map>()
        .map((e) => candidateFromJson(Map<String, dynamic>.from(e)))
        .toList(),
    offers: offersRaw
        .whereType<Map>()
        .map(
          (e) => RecruitmentOfferListRow(
            id: e['id']?.toString() ?? '',
            candidateId: e['candidate_id']?.toString() ?? '',
            candidateName: e['candidate_name']?.toString() ?? '',
            uiStatus: e['ui_status']?.toString() ?? 'DRAFT',
            sentAt: e['sent_at'] != null
                ? DateTime.tryParse(e['sent_at'].toString())
                : null,
          ),
        )
        .toList(),
    activities: const [],
  );
}

RecruitmentAssessmentDetail assessmentDetailFromJson(
  Map<String, dynamic> json,
) {
  return RecruitmentAssessmentDetail(
    id: json['id']?.toString() ?? '',
    candidateId: json['candidate_id']?.toString() ?? '',
    candidateName: json['candidate_name']?.toString() ?? '',
    roundName: json['round_name']?.toString() ?? '',
    interviewDate: _parseDate(json['interview_date']),
    interviewer: json['interviewer']?.toString() ?? '',
    technical: (json['technical'] as num?)?.toInt() ?? 0,
    problemSolving: (json['problem_solving'] as num?)?.toInt() ?? 0,
    communication: (json['communication'] as num?)?.toInt() ?? 0,
    culturalFit: (json['cultural_fit'] as num?)?.toInt() ?? 0,
    strengths: json['strengths']?.toString() ?? '',
    concerns: json['concerns']?.toString() ?? '',
    recommendation: json['recommendation']?.toString() ?? '',
    comments: json['comments']?.toString() ?? '',
    isDraft: json['is_draft'] == true,
    interviewerEmpId: json['interviewer_emp_id']?.toString() ?? '',
    currentUserEmpId: json['current_user_emp_id']?.toString() ?? '',
  );
}

RecruitmentOfferDetail offerDetailFromJson(Map<String, dynamic> json) {
  final salary = json['salary_breakdown_lines'];
  return RecruitmentOfferDetail(
    id: json['id']?.toString() ?? '',
    candidateName: json['candidate_name']?.toString() ?? '',
    positionTitle: json['position_title']?.toString() ?? '',
    referenceNumber: json['reference_number']?.toString() ?? '',
    uiStatus: json['ui_status']?.toString() ?? 'DRAFT',
    sentAt: json['sent_at'] != null
        ? DateTime.tryParse(json['sent_at'].toString())
        : null,
    expiryAt: json['expiry_at'] != null
        ? DateTime.tryParse(json['expiry_at'].toString())
        : null,
    department: json['department']?.toString() ?? '',
    reportingManager: json['reporting_manager']?.toString() ?? '',
    location: json['location']?.toString() ?? '',
    joiningDate: json['joining_date'] != null
        ? DateTime.tryParse(json['joining_date'].toString())
        : null,
    employmentType: json['employment_type']?.toString() ?? '',
    salaryBreakdownLines: salary is List
        ? salary.map((e) => e.toString()).toList()
        : null,
  );
}
