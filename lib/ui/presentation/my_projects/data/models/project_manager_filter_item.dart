import 'package:el_race/ui/presentation/my_projects/presentation/utils/odoo_field_parsers.dart';

class ProjectManagerFilterItem {
  const ProjectManagerFilterItem({
    required this.id,
    required this.name,
    required this.photoUrl,
    required this.projectCount,
    required this.lastUpdate,
  });

  final int id;
  final String name;
  final String? photoUrl;
  final int projectCount;
  final String? lastUpdate;

  factory ProjectManagerFilterItem.fromJson(Map<String, dynamic> json) {
    final rawPhoto = json['photo_url']?.toString() ??
        json['project_manager_photo']?.toString() ??
        json['manager_photo']?.toString();
    final normalizedPhoto = (rawPhoto != null &&
            rawPhoto.contains('erp.elrace.compublic'))
        ? rawPhoto.replaceAll('erp.elrace.compublic', 'erp.elrace.com/public')
        : rawPhoto;

    final managerId = OdooFieldParsers.parseMany2oneId(
          json['project_manager_id'] ?? json['project_manager'],
        ) ??
        OdooFieldParsers.parseMany2oneId(json['employee_id']) ??
        OdooFieldParsers.parseMany2oneId(json['manager_id']);

    final genericId = OdooFieldParsers.parseMany2oneId(json['id']) ?? 0;
    final id = (managerId != null && managerId > 0) ? managerId : genericId;

    var name = OdooFieldParsers.readString(
      json['project_manager_name'] ??
          json['manager_name'] ??
          json['display_name'] ??
          json['project_manager'] ??
          json['name'],
    );

    if (OdooFieldParsers.isNoManagerLabel(name) && id > 0) {
      name = 'Manager #$id';
    }

    return ProjectManagerFilterItem(
      id: id,
      name: name,
      photoUrl: normalizedPhoto,
      projectCount: json['project_count'] is int
          ? json['project_count'] as int
          : int.tryParse((json['project_count'] ?? '').toString()) ?? 0,
      lastUpdate: json['last_update']?.toString(),
    );
  }
}
