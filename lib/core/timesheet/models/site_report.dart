import 'timesheet_model_parsers.dart';

class SiteReport {
  const SiteReport({
    required this.id,
    required this.projectId,
    required this.date,
    required this.weather,
    required this.manpower,
    required this.workPerformed,
    required this.issues,
    required this.materials,
    required this.equipment,
    required this.photoUrls,
    required this.signatureUrl,
    required this.pdfUrl,
    required this.uiStatus,
  });

  final String id;
  final String projectId;
  final DateTime? date;
  final String weather;
  final int manpower;
  final String workPerformed;
  final String issues;
  final String materials;
  final String equipment;
  final List<String> photoUrls;
  final String signatureUrl;
  final String pdfUrl;
  final String uiStatus;

  factory SiteReport.fromJson(Map<String, dynamic> json) {
    return SiteReport(
      id: tmStringFromJson(json['id']),
      projectId: tmStringFromJson(json['project_id']),
      date: tmDateTimeFromJson(json['date']),
      weather: tmStringFromJson(json['weather']),
      manpower: tmIntFromJson(json['manpower']),
      workPerformed: tmStringFromJson(json['work_performed']),
      issues: tmStringFromJson(json['issues']),
      materials: tmStringFromJson(json['materials']),
      equipment: tmStringFromJson(json['equipment']),
      photoUrls: tmStringListFromJson(json['photo_urls']),
      signatureUrl: tmStringFromJson(json['signature_url']),
      pdfUrl: tmStringFromJson(json['pdf_url']),
      uiStatus: tmStringFromJson(json['ui_status']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'date': tmDateTimeToJson(date),
      'weather': weather,
      'manpower': manpower,
      'work_performed': workPerformed,
      'issues': issues,
      'materials': materials,
      'equipment': equipment,
      'photo_urls': photoUrls,
      'signature_url': signatureUrl,
      'pdf_url': pdfUrl,
      'ui_status': uiStatus,
    };
  }
}
