import 'package:el_race/ui/presentation/my_projects/data/models/project_manager_filter_item.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_manager_filter_item_extensions.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_model.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/odoo_field_parsers.dart';

/// Patches PM group rows when `clients/list` returns id=0 / "No Manager".
abstract final class ProjectsGroupManagerEnricher {
  static String _norm(String? value) =>
      (value ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static Map<String, int> _nameToEmployeeId(List<ProjectModel> projects) {
    final map = <String, int>{};
    for (final p in projects) {
      final id = p.projectManagerId;
      final name = _norm(p.projectManagerName);
      if (id != null && id > 0 && name.isNotEmpty) {
        map[name] = id;
      }
    }
    return map;
  }

  static Map<String, String> _nameToPhoto(List<ProjectModel> projects) {
    final map = <String, String>{};
    for (final p in projects) {
      final name = _norm(p.projectManagerName);
      final photo = p.managerPhoto ?? p.projectManagerPhoto;
      if (name.isNotEmpty && photo != null && photo.isNotEmpty) {
        map[name] = photo;
      }
    }
    return map;
  }

  static List<ProjectManagerFilterItem> enrichFromProjects({
    required List<ProjectManagerFilterItem> apiRows,
    required List<ProjectModel> projects,
  }) {
    if (apiRows.isEmpty || projects.isEmpty) return apiRows;

    final nameToId = _nameToEmployeeId(projects);
    final nameToPhoto = _nameToPhoto(projects);

    return apiRows.map((row) {
      var id = row.id;
      var name = row.name.trim();
      var photo = row.photoUrl;

      final normName = _norm(name);
      final looksUnassigned =
          id <= 0 || OdooFieldParsers.isNoManagerLabel(name);

      if (looksUnassigned && normName.isNotEmpty && nameToId.containsKey(normName)) {
        id = nameToId[normName]!;
      } else if (looksUnassigned) {
        // Try matching API label against project manager names.
        for (final entry in nameToId.entries) {
          if (entry.key.contains(normName) || normName.contains(entry.key)) {
            id = entry.value;
            name = projects
                    .firstWhere(
                      (p) => p.projectManagerId == id,
                      orElse: () => projects.first,
                    )
                    .projectManagerName ??
                name;
            break;
          }
        }
      }

      if ((photo == null || photo.isEmpty) && nameToPhoto.containsKey(_norm(name))) {
        photo = nameToPhoto[_norm(name)];
      }

      if (OdooFieldParsers.isNoManagerLabel(name) && id > 0) {
        name = 'Manager #$id';
      }

      return row.copyWith(id: id, name: name, photoUrl: photo);
    }).toList();
  }
}
