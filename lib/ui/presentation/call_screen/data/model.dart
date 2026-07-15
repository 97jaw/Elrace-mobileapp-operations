// To parse this JSON data, do
//
//     final employeeModel = employeeModelFromJson(jsonString);

import 'dart:convert';

EmployeeModel employeeModelFromJson(String str) =>
    EmployeeModel.fromJson(json.decode(str));

String employeeModelToJson(EmployeeModel data) => json.encode(data.toJson());

class EmployeeModel {
  final String? jsonrpc;
  final dynamic id;
  final Result? result;

  EmployeeModel({
    this.jsonrpc,
    this.id,
    this.result,
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) => EmployeeModel(
        jsonrpc: json["jsonrpc"],
        id: json["id"],
        result: json["result"] == null ? null : Result.fromJson(json["result"]),
      );

  Map<String, dynamic> toJson() => {
        "jsonrpc": jsonrpc,
        "id": id,
        "result": result?.toJson(),
      };
}

class Result {
  final List<Employee>? employees;

  Result({
    this.employees,
  });

  factory Result.fromJson(Map<String, dynamic> json) => Result(
        employees: json["employees"] == null
            ? []
            : List<Employee>.from(
                json["employees"]!.map((x) => Employee.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "employees": employees == null
            ? []
            : List<dynamic>.from(employees!.map((x) => x.toJson())),
      };
}

class Employee {
  final int? id;
  /// Odoo `hr.employee` database id (use for profile fetch).
  final int? employeeId;
  final String? name;
  final dynamic mobilePhone;
  final dynamic jobId;
  final String? profilePhotoUrl;
  final String? empId;
  final String? department;

  Employee({
    this.id,
    this.employeeId,
    this.name,
    this.mobilePhone,
    this.jobId,
    this.profilePhotoUrl,
    this.empId,
    this.department,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    // Extract employee ID from name (format: "2879 Name Surname")
    String? extractedEmpId;
    final name = json["name"]?.toString();
    if (name != null && name.isNotEmpty) {
      final parts = name.split(' ');
      if (parts.isNotEmpty) {
        // Check if first part is a number
        final firstPart = parts[0];
        if (int.tryParse(firstPart) != null) {
          extractedEmpId = firstPart;
        }
      }
    }

    final job = json["job_position"] ??
        json["job_id"] ??
        json["job"] ??
        json["designation"];
    final department = json["department_name"] ??
        json["department"] ??
        json["department_id"];

    final odooId = json["employee_id"] ?? json["odoo_employee_id"];
    return Employee(
      id: json["id"] is int
          ? json["id"] as int
          : int.tryParse('${json["id"] ?? ''}'),
      employeeId: odooId is int ? odooId : int.tryParse('${odooId ?? ''}'),
      name: json["name"]?.toString(),
      mobilePhone: json["mobile_phone"],
      jobId: job,
      profilePhotoUrl: json["profile_photo_url"]?.toString() ??
          json["image_url"]?.toString(),
      empId: json["emp_id"]?.toString() ??
          json["file_id"]?.toString() ??
          extractedEmpId,
      department: department?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "employee_id": employeeId,
        "name": name,
        "mobile_phone": mobilePhone,
        "job_id": jobId,
        "emp_id": empId,
        "profile_photo_url": profilePhotoUrl,
        "department": department,
      };
}
