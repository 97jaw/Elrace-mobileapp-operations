import 'timesheet_model_parsers.dart';

class SitePhoto {
  const SitePhoto({
    required this.id,
    required this.projectId,
    required this.foremanId,
    required this.ts,
    required this.category,
    required this.caption,
    required this.lat,
    required this.lon,
    required this.storageUrl,
  });

  final String id;
  final String projectId;
  final String foremanId;
  final DateTime? ts;
  final String category;
  final String caption;
  final double lat;
  final double lon;
  final String storageUrl;

  factory SitePhoto.fromJson(Map<String, dynamic> json) {
    return SitePhoto(
      id: tmStringFromJson(json['id']),
      projectId: tmStringFromJson(json['project_id']),
      foremanId: tmStringFromJson(json['foreman_id']),
      ts: tmDateTimeFromJson(json['ts']),
      category: tmStringFromJson(json['category']),
      caption: tmStringFromJson(json['caption']),
      lat: tmDoubleFromJson(json['lat']),
      lon: tmDoubleFromJson(json['lon']),
      storageUrl: tmStringFromJson(json['storage_url']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'foreman_id': foremanId,
      'ts': tmDateTimeToJson(ts),
      'category': category,
      'caption': caption,
      'lat': lat,
      'lon': lon,
      'storage_url': storageUrl,
    };
  }
}
