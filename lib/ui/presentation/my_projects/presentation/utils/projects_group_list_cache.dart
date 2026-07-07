import 'package:el_race/ui/presentation/my_projects/data/models/project_manager_filter_item.dart';

/// In-memory cache for `clients/list` group-by responses (per session).
class ProjectsGroupListCache {
  ProjectsGroupListCache._();

  static final ProjectsGroupListCache instance = ProjectsGroupListCache._();

  final Map<String, List<ProjectManagerFilterItem>> _byGroup = {};

  List<ProjectManagerFilterItem>? get(String groupBy) => _byGroup[groupBy];

  void put(String groupBy, List<ProjectManagerFilterItem> items) {
    _byGroup[groupBy] = items;
  }

  void clear() => _byGroup.clear();
}
