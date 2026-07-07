import 'package:el_race/ui/presentation/my_projects/domain/entities/project_entity.dart';
import 'package:latlong2/latlong.dart';

/// UAE mainland bounds (approx.) for fallback marker placement when API
/// does not send latitude/longitude yet.
const double _uaeMinLat = 22.65;
const double _uaeMaxLat = 26.15;
const double _uaeMinLng = 51.0;
const double _uaeMaxLng = 56.45;

/// Default framing center (UAE).
LatLng uaeMapInitialCenter() => const LatLng(24.35, 54.55);

double uaeMapInitialZoom() => 6.8;

/// Resolves a stable [LatLng] for [p]. Prefer API coordinates (`x_pr_lat` /
/// `x_pr_long` or `latitude` / `longitude` on [ProjectEntity]); otherwise
/// spread deterministically inside UAE so markers do not stack on one point.
LatLng resolveProjectLatLng(ProjectEntity p) {
  final lat = p.latitude;
  final lng = p.longitude;
  if (lat != null &&
      lng != null &&
      lat.abs() > 1e-6 &&
      lng.abs() > 1e-6 &&
      lat >= -90 &&
      lat <= 90 &&
      lng >= -180 &&
      lng <= 180) {
    // Some APIs accidentally swap latitude/longitude.
    final looksSwapped = lat >= 50 && lat <= 60 && lng >= 20 && lng <= 30;
    if (looksSwapped) return LatLng(lng, lat);
    return LatLng(lat, lng);
  }

  final h = p.projectId.hashCode.abs();
  final r = (h % 9973) / 9973.0;
  final t = ((h ~/ 9973) % 9973) / 9973.0;
  final outLat = _uaeMinLat + r * (_uaeMaxLat - _uaeMinLat);
  final outLng = _uaeMinLng + t * (_uaeMaxLng - _uaeMinLng);
  return LatLng(outLat, outLng);
}
