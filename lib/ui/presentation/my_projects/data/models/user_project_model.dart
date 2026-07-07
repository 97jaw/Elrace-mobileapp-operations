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
      totalProjects: json['total_projects'] as int? ?? 0,
      totalProjectsAmount:
          (json['total_projects_amount'] as num?)?.toDouble() ?? 0.0,
      photoUrl: photoUrl,
      agreementId: parseId(agreementIdValue),
      agreementNo: json['agreement_no']?.toString(),
      agreementName: json['agreement_name']?.toString(),
      cityId: json['city_id'] is List && (json['city_id'] as List).length > 1
          ? (json['city_id'] as List)[1]?.toString()
          : json['city_id']?.toString(),
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
    };
  }
}
