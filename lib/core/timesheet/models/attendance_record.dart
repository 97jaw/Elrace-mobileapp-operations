import 'timesheet_model_parsers.dart';

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.projectId,
    required this.taskId,
    required this.workerId,
    required this.foremanId,
    required this.event,
    required this.timestamp,
    required this.lat,
    required this.lon,
    required this.gpsAccuracyM,
    required this.similarity,
    required this.auditPhotoUrl,
    required this.outsideGeofence,
    required this.manualOverride,
    required this.deviceId,
    required this.syncState,
  });

  final String id;
  final String projectId;
  final String taskId;
  final String workerId;
  final String foremanId;
  final String event;
  final DateTime? timestamp;
  final double lat;
  final double lon;
  final double gpsAccuracyM;
  final double similarity;
  final String auditPhotoUrl;
  final bool outsideGeofence;
  final bool manualOverride;
  final String deviceId;
  final String syncState;

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: tmStringFromJson(json['id']),
      projectId: tmStringFromJson(json['project_id']),
      taskId: tmStringFromJson(json['task_id']),
      workerId: tmStringFromJson(json['worker_id']),
      foremanId: tmStringFromJson(json['foreman_id']),
      event: tmStringFromJson(json['event']),
      timestamp: tmDateTimeFromJson(json['timestamp']),
      lat: tmDoubleFromJson(json['lat']),
      lon: tmDoubleFromJson(json['lon']),
      gpsAccuracyM: tmDoubleFromJson(json['gps_accuracy_m']),
      similarity: tmDoubleFromJson(json['similarity']),
      auditPhotoUrl: tmStringFromJson(json['audit_photo_url']),
      outsideGeofence: tmBoolFromJson(json['outside_geofence']),
      manualOverride: tmBoolFromJson(json['manual_override']),
      deviceId: tmStringFromJson(json['device_id']),
      syncState: tmStringFromJson(json['sync_state']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'project_id': projectId,
      'task_id': taskId,
      'worker_id': workerId,
      'foreman_id': foremanId,
      'event': event,
      'timestamp': tmDateTimeToJson(timestamp),
      'lat': lat,
      'lon': lon,
      'gps_accuracy_m': gpsAccuracyM,
      'similarity': similarity,
      'audit_photo_url': auditPhotoUrl,
      'outside_geofence': outsideGeofence,
      'manual_override': manualOverride,
      'device_id': deviceId,
      'sync_state': syncState,
    };
  }
}
