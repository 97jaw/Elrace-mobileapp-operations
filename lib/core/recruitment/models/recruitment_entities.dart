import 'package:el_race/core/recruitment/models/requisition.dart';

// ignore_for_file: public_member_api_docs — internal DTOs; SRD is source of truth.

/// Five pipeline buckets for R2 summary cards (SRD §3.2.2).
class RecruitmentPipelineCounts {
  const RecruitmentPipelineCounts({
    required this.applied,
    required this.screening,
    required this.interview,
    required this.offer,
    required this.hired,
  });

  final int applied;
  final int screening;
  final int interview;
  final int offer;
  final int hired;
}

class RecruitmentActivityEntry {
  const RecruitmentActivityEntry({required this.at, required this.message});

  final DateTime at;
  final String message;
}

class RecruitmentOfferListRow {
  const RecruitmentOfferListRow({
    required this.id,
    required this.candidateId,
    required this.candidateName,
    required this.uiStatus,
    this.sentAt,
  });

  final String id;
  final String candidateId;
  final String candidateName;
  final String uiStatus;
  final DateTime? sentAt;
}

class RecruitmentAssessmentSummary {
  const RecruitmentAssessmentSummary({
    required this.id,
    required this.roundName,
    required this.date,
    required this.interviewer,
    required this.overallScore,
    required this.recommendation,
    required this.isDraft,
  });

  final String id;
  final String roundName;
  final DateTime date;
  final String interviewer;
  final double overallScore;
  final String recommendation;
  final bool isDraft;
}

/// Full scorecard for A1.
class RecruitmentAssessmentDetail {
  const RecruitmentAssessmentDetail({
    required this.id,
    required this.candidateId,
    required this.candidateName,
    required this.roundName,
    required this.interviewDate,
    required this.interviewer,
    required this.technical,
    required this.problemSolving,
    required this.communication,
    required this.culturalFit,
    required this.strengths,
    required this.concerns,
    required this.recommendation,
    required this.comments,
    required this.isDraft,
    required this.interviewerEmpId,
    required this.currentUserEmpId,
  });

  final String id;
  final String candidateId;
  final String candidateName;
  final String roundName;
  final DateTime interviewDate;
  final String interviewer;
  final int technical;
  final int problemSolving;
  final int communication;
  final int culturalFit;
  final String strengths;
  final String concerns;
  final String recommendation;
  final String comments;
  final bool isDraft;
  final String interviewerEmpId;
  final String currentUserEmpId;
}

class RecruitmentCandidate {
  const RecruitmentCandidate({
    required this.id,
    required this.requisitionId,
    required this.requisitionRef,
    required this.jobTitle,
    required this.fullName,
    required this.email,
    this.phone,
    required this.stage,
    required this.appliedAt,
    this.avgScore,
    this.source,
    this.yearsExperience,
    this.currentCompany,
    this.expectedSalary,
    this.noticePeriod,
    this.assessments = const [],
    this.offerId,
    this.notesLines = const [],
  });

  final String id;
  final String requisitionId;
  final String requisitionRef;
  final String jobTitle;
  final String fullName;
  final String email;
  final String? phone;
  /// Normalized candidate stage (e.g. APPLIED, INTERVIEW).
  final String stage;
  final DateTime appliedAt;
  final double? avgScore;
  final String? source;
  final int? yearsExperience;
  final String? currentCompany;
  final String? expectedSalary;
  final String? noticePeriod;
  final List<RecruitmentAssessmentSummary> assessments;
  final String? offerId;
  final List<String> notesLines;
}

class RequisitionDetailModel {
  const RequisitionDetailModel({
    required this.requisition,
    required this.jobDescription,
    required this.keyResponsibilities,
    required this.requiredSkills,
    this.salaryMinAed,
    this.salaryMaxAed,
    this.requiredBy,
    required this.pipeline,
    required this.candidates,
    required this.offers,
    required this.activities,
  });

  final Requisition requisition;
  final String jobDescription;
  final String keyResponsibilities;
  final List<String> requiredSkills;
  final int? salaryMinAed;
  final int? salaryMaxAed;
  final DateTime? requiredBy;
  final RecruitmentPipelineCounts pipeline;
  final List<RecruitmentCandidate> candidates;
  final List<RecruitmentOfferListRow> offers;
  final List<RecruitmentActivityEntry> activities;
}

class RecruitmentOfferDetail {
  const RecruitmentOfferDetail({
    required this.id,
    required this.candidateName,
    required this.positionTitle,
    required this.referenceNumber,
    required this.uiStatus,
    required this.sentAt,
    required this.expiryAt,
    required this.department,
    required this.reportingManager,
    required this.location,
    required this.joiningDate,
    required this.employmentType,
    this.salaryBreakdownLines,
  });

  final String id;
  final String candidateName;
  final String positionTitle;
  final String referenceNumber;
  final String uiStatus;
  final DateTime? sentAt;
  final DateTime? expiryAt;
  final String department;
  final String reportingManager;
  final String location;
  final DateTime? joiningDate;
  final String employmentType;
  /// HR-only lines; null when hidden for hiring manager (SRD §5.1.2).
  final List<String>? salaryBreakdownLines;
}
