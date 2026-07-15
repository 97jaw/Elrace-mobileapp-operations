class EmployeeProfileKpiQuota {
  const EmployeeProfileKpiQuota({
    required this.value,
    this.subtitle,
  });

  final String value;
  final String? subtitle;

  factory EmployeeProfileKpiQuota.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const EmployeeProfileKpiQuota(value: '—');
    }
    return EmployeeProfileKpiQuota(
      value: '${json['value'] ?? '—'}',
      subtitle: json['subtitle']?.toString(),
    );
  }
}

class EmployeeProfileKpis {
  const EmployeeProfileKpis({
    required this.workingDays,
    required this.leaveBalance,
    required this.sickLeave,
    required this.tempPermission,
    required this.annualShort,
    required this.expiredDocuments,
  });

  final String workingDays;
  final String leaveBalance;
  final String sickLeave;
  final EmployeeProfileKpiQuota tempPermission;
  final EmployeeProfileKpiQuota annualShort;
  final String expiredDocuments;

  factory EmployeeProfileKpis.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const EmployeeProfileKpis(
        workingDays: '—',
        leaveBalance: '—',
        sickLeave: '—',
        tempPermission: EmployeeProfileKpiQuota(value: '—'),
        annualShort: EmployeeProfileKpiQuota(value: '—'),
        expiredDocuments: '—',
      );
    }
    return EmployeeProfileKpis(
      workingDays: '${json['working_days'] ?? '—'}',
      leaveBalance: '${json['leave_balance'] ?? '—'}',
      sickLeave: '${json['sick_leave'] ?? '—'}',
      tempPermission: EmployeeProfileKpiQuota.fromJson(
        json['temp_permission'] is Map
            ? Map<String, dynamic>.from(json['temp_permission'] as Map)
            : null,
      ),
      annualShort: EmployeeProfileKpiQuota.fromJson(
        json['annual_short'] is Map
            ? Map<String, dynamic>.from(json['annual_short'] as Map)
            : null,
      ),
      expiredDocuments: '${json['expired_documents'] ?? '—'}',
    );
  }
}

class EmployeeProfileInfo {
  const EmployeeProfileInfo({
    this.directManager,
    this.joiningDate,
    this.evaluation,
    this.education,
    this.graduationYear,
    this.experienceYears,
    this.visaCo,
    this.email,
    this.country,
    this.countryCode,
  });

  final String? directManager;
  final String? joiningDate;
  final String? evaluation;
  final String? education;
  final String? graduationYear;
  final String? experienceYears;
  final String? visaCo;
  final String? email;
  final String? country;
  final String? countryCode;

  factory EmployeeProfileInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const EmployeeProfileInfo();
    return EmployeeProfileInfo(
      directManager: json['direct_manager']?.toString(),
      joiningDate: json['joining_date']?.toString(),
      evaluation: json['evaluation']?.toString(),
      education: json['education']?.toString(),
      graduationYear: json['graduation_year']?.toString(),
      experienceYears: json['experience_years']?.toString(),
      visaCo: json['visa_co']?.toString(),
      email: json['email']?.toString(),
      country: json['country']?.toString(),
      countryCode: json['country_code']?.toString(),
    );
  }
}

class EmployeeProfileDetail {
  const EmployeeProfileDetail({
    required this.employeeId,
    required this.empId,
    required this.name,
    this.arabicName,
    this.profilePhotoUrl,
    this.jobTitle,
    this.positionType,
    this.department,
    this.section,
    this.mobilePhone,
    this.workEmail,
    required this.kpis,
    required this.info,
  });

  final int employeeId;
  final String empId;
  final String name;
  final String? arabicName;
  final String? profilePhotoUrl;
  final String? jobTitle;
  final String? positionType;
  final String? department;
  final String? section;
  final String? mobilePhone;
  final String? workEmail;
  final EmployeeProfileKpis kpis;
  final EmployeeProfileInfo info;

  factory EmployeeProfileDetail.fromJson(Map<String, dynamic> json) {
    final result = json['result'] is Map
        ? Map<String, dynamic>.from(json['result'] as Map)
        : json;
    final data = result['data'] is Map
        ? Map<String, dynamic>.from(result['data'] as Map)
        : result;

    return EmployeeProfileDetail(
      employeeId: data['employee_id'] is int
          ? data['employee_id'] as int
          : int.tryParse('${data['employee_id'] ?? 0}') ?? 0,
      empId: '${data['emp_id'] ?? ''}',
      name: '${data['name'] ?? ''}',
      arabicName: data['arabic_name']?.toString(),
      profilePhotoUrl: data['profile_photo_url']?.toString(),
      jobTitle: data['job_title']?.toString(),
      positionType: data['position_type']?.toString(),
      department: data['department']?.toString(),
      section: data['section']?.toString(),
      mobilePhone: data['mobile_phone']?.toString(),
      workEmail: data['work_email']?.toString(),
      kpis: EmployeeProfileKpis.fromJson(
        data['kpis'] is Map
            ? Map<String, dynamic>.from(data['kpis'] as Map)
            : null,
      ),
      info: EmployeeProfileInfo.fromJson(
        data['info'] is Map
            ? Map<String, dynamic>.from(data['info'] as Map)
            : null,
      ),
    );
  }
}

Map<String, dynamic> _unwrapProfilePayload(Map<String, dynamic> json) {
  final result = json['result'] is Map
      ? Map<String, dynamic>.from(json['result'] as Map)
      : json;
  if (result['data'] is Map) {
    return Map<String, dynamic>.from(result['data'] as Map);
  }
  return result;
}

class EmployeeProfileMini {
  const EmployeeProfileMini({
    required this.employeeId,
    required this.empId,
    required this.name,
    this.jobTitle,
    this.department,
    this.section,
    this.mobilePhone,
    this.workEmail,
  });

  final int employeeId;
  final String empId;
  final String name;
  final String? jobTitle;
  final String? department;
  final String? section;
  final String? mobilePhone;
  final String? workEmail;

  factory EmployeeProfileMini.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const EmployeeProfileMini(employeeId: 0, empId: '', name: '');
    }
    return EmployeeProfileMini(
      employeeId: json['employee_id'] is int
          ? json['employee_id'] as int
          : int.tryParse('${json['employee_id'] ?? 0}') ?? 0,
      empId: '${json['emp_id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      jobTitle: json['job_title']?.toString(),
      department: json['department']?.toString(),
      section: json['section']?.toString(),
      mobilePhone: json['mobile_phone']?.toString(),
      workEmail: json['work_email']?.toString(),
    );
  }
}

class EmployeeContractSalary {
  const EmployeeContractSalary({
    required this.basicSalary,
    required this.allowanceTotal,
    required this.timesheetCost,
    required this.benefits,
    required this.totalSalary,
  });

  final double basicSalary;
  final double allowanceTotal;
  final double timesheetCost;
  final double benefits;
  final double totalSalary;

  factory EmployeeContractSalary.fromJson(Map<String, dynamic>? json) {
    double n(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    if (json == null) {
      return const EmployeeContractSalary(
        basicSalary: 0,
        allowanceTotal: 0,
        timesheetCost: 0,
        benefits: 0,
        totalSalary: 0,
      );
    }
    return EmployeeContractSalary(
      basicSalary: n(json['basic_salary']),
      allowanceTotal: n(json['allowance_total']),
      timesheetCost: n(json['timesheet_cost']),
      benefits: n(json['benefits']),
      totalSalary: n(json['total_salary']),
    );
  }
}

class EmployeeContractAmountRow {
  const EmployeeContractAmountRow({this.date, required this.amount});

  final String? date;
  final double amount;

  factory EmployeeContractAmountRow.fromJson(Map<String, dynamic> json) {
    final amount = json['amount'];
    return EmployeeContractAmountRow(
      date: json['date']?.toString(),
      amount: amount is num
          ? amount.toDouble()
          : double.tryParse('$amount') ?? 0,
    );
  }
}

class EmployeeContractDetail {
  const EmployeeContractDetail({
    required this.employee,
    this.contractId,
    this.salary,
    required this.incrementHistory,
    required this.bonuses,
  });

  final EmployeeProfileMini employee;
  final int? contractId;
  final EmployeeContractSalary? salary;
  final List<EmployeeContractAmountRow> incrementHistory;
  final List<EmployeeContractAmountRow> bonuses;

  factory EmployeeContractDetail.fromJson(Map<String, dynamic> json) {
    final data = _unwrapProfilePayload(json);
    final increments = (data['increment_history'] is List)
        ? (data['increment_history'] as List)
            .whereType<Map>()
            .map((e) => EmployeeContractAmountRow.fromJson(
                  Map<String, dynamic>.from(e),
                ))
            .toList()
        : <EmployeeContractAmountRow>[];
    final bonuses = (data['bonuses'] is List)
        ? (data['bonuses'] as List)
            .whereType<Map>()
            .map((e) => EmployeeContractAmountRow.fromJson(
                  Map<String, dynamic>.from(e),
                ))
            .toList()
        : <EmployeeContractAmountRow>[];
    return EmployeeContractDetail(
      employee: EmployeeProfileMini.fromJson(
        data['employee'] is Map
            ? Map<String, dynamic>.from(data['employee'] as Map)
            : null,
      ),
      contractId: data['contract_id'] is int
          ? data['contract_id'] as int
          : int.tryParse('${data['contract_id'] ?? ''}'),
      salary: data['salary'] is Map
          ? EmployeeContractSalary.fromJson(
              Map<String, dynamic>.from(data['salary'] as Map),
            )
          : null,
      incrementHistory: increments,
      bonuses: bonuses,
    );
  }
}

class EmployeeProfileDocumentItem {
  const EmployeeProfileDocumentItem({
    required this.id,
    required this.name,
    this.documentType,
    this.issueDate,
    this.expiryDate,
    this.description,
    required this.isFamily,
    required this.status,
  });

  final int id;
  final String name;
  final String? documentType;
  final String? issueDate;
  final String? expiryDate;
  final String? description;
  final bool isFamily;
  final String status;

  factory EmployeeProfileDocumentItem.fromJson(Map<String, dynamic> json) {
    return EmployeeProfileDocumentItem(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id'] ?? 0}') ?? 0,
      name: '${json['name'] ?? ''}',
      documentType: json['document_type']?.toString(),
      issueDate: json['issue_date']?.toString(),
      expiryDate: json['expiry_date']?.toString(),
      description: json['description']?.toString(),
      isFamily: json['is_family'] == true,
      status: '${json['status'] ?? 'valid'}',
    );
  }
}

class EmployeeDocumentsDetail {
  const EmployeeDocumentsDetail({
    required this.employee,
    required this.documents,
    required this.total,
    required this.family,
    required this.nonFamily,
  });

  final EmployeeProfileMini employee;
  final List<EmployeeProfileDocumentItem> documents;
  final int total;
  final int family;
  final int nonFamily;

  factory EmployeeDocumentsDetail.fromJson(Map<String, dynamic> json) {
    final data = _unwrapProfilePayload(json);
    final docs = (data['documents'] is List)
        ? (data['documents'] as List)
            .whereType<Map>()
            .map((e) => EmployeeProfileDocumentItem.fromJson(
                  Map<String, dynamic>.from(e),
                ))
            .toList()
        : <EmployeeProfileDocumentItem>[];
    final summary = data['summary'] is Map
        ? Map<String, dynamic>.from(data['summary'] as Map)
        : const <String, dynamic>{};
    return EmployeeDocumentsDetail(
      employee: EmployeeProfileMini.fromJson(
        data['employee'] is Map
            ? Map<String, dynamic>.from(data['employee'] as Map)
            : null,
      ),
      documents: docs,
      total: int.tryParse('${summary['total'] ?? docs.length}') ?? docs.length,
      family: int.tryParse('${summary['family'] ?? 0}') ?? 0,
      nonFamily: int.tryParse('${summary['non_family'] ?? 0}') ?? 0,
    );
  }
}

class EmployeeFleetVehicle {
  const EmployeeFleetVehicle({
    required this.id,
    this.model,
    this.licensePlate,
    this.name,
  });

  final int id;
  final String? model;
  final String? licensePlate;
  final String? name;

  factory EmployeeFleetVehicle.fromJson(Map<String, dynamic> json) {
    return EmployeeFleetVehicle(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id'] ?? 0}') ?? 0,
      model: json['model']?.toString(),
      licensePlate: json['license_plate']?.toString(),
      name: json['name']?.toString(),
    );
  }
}

class EmployeeFleetDetail {
  const EmployeeFleetDetail({
    required this.employee,
    required this.vehicles,
  });

  final EmployeeProfileMini employee;
  final List<EmployeeFleetVehicle> vehicles;

  factory EmployeeFleetDetail.fromJson(Map<String, dynamic> json) {
    final data = _unwrapProfilePayload(json);
    final vehicles = (data['vehicles'] is List)
        ? (data['vehicles'] as List)
            .whereType<Map>()
            .map((e) =>
                EmployeeFleetVehicle.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <EmployeeFleetVehicle>[];
    return EmployeeFleetDetail(
      employee: EmployeeProfileMini.fromJson(
        data['employee'] is Map
            ? Map<String, dynamic>.from(data['employee'] as Map)
            : null,
      ),
      vehicles: vehicles,
    );
  }
}
