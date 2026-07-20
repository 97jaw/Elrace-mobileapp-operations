import 'package:hive/hive.dart';

part 'report_model.g.dart';

@HiveType(typeId: 105) // <-- make sure this is unique across your app
class ReportModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  /// Optional: to be removed in the future
  @HiveField(2)
  final String companyId;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final String folderId;

  @HiveField(5)
  final DateTime updatedAt;

  @HiveField(6)
  final String? reportType;

  /// Set on the report record after PDF upload (`report.management.report.report_link`).
  final String? reportLink;

  /// Preview image URLs from list API (max 3); not persisted in Hive.
  final List<String> latestItemImages;

  ReportModel({
    required this.id,
    required this.name,
    required this.companyId,
    required this.folderId,
    required this.createdAt,
    required this.updatedAt,
    this.reportType,
    this.reportLink,
    this.latestItemImages = const [],
  });

  bool get hasGeneratedPdf =>
      reportLink != null && reportLink!.trim().isNotEmpty;

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    final parsedLatestItemImages = (json['latest_items'] is List)
        ? (json['latest_items'] as List)
            .whereType<Map>()
            .map((item) {
              final image = item['item_data'];
              if (image == null || image == false) return '';
              return image.toString().trim();
            })
            .where((image) => image.isNotEmpty)
            .take(3)
            .toList()
        : <String>[];

    return ReportModel(
      id: json['id'].toString(),
      name: (json['name'] ?? '').toString(),
      folderId: (json['folder_id'] ?? '').toString(),
      companyId: (json['company_id'] == false || json['company_id'] == null)
          ? ''
          : json['company_id'].toString(),
      createdAt: DateTime.tryParse(
              (json['created_at'] ?? json['create_at'] ?? '').toString()) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse((json['updated_at'] ??
                  json['created_at'] ??
                  json['create_at'] ??
                  '')
              .toString()) ??
          DateTime.now(),
      reportType: (json['report_type'] != null && json['report_type'] != false)
          ? json['report_type'].toString()
          : null,
      reportLink: _optionalString(json['report_link']),
      latestItemImages: parsedLatestItemImages,
    );
  }

  static String? _optionalString(Object? value) {
    if (value == null || value == false) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'company_id': companyId,
      'folder_id': folderId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'report_type': reportType,
    };
  }

  ReportModel copyWith({
    String? id,
    String? name,
    String? companyId,
    String? folderId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? reportType,
    String? reportLink,
    List<String>? latestItemImages,
  }) {
    return ReportModel(
      id: id ?? this.id,
      name: name ?? this.name,
      companyId: companyId ?? this.companyId,
      folderId: folderId ?? this.folderId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reportType: reportType ?? this.reportType,
      reportLink: reportLink ?? this.reportLink,
      latestItemImages: latestItemImages ?? this.latestItemImages,
    );
  }
}
