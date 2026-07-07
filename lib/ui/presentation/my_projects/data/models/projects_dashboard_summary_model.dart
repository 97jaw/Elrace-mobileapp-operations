/// Portfolio KPIs from `GET /api/projects/dashboard_summary`.
class ProjectsDashboardSummaryModel {
  const ProjectsDashboardSummaryModel({
    required this.agreementsCount,
    required this.totalProjects,
    required this.delayedProjects,
    required this.inProgress,
    required this.completed,
    required this.totalValueAed,
    required this.invoiced,
    this.featuredClientPhoto,
  });

  final int agreementsCount;
  final int totalProjects;
  final int delayedProjects;
  final int inProgress;
  final int completed;
  final double totalValueAed;
  final int invoiced;
  final String? featuredClientPhoto;

  factory ProjectsDashboardSummaryModel.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic v) {
      if (v is double) return v;
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0.0;
    }

    int parseInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    String? photo = json['featured_client_photo']?.toString();
    if (photo != null && photo.contains('erp.elrace.compublic')) {
      photo = photo.replaceAll(
        'erp.elrace.compublic',
        'erp.elrace.com/public',
      );
    }

    return ProjectsDashboardSummaryModel(
      agreementsCount: parseInt(json['agreements_count']),
      totalProjects: parseInt(json['total_projects']),
      delayedProjects: parseInt(json['delayed_projects']),
      inProgress: parseInt(json['in_progress']),
      completed: parseInt(json['completed']),
      totalValueAed: parseDouble(json['total_value_aed']),
      invoiced: parseInt(
        json['invoiced'] ??
            json['invoiced_projects'] ??
            json['invoiced_count'],
      ),
      featuredClientPhoto: photo,
    );
  }
}
