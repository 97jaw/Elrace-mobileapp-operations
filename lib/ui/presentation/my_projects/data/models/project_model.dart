import 'package:el_race/ui/presentation/my_projects/domain/entities/project_entity.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/odoo_field_parsers.dart';

class ProjectModel extends ProjectEntity {
  const ProjectModel({
    required super.projectId,
    required super.partnerId,
    required super.agreementId,
    required super.woRefNo,
    required super.name,
    required super.woAmount,
    required super.projectStatus,
    required super.date,
    required super.dateStart,
    super.differenceDays,
    super.projectManagerPhoto,
    super.latitude,
    super.longitude,
    super.clientImageUrl,
    super.managerPhoto,
    super.projectManagerName,
    super.projectManagerId,
    super.projectStatusCompute,
    super.projectNameArabic,
    super.woTypeNoOffice,
    super.isInternalProject,
    super.partnerName,
    super.cityId,
    super.cityName,
    super.totalProgress,
    super.contractorName,
    super.milestoneLabel,
    super.budgetLabel,
    super.openIssuesCount,
    super.supervisors,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    // Fix malformed photo URL from API (erp.elrace.compublic -> erp.elrace.com/public)
    String? projectManagerPhoto = json['project_manager_photo'] as String?;
    if (projectManagerPhoto != null &&
        projectManagerPhoto.contains('erp.elrace.compublic')) {
      projectManagerPhoto = projectManagerPhoto.replaceAll(
          'erp.elrace.compublic', 'erp.elrace.com/public');
    }
    String? managerPhoto = json['manager_photo'] as String? ?? projectManagerPhoto;
    if (managerPhoto != null && managerPhoto.contains('erp.elrace.compublic')) {
      managerPhoto =
          managerPhoto.replaceAll('erp.elrace.compublic', 'erp.elrace.com/public');
    }
    String? clientImageUrl = json['client_image'] as String?;
    if (clientImageUrl != null && clientImageUrl.contains('erp.elrace.compublic')) {
      clientImageUrl =
          clientImageUrl.replaceAll('erp.elrace.compublic', 'erp.elrace.com/public');
    }

    double? parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      // Some backends send coordinates with comma decimal separator.
      return double.tryParse(s.replaceAll(',', '.'));
    }

    int? parseInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    List<ProjectSupervisorEntity> parseSupervisors(dynamic value) {
      if (value is! List) return const [];
      return value.map((item) {
        final map = (item is Map) ? item.cast<String, dynamic>() : <String, dynamic>{};
        String? photo = map['photo']?.toString();
        if (photo != null && photo.contains('erp.elrace.compublic')) {
          photo = photo.replaceAll('erp.elrace.compublic', 'erp.elrace.com/public');
        }
        return ProjectSupervisorEntity(
          employeeId: parseInt(map['employee_id']) ?? 0,
          employeeName: map['employee_name']?.toString() ?? '',
          empCode: map['emp_code']?.toString() ?? '',
          jobId: map['job_id']?.toString() ?? '',
          status: map['status']?.toString() ?? '',
          photo: photo,
        );
      }).toList(growable: false);
    }

    // Prefer ERP fields x_pr_lat / x_pr_long when present (see get_projects API).
    final lat = parseDouble(json['x_pr_lat']) ??
        parseDouble(json['x_pr_latitude']) ??
        parseDouble(json['latitude']) ??
        parseDouble(json['latitute']) ??
        parseDouble(json['lat']) ??
        parseDouble(json['partner_latitude']) ??
        parseDouble(json['project_latitude']);
    final lng = parseDouble(json['x_pr_long']) ??
        parseDouble(json['x_pr_lng']) ??
        parseDouble(json['x_pr_lon']) ??
        parseDouble(json['x_pr_longitude']) ??
        parseDouble(json['longitude']) ??
        parseDouble(json['longitute']) ??
        parseDouble(json['lng']) ??
        parseDouble(json['lon']) ??
        parseDouble(json['partner_longitude']) ??
        parseDouble(json['project_longitude']);

    final pmId = OdooFieldParsers.parseMany2oneId(json['project_manager_id']) ??
        OdooFieldParsers.parseMany2oneId(json['project_manager']) ??
        OdooFieldParsers.parseMany2oneId(json['manager_id']) ??
        OdooFieldParsers.parseMany2oneId(json['x_project_manager']) ??
        OdooFieldParsers.parseId(json['x_project_manager_id']) ??
        OdooFieldParsers.parseId(json['employee_id']);
    final pmName = OdooFieldParsers.readString(
      json['project_manager_name'] ??
          json['manager_name'] ??
          json['project_manager'],
    );

    final cityIdRaw = json['city_id'] ?? json['city'];
    final cityId = OdooFieldParsers.parseMany2oneId(cityIdRaw);
    final cityName = OdooFieldParsers.readString(
      json['city_name'] ?? json['location_id'] ?? cityIdRaw,
    );

    final partnerName = OdooFieldParsers.readString(
      json['partner_name'] ?? json['partner_id'],
    );

    return ProjectModel(
      projectId: json['project_id'] ?? 0,
      partnerId: json['partner_id'].toString(),
      agreementId: json['agreement_id'].toString(),
      woRefNo: json['wo_ref_no'] ?? '',
      name: json['name']?.toString() ?? '',
      woAmount: (json['wo_amount'] as num?)?.toDouble() ?? 0.0,
      projectStatus: json['project_status']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      dateStart: json['date_start']?.toString() ?? '',
      differenceDays: json['difference_days'] as int?,
      projectManagerPhoto: managerPhoto ?? projectManagerPhoto,
      projectManagerId: pmId,
      projectManagerName: pmName.isNotEmpty ? pmName : null,
      projectStatusCompute:
          OdooFieldParsers.readString(json['project_status_compute']).isEmpty
              ? null
              : OdooFieldParsers.readString(json['project_status_compute']),
      projectNameArabic:
          OdooFieldParsers.readString(json['project_name_arabic']).isEmpty
              ? null
              : OdooFieldParsers.readString(json['project_name_arabic']),
      woTypeNoOffice: () {
        final noOffice =
            OdooFieldParsers.readString(json['wo_type_no_office']);
        if (noOffice.isNotEmpty) return noOffice;
        final woType = OdooFieldParsers.readString(json['wo_type']);
        return woType.isEmpty ? null : woType;
      }(),
      isInternalProject: () {
        final raw = json['x_internal_project'] ?? json['is_internal_project'];
        if (raw == true || raw == 1) return true;
        if (raw == false || raw == 0 || raw == null) return false;
        return raw.toString().trim().toLowerCase() == 'true';
      }(),
      partnerName: partnerName.isNotEmpty ? partnerName : null,
      cityId: cityId,
      cityName: cityName.isNotEmpty ? cityName : null,
      latitude: lat,
      longitude: lng,
      clientImageUrl: clientImageUrl,
      managerPhoto: managerPhoto,
      totalProgress: parseDouble(json['total_progress'] ?? json['progress']),
      contractorName: json['contractor']?.toString() ??
          json['contractor_name']?.toString() ??
          json['main_contractor']?.toString(),
      milestoneLabel: json['milestone']?.toString() ??
          json['next_milestone']?.toString() ??
          json['milestone_name']?.toString(),
      budgetLabel: json['budget']?.toString() ??
          json['contract_value']?.toString() ??
          json['total_budget']?.toString(),
      openIssuesCount: parseInt(json['open_issues'] ??
          json['issues_count'] ??
          json['issue_count']),
      supervisors: parseSupervisors(json['supervisors']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'project_id': projectId,
      'partner_id': partnerId,
      'agreement_id': agreementId,
      'wo_ref_no': woRefNo,
      'name': name,
      'wo_amount': woAmount,
      'project_status': projectStatus,
      'date': date,
      'date_start': dateStart,
      'difference_days': differenceDays,
      'project_manager_photo': projectManagerPhoto,
      'x_pr_lat': latitude,
      'x_pr_long': longitude,
      'latitude': latitude,
      'longitude': longitude,
      'client_image': clientImageUrl,
      'manager_photo': managerPhoto,
      'project_manager_name': projectManagerName,
      'total_progress': totalProgress,
      'contractor_name': contractorName,
      'milestone': milestoneLabel,
      'budget': budgetLabel,
      'open_issues': openIssuesCount,
      'supervisors': supervisors
          .map(
            (s) => {
              'employee_id': s.employeeId,
              'employee_name': s.employeeName,
              'emp_code': s.empCode,
              'job_id': s.jobId,
              'status': s.status,
              'photo': s.photo,
            },
          )
          .toList(),
    };
  }
}
