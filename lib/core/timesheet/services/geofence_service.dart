import 'dart:math' as math;

class TimesheetGeoPoint {
  const TimesheetGeoPoint({
    required this.lat,
    required this.lon,
  });

  final double lat;
  final double lon;
}

class TimesheetGeofencePreview {
  const TimesheetGeofencePreview({
    required this.hasGpsLock,
    required this.distanceM,
    required this.isInside,
    required this.label,
  });

  final bool hasGpsLock;
  final double? distanceM;
  final bool isInside;
  final String label;
}

/// Device-side geofence helper for preview labels only.
///
/// Cloud Functions remain authoritative for `outside_geofence`.
class TimesheetGeofenceService {
  const TimesheetGeofenceService();

  static const double earthRadiusM = 6371000;

  bool isInsideCircle({
    required TimesheetGeoPoint? point,
    required TimesheetGeoPoint center,
    required double radiusM,
  }) {
    if (point == null || radiusM < 0) return false;
    return distanceMeters(point, center) <= radiusM;
  }

  double distanceMeters(TimesheetGeoPoint a, TimesheetGeoPoint b) {
    final lat1 = _toRadians(a.lat);
    final lat2 = _toRadians(b.lat);
    final deltaLat = _toRadians(b.lat - a.lat);
    final deltaLon = _toRadians(b.lon - a.lon);

    final haversine = math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLon / 2) *
            math.sin(deltaLon / 2);
    final angularDistance =
        2 * math.atan2(math.sqrt(haversine), math.sqrt(1 - haversine));
    return earthRadiusM * angularDistance;
  }

  TimesheetGeofencePreview preview({
    required TimesheetGeoPoint? point,
    required TimesheetGeoPoint center,
    required double radiusM,
  }) {
    if (point == null) {
      return const TimesheetGeofencePreview(
        hasGpsLock: false,
        distanceM: null,
        isInside: false,
        label: 'Waiting for GPS lock',
      );
    }

    final distance = distanceMeters(point, center);
    final delta = (radiusM - distance).abs();
    final inside = distance <= radiusM;
    final rounded = delta.round();
    return TimesheetGeofencePreview(
      hasGpsLock: true,
      distanceM: distance,
      isInside: inside,
      label: inside ? '$rounded m inside fence' : '$rounded m outside fence',
    );
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;
}
