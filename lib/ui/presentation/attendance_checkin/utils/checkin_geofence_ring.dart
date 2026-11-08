import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Builds a closed ring of lat/lng points for a dashed geofence polyline.
abstract final class CheckinGeofenceRing {
  /// [segments] should be even so dashes alternate cleanly when split.
  static List<LatLng> circlePoints({
    required LatLng center,
    required double radiusM,
    int segments = 72,
  }) {
    final points = <LatLng>[];
    final latRad = center.latitude * math.pi / 180;
    const metersPerDegLat = 111320.0;
    final metersPerDegLng = metersPerDegLat * math.cos(latRad);

    for (var i = 0; i <= segments; i++) {
      final angle = (2 * math.pi * i) / segments;
      final dLat = (radiusM * math.cos(angle)) / metersPerDegLat;
      final dLng = (radiusM * math.sin(angle)) / metersPerDegLng;
      points.add(LatLng(center.latitude + dLat, center.longitude + dLng));
    }
    return points;
  }

  /// Alternating short polylines for a dashed border.
  static List<List<LatLng>> dashedSegments({
    required LatLng center,
    required double radiusM,
    int segments = 72,
    int dashLength = 2,
    int gapLength = 1,
  }) {
    final ring = circlePoints(
      center: center,
      radiusM: radiusM,
      segments: segments,
    );
    final dashes = <List<LatLng>>[];
    var i = 0;
    while (i < ring.length - 1) {
      final end = math.min(i + dashLength, ring.length - 1);
      dashes.add(ring.sublist(i, end + 1));
      i += dashLength + gapLength;
    }
    return dashes;
  }

  /// Northernmost point on the circle (for the "Allowed Zone" pill).
  static LatLng northEdge({
    required LatLng center,
    required double radiusM,
  }) {
    return circlePoints(center: center, radiusM: radiusM, segments: 4).first;
  }
}
