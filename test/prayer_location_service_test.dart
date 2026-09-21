import 'package:adhan/adhan.dart';
import 'package:el_race/data/services/prayer_location_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrayerLocationService calculation method', () {
    test('uses the UAE method for coordinates in the UAE', () {
      final coordinates = Coordinates(25.2048, 55.2708);

      expect(PrayerLocationService.aladhanMethodIdFor(coordinates), 16);
      expect(
        PrayerLocationService.calculationParametersFor(coordinates).method,
        CalculationMethod.dubai,
      );
    });

    test('keeps the existing method outside the UAE', () {
      final coordinates = Coordinates(51.5074, -0.1278);

      expect(PrayerLocationService.aladhanMethodIdFor(coordinates), 5);
      expect(
        PrayerLocationService.calculationParametersFor(coordinates).method,
        CalculationMethod.egyptian,
      );
    });
  });
}
