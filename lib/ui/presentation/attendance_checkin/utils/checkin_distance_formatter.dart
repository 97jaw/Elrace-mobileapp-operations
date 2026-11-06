/// Formats geofence distance for the check-in map and bottom sheet.
abstract final class CheckinDistanceFormatter {
  static String formatDistance(double? meters) {
    if (meters == null) return '--';
    if (meters <= 500) return '${meters.round()} m';
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000;
    return km >= 10 ? '${km.round()} km' : '${km.toStringAsFixed(1)} km';
  }

  /// e.g. "11 m away", "1.2 km away".
  static String formatAway(double? meters) {
    if (meters == null) return '-- away';
    if (meters < 1000) return '${meters.round()} m away';
    final km = meters / 1000;
    final body =
        km >= 10 ? '${km.round()} km' : '${km.toStringAsFixed(1)} km';
    return '$body away';
  }

  static String proximityLabel({required bool isInside, required bool hasGps}) {
    if (!hasGps) return 'Locating…';
    return isInside ? 'Near' : 'Away';
  }
}
