class FaceDbVersionInfo {
  const FaceDbVersionInfo({
    required this.version,
    required this.modelVersion,
    this.totalEmployees = 0,
    this.lastUpdatedAt,
  });

  final int version;
  final String modelVersion;
  final int totalEmployees;
  final String? lastUpdatedAt;

  factory FaceDbVersionInfo.fromJson(Map<String, dynamic> json) {
    return FaceDbVersionInfo(
      version: _int(json['version']),
      modelVersion: json['model_version']?.toString() ?? 'mobilefacenet-v1',
      totalEmployees: _int(json['total_employees_with_embedding']),
      lastUpdatedAt: json['last_updated_at']?.toString(),
    );
  }

  static int _int(Object? v) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}
