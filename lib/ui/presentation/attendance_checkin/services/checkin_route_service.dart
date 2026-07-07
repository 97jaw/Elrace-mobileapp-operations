import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Fetches a road-following route via OSRM (public demo server).
class CheckinRouteService {
  const CheckinRouteService();

  Future<List<LatLng>> fetchRoute({
    required double userLat,
    required double userLon,
    required double destLat,
    required double destLon,
  }) async {
    final fallback = [
      LatLng(userLat, userLon),
      LatLng(destLat, destLon),
    ];

    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '$userLon,$userLat;$destLon,$destLat'
        '?overview=full&geometries=geojson',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return fallback;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return fallback;
      final routes = decoded['routes'];
      if (routes is! List || routes.isEmpty) return fallback;

      final geometry = routes.first['geometry'];
      if (geometry is! Map) return fallback;
      final coords = geometry['coordinates'];
      if (coords is! List || coords.length < 2) return fallback;

      return coords
          .whereType<List>()
          .where((c) => c.length >= 2)
          .map((c) => LatLng(
                (c[1] as num).toDouble(),
                (c[0] as num).toDouble(),
              ))
          .toList();
    } catch (_) {
      return fallback;
    }
  }
}
