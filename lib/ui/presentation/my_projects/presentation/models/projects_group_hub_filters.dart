/// Active filters for the unified group-by hub.
class ProjectsGroupHubFilters {
  const ProjectsGroupHubFilters({
    this.year,
    this.month,
    this.projectStatusCompute,
    this.woRefNo,
    this.woTypeNoOffice,
    this.searchName,
  });

  final int? year;
  final int? month;

  /// Maps to Odoo `project_status_compute`.
  final String? projectStatusCompute;

  /// Maps to Odoo `wo_ref_no`.
  final String? woRefNo;

  /// Maps to Odoo `wo_type_no_office` — `active` or `pending`.
  final String? woTypeNoOffice;

  /// Search `name` OR `project_name_arabic` (OR on backend).
  final String? searchName;

  bool get hasActiveFilters =>
      year != null ||
      month != null ||
      (projectStatusCompute?.isNotEmpty == true) ||
      (woRefNo?.trim().isNotEmpty == true) ||
      (woTypeNoOffice?.isNotEmpty == true) ||
      (searchName?.trim().isNotEmpty == true);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProjectsGroupHubFilters &&
        other.year == year &&
        other.month == month &&
        other.projectStatusCompute == projectStatusCompute &&
        other.woRefNo == woRefNo &&
        other.woTypeNoOffice == woTypeNoOffice &&
        other.searchName == searchName;
  }

  @override
  int get hashCode => Object.hash(
        year,
        month,
        projectStatusCompute,
        woRefNo,
        woTypeNoOffice,
        searchName,
      );

  ProjectsGroupHubFilters copyWith({
    int? year,
    int? month,
    String? projectStatusCompute,
    String? woRefNo,
    String? woTypeNoOffice,
    String? searchName,
    bool clearAll = false,
  }) {
    if (clearAll) return const ProjectsGroupHubFilters();
    return ProjectsGroupHubFilters(
      year: year ?? this.year,
      month: month ?? this.month,
      projectStatusCompute: projectStatusCompute ?? this.projectStatusCompute,
      woRefNo: woRefNo ?? this.woRefNo,
      woTypeNoOffice: woTypeNoOffice ?? this.woTypeNoOffice,
      searchName: searchName ?? this.searchName,
    );
  }

  Map<String, dynamic> toApiParams() {
    final params = <String, dynamic>{};
    if (year != null) params['year'] = year;
    if (month != null) params['month'] = month;
    if (projectStatusCompute != null &&
        projectStatusCompute!.trim().isNotEmpty) {
      params['project_status_compute'] = projectStatusCompute!.trim();
    }
    final wo = woRefNo?.trim();
    if (wo != null && wo.isNotEmpty) params['wo_ref_no'] = wo;
    if (woTypeNoOffice != null && woTypeNoOffice!.trim().isNotEmpty) {
      params['wo_type_no_office'] = woTypeNoOffice!.trim();
    }
    final q = searchName?.trim();
    if (q != null && q.isNotEmpty) {
      params['name'] = q;
      params['search_name'] = q;
    }
    return params;
  }
}

enum ProjectsGroupByMode {
  projectManager('project_manager'),
  client('client'),
  city('city');

  const ProjectsGroupByMode(this.apiValue);
  final String apiValue;
}

/// WO type values for `wo_type_no_office`.
abstract final class ProjectsWoTypeFilter {
  static const active = 'active';
  static const pending = 'pending';
}
