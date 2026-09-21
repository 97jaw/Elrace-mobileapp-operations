import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';

class PrayerLocationService {
  static final Coordinates _fallbackCoordinates = Coordinates(25.2048, 55.2708);

  static Future<Coordinates> getBestAvailableCoordinates() async {
    Position? position;

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      final permission = await Geolocator.checkPermission();
      final canReadLocation = permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;

      if (serviceEnabled && canReadLocation) {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        );
      }
    } catch (_) {
      position = null;
    }

    if (position == null) {
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {
        position = null;
      }
    }

    return position == null
        ? _fallbackCoordinates
        : Coordinates(position.latitude, position.longitude);
  }

  static int aladhanMethodIdFor(Coordinates coordinates) {
    return _isInUnitedArabEmirates(coordinates) ? 16 : 5;
  }

  static CalculationParameters calculationParametersFor(
    Coordinates coordinates,
  ) {
    final method = _isInUnitedArabEmirates(coordinates)
        ? CalculationMethod.dubai
        : CalculationMethod.egyptian;
    return method.getParameters()..madhab = Madhab.shafi;
  }

  static bool _isInUnitedArabEmirates(Coordinates coordinates) {
    // Coordinate-based selection keeps the method local without fixing the
    // app timezone or prayer times to Dubai when the employee travels.
    return coordinates.latitude >= 22.5 &&
        coordinates.latitude <= 26.5 &&
        coordinates.longitude >= 51.5 &&
        coordinates.longitude <= 56.6;
  }
}
