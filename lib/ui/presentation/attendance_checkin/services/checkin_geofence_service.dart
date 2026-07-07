import 'package:el_race/core/timesheet/services/geofence_service.dart';
import 'package:el_race/ui/presentation/attendance_checkin/models/checkin_context_model.dart';

export 'package:el_race/core/timesheet/services/geofence_service.dart'
    show TimesheetGeoPoint, TimesheetGeofencePreview;

/// Geofence helpers for the attendance check-in map activity.
class CheckinGeofenceService {
  const CheckinGeofenceService();

  static const _inner = TimesheetGeofenceService();

  TimesheetGeofencePreview preview({
    required TimesheetGeoPoint? userPoint,
    required CheckinAllowedProject project,
  }) {
    return _inner.preview(
      point: userPoint,
      center: TimesheetGeoPoint(lat: project.lat, lon: project.lng),
      radiusM: project.geofenceRadiusM,
    );
  }

  bool isInside({
    required TimesheetGeoPoint? userPoint,
    required CheckinAllowedProject project,
  }) {
    return _inner.isInsideCircle(
      point: userPoint,
      center: TimesheetGeoPoint(lat: project.lat, lon: project.lng),
      radiusM: project.geofenceRadiusM,
    );
  }

  double? distanceMeters({
    required TimesheetGeoPoint? userPoint,
    required CheckinAllowedProject project,
  }) {
    if (userPoint == null) return null;
    return _inner.distanceMeters(
      userPoint,
      TimesheetGeoPoint(lat: project.lat, lon: project.lng),
    );
  }

  /// Pick the nearest project with valid coordinates (manual selection overrides).
  CheckinAllowedProject? nearestProject({
    required TimesheetGeoPoint? userPoint,
    required List<CheckinAllowedProject> projects,
  }) {
    if (projects.isEmpty) return null;
    if (userPoint == null) return projects.first;

    CheckinAllowedProject? best;
    double? bestDistance;
    for (final project in projects) {
      final distance = distanceMeters(userPoint: userPoint, project: project);
      if (distance == null) continue;
      if (bestDistance == null || distance < bestDistance) {
        bestDistance = distance;
        best = project;
      }
    }
    return best ?? projects.first;
  }
}
