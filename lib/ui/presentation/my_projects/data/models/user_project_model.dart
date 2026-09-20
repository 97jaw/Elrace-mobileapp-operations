class UserProjectModel {
  final int projectId;
  final String projectName;
  final int totalProjects;
  final double totalProjectsAmount;
  final String? photoUrl;
  final int? agreementId;
  final String? agreementNo;
  final String? agreementName;
  final String? cityId;
  /// Latest project write date in the bucket (`last_update` from clients/list).
  final String? lastUpdate;

  const UserProjectModel({
    required this.projectId,
    required this.projectName,
    required this.totalProjects,
    required this.totalProjectsAmount,
    this.photoUrl,
    this.agreementId,
    this.agreementNo,
    this.agreementName,
    this.cityId,
    this.lastUpdate,
  });

  factory UserProjectModel.fromJson(Map<String, dynamic> json) {
    int? parseId(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is List && value.isNotEmpty) return parseId(value.first);
      if (value is Map) {
        return parseId(value['id'] ?? value['agreement_id']);
      }
      return int.tryParse(value?.toString() ?? '');
    }

    int parseCount(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    final idValue = json['id'];
    final agreementIdValue = json['agreement_id'] ??
        json['agreement'] ??
        json['agreementId'] ??
        json['project_agreement_id'];

    // Fix malformed photo URL from API (erp.elrace.compublic -> erp.elrace.com/public)
    String? photoUrl = json['photo_url']?.toString();
    if (photoUrl != null && photoUrl.contains('erp.elrace.compublic')) {
      photoUrl =
          photoUrl.replaceAll('erp.elrace.compublic', 'erp.elrace.com/public');
    }

    return UserProjectModel(
      projectId: idValue is int
          ? idValue
          : int.tryParse(idValue?.toString() ?? '') ?? 0,
      projectName: json['name']?.toString() ?? '',
      // agreement buckets use total_projects; client buckets use project_count
      totalProjects: parseCount(
        json['total_projects'] ?? json['project_count'],
      ),
      totalProjectsAmount:
          (json['total_projects_amount'] as num?)?.toDouble() ?? 0.0,
      photoUrl: photoUrl,
      agreementId: parseId(agreementIdValue),
      agreementNo: json['agreement_no']?.toString(),
      agreementName: json['agreement_name']?.toString(),
      cityId: json['city_id'] is List && (json['city_id'] as List).length > 1
          ? (json['city_id'] as List)[1]?.toString()
          : json['city_id']?.toString(),
      lastUpdate: json['last_update']?.toString() ??
          json['write_date']?.toString() ??
          json['date']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': projectId,
      'name': projectName,
      'total_projects': totalProjects,
      'total_projects_amount': totalProjectsAmount,
      'photo_url': photoUrl,
      'agreement_id': agreementId,
      'agreement_no': agreementNo,
      'agreement_name': agreementName,
      'city_id': cityId,
      'last_update': lastUpdate,
    };
  }
}
