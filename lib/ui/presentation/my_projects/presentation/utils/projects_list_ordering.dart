import 'package:el_race/ui/presentation/my_projects/data/models/project_documents_models.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_model.dart';
import 'package:el_race/ui/presentation/my_projects/domain/entities/project_entity.dart';

/// Shared newest-first ordering for My Projects listing records.
///
/// Uses higher [projectId] first (`id desc`) so client order matches the API
/// order param and stays safe with limit/offset pagination.
class ProjectsListOrdering {
  ProjectsListOrdering._();

  /// Odoo-style order string accepted by many list endpoints.
  static const String apiOrder = 'id desc';

  /// Adds order params without overriding an explicit caller value.
  static void applyApiOrderParams(Map<String, dynamic> params) {
    params.putIfAbsent('order', () => apiOrder);
    params.putIfAbsent('sort', () => 'desc');
  }

  static DateTime _parseDate(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
    final normalized = value.contains(' ') ? value.replaceFirst(' ', 'T') : value;
    return DateTime.tryParse(normalized) ??
        DateTime.tryParse(value) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  static int compareModelsDesc(ProjectModel a, ProjectModel b) {
    final byId = b.projectId.compareTo(a.projectId);
    if (byId != 0) return byId;
    final byStart = _parseDate(b.dateStart).compareTo(_parseDate(a.dateStart));
    if (byStart != 0) return byStart;
    return _parseDate(b.date).compareTo(_parseDate(a.date));
  }

  static int compareEntitiesDesc(ProjectEntity a, ProjectEntity b) {
    final byId = b.projectId.compareTo(a.projectId);
    if (byId != 0) return byId;
    final byStart = _parseDate(b.dateStart).compareTo(_parseDate(a.dateStart));
    if (byStart != 0) return byStart;
    return _parseDate(b.date).compareTo(_parseDate(a.date));
  }

  static int compareDocumentProjectsDesc(
    ProjectDocumentFolderProject a,
    ProjectDocumentFolderProject b,
  ) {
    final byId = b.projectId.compareTo(a.projectId);
    if (byId != 0) return byId;
    return _parseDate(b.lastUpdated).compareTo(_parseDate(a.lastUpdated));
  }

  static List<ProjectModel> sortModelsDesc(Iterable<ProjectModel> input) {
    final out = List<ProjectModel>.from(input);
    out.sort(compareModelsDesc);
    return out;
  }

  static List<ProjectEntity> sortEntitiesDesc(Iterable<ProjectEntity> input) {
    final out = List<ProjectEntity>.from(input);
    out.sort(compareEntitiesDesc);
    return out;
  }

  static List<ProjectDocumentFolderProject> sortDocumentProjectsDesc(
    Iterable<ProjectDocumentFolderProject> input,
  ) {
    final out = List<ProjectDocumentFolderProject>.from(input);
    out.sort(compareDocumentProjectsDesc);
    return out;
  }
}
