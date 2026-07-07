/// Formats geofence distance for the check-in map banner.
abstract final class CheckinDistanceFormatter {
  static String formatDistance(double? meters) {
    if (meters == null) return '--';
    if (meters <= 500) return '${meters.round()} m';
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000;
    return km >= 10 ? '${km.round()} km' : '${km.toStringAsFixed(1)} km';
  }

  static String proximityLabel({required bool isInside, required bool hasGps}) {
    if (!hasGps) return 'Locating…';
    return isInside ? 'Near' : 'Away';
  }
}
