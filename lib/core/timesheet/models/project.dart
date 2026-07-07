import 'timesheet_model_parsers.dart';

class Project {
  const Project({
    required this.id,
    required this.name,
    required this.code,
    required this.woRefNo,
    required this.client,
    required this.start,
    required this.end,
    required this.status,
    this.lastUpdate,
    required this.address,
    required this.heroImageUrl,
    required this.clientImageUrl,
    required this.progressPct,
    required this.budgetMin,
    required this.budgetMax,
    required this.geofenceLat,
    required this.geofenceLon,
    required this.geofenceRadiusM,
    required this.pmId,
    required this.foremanIds,
    required this.chatRoomId,
  });

  final String id;
  final String name;
  final String code;
  final String woRefNo;
  final String client;
  final DateTime? start;
  final DateTime? end;
  final String status;
  final DateTime? lastUpdate;
  final String address;
  final String heroImageUrl;
  final String clientImageUrl;
  final double progressPct;
  final double budgetMin;
  final double budgetMax;
  final double geofenceLat;
  final double geofenceLon;
  final double geofenceRadiusM;
  final String pmId;
  final List<String> foremanIds;
  final String chatRoomId;

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: tmStringFromJson(json['id']),
      name: tmStringFromJson(json['name']),
      code: tmStringFromJson(json['code'] ?? json['project_id']),
      woRefNo: tmStringFromJson(
        json['wo_ref_no'] ?? json['wo_ref'] ?? json['work_order_no'],
      ),
      client: tmStringFromJson(json['client']),
      start: tmDateTimeFromJson(json['start']),
      end: tmDateTimeFromJson(json['end']),
      status: tmStringFromJson(json['status'] ?? json['project_status']),
      lastUpdate: tmDateTimeFromJson(json['last_update'] ?? json['write_date']),
      address: tmStringFromJson(json['address']),
      heroImageUrl: tmStringFromJson(json['hero_image_url']),
      clientImageUrl: tmStringFromJson(
        json['client_image_url'] ??
            json['partner_image_url'] ??
            json['customer_image_url'] ??
            json['partner_image'],
      ),
      progressPct: tmDoubleFromJson(json['progress_pct']),
      budgetMin: tmDoubleFromJson(json['budget_min']),
      budgetMax: tmDoubleFromJson(json['budget_max']),
      geofenceLat: tmDoubleFromJson(json['geofence_lat']),
      geofenceLon: tmDoubleFromJson(json['geofence_lon']),
      geofenceRadiusM: tmDoubleFromJson(json['geofence_radius_m']),
      pmId: tmStringFromJson(json['pm_id']),
      foremanIds: tmStringListFromJson(json['foreman_ids']),
      chatRoomId: tmStringFromJson(json['chat_room_id']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'wo_ref_no': woRefNo,
      'client': client,
      'start': tmDateTimeToJson(start),
      'end': tmDateTimeToJson(end),
      'status': status,
      'last_update': tmDateTimeToJson(lastUpdate),
      'address': address,
      'hero_image_url': heroImageUrl,
      'client_image_url': clientImageUrl,
      'progress_pct': progressPct,
      'budget_min': budgetMin,
      'budget_max': budgetMax,
      'geofence_lat': geofenceLat,
      'geofence_lon': geofenceLon,
      'geofence_radius_m': geofenceRadiusM,
      'pm_id': pmId,
      'foreman_ids': foremanIds,
      'chat_room_id': chatRoomId,
    };
  }
}
