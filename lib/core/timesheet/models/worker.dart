import 'timesheet_model_parsers.dart';

class Worker {
  const Worker({
    required this.id,
    required this.projectId,
    required this.name,
    required this.trade,
    required this.contact,
    required this.hourlyRate,
    required this.status,
    required this.faceId,
    required this.refPhotoUrls,
    this.odooEmployeeId,
  });

  final String id;
  final String projectId;
  final String name;
  final String trade;
  final String contact;
  final double hourlyRate;
  final String status;
  final String faceId;
  final List<String> refPhotoUrls;
  final int? odooEmployeeId;

  factory Worker.fromJson(Map<String, dynamic> json) {
    return Worker(
      id: tmStringFromJson(json['id']),
      projectId: tmStringFromJson(json['project_id']),
      name: tmStringFromJson(json['name']),
      trade: tmStringFromJson(json['trade']),
      contact: tmStringFromJson(json['contact']),
      hourlyRate: tmDoubleFromJson(json['hourly_rate']),
      status: tmStringFromJson(json['status']),
      faceId: tmStringFromJson(json['face_id']),
      refPhotoUrls: tmStringListFromJson(json['ref_photo_urls']),
      odooEmployeeId: tmIntOrNullFromJson(json['odoo_employee_id'] ?? json['employee_id']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'name': name,
      'trade': trade,
      'contact': contact,
      'hourly_rate': hourlyRate,
      'status': status,
      'face_id': faceId,
      'ref_photo_urls': refPhotoUrls,
      if (odooEmployeeId != null) 'odoo_employee_id': odooEmployeeId,
    };
  }
}
