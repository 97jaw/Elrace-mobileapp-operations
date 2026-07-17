import 'package:equatable/equatable.dart';

class ProjectSupervisorEntity extends Equatable {
  final int employeeId;
  final String employeeName;
  final String empCode;
  final String jobId;
  final String status;
  final String? photo;

  const ProjectSupervisorEntity({
    required this.employeeId,
    required this.employeeName,
    required this.empCode,
    required this.jobId,
    required this.status,
    this.photo,
  });

  @override
  List<Object?> get props => [
        employeeId,
        employeeName,
        empCode,
        jobId,
        status,
        photo,
      ];
}

class ProjectEntity extends Equatable {
  final int projectId;
  final String partnerId;
  final String agreementId;
  final String woRefNo;
  final String name;
  final double woAmount;
  final String projectStatus;
  final String date;
  final String dateStart;
  final int? differenceDays;
  final String? projectManagerPhoto;
  /// When API returns coordinates, map uses them; otherwise UAE fallback placement applies.
  final double? latitude;
  final double? longitude;
  final String? clientImageUrl;
  final String? managerPhoto;
  final String? projectManagerName;
  final int? projectManagerId;
  final String? projectStatusCompute;
  final String? projectNameArabic;
  final String? woTypeNoOffice;
  /// Odoo `x_internal_project` — when true, project is excluded from mobile lists.
  final bool isInternalProject;
  final String? partnerName;
  final int? cityId;
  final String? cityName;
  final double? totalProgress;
  final String? contractorName;
  final String? milestoneLabel;
  final String? budgetLabel;
  final int? openIssuesCount;
  final List<ProjectSupervisorEntity> supervisors;

  /// Internal / “general” projects must not appear in mobile portfolio UIs
  /// (client bars, lists, KPIs). Covers `x_internal_project` and `wo_type`.
  bool get isGeneralWo {
    if (isInternalProject) return true;
    final wo = woTypeNoOffice?.trim().toLowerCase();
    if (wo == 'general') return true;
    return false;
  }

  const ProjectEntity({
    required this.projectId,
    required this.partnerId,
    required this.agreementId,
    required this.woRefNo,
    required this.name,
    required this.woAmount,
    required this.projectStatus,
    required this.date,
    required this.dateStart,
    this.differenceDays,
    this.projectManagerPhoto,
    this.latitude,
    this.longitude,
    this.clientImageUrl,
    this.managerPhoto,
    this.projectManagerName,
    this.projectManagerId,
    this.projectStatusCompute,
    this.projectNameArabic,
    this.woTypeNoOffice,
    this.isInternalProject = false,
    this.partnerName,
    this.cityId,
    this.cityName,
    this.totalProgress,
    this.contractorName,
    this.milestoneLabel,
    this.budgetLabel,
    this.openIssuesCount,
    this.supervisors = const [],
  });

  @override
  List<Object?> get props => [
        projectId,
        partnerId,
        agreementId,
        woRefNo,
        name,
        woAmount,
        projectStatus,
        date,
        dateStart,
        differenceDays,
        projectManagerPhoto,
        latitude,
        longitude,
        clientImageUrl,
        managerPhoto,
        projectManagerName,
        projectManagerId,
        projectStatusCompute,
        projectNameArabic,
        woTypeNoOffice,
        isInternalProject,
        partnerName,
        cityId,
        cityName,
        totalProgress,
        contractorName,
        milestoneLabel,
        budgetLabel,
        openIssuesCount,
        supervisors,
      ];
}
