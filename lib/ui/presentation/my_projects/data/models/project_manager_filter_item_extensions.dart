import 'package:el_race/ui/presentation/my_projects/data/models/project_manager_filter_item.dart';

extension ProjectManagerFilterItemCopy on ProjectManagerFilterItem {
  ProjectManagerFilterItem copyWith({
    int? id,
    String? name,
    String? photoUrl,
    int? projectCount,
    String? lastUpdate,
  }) {
    return ProjectManagerFilterItem(
      id: id ?? this.id,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      projectCount: projectCount ?? this.projectCount,
      lastUpdate: lastUpdate ?? this.lastUpdate,
    );
  }
}
