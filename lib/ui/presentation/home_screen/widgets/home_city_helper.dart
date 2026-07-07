import 'dart:convert';

import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_theme.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Resolves the user's current city for the home greeting row.
class HomeCityHelper {
  HomeCityHelper._();

  static String? _cachedCity;

  static String get cachedCity {
    if (_cachedCity != null &&
        _cachedCity!.isNotEmpty &&
        _cachedCity != '...') {
      return _cachedCity!;
    }
    return 'Al Ain';
  }

  static Future<String> fetchCity({bool force = false}) async {
    if (!force &&
        _cachedCity != null &&
        _cachedCity!.isNotEmpty &&
        _cachedCity != '...') {
      return _cachedCity!;
    }

    try {
      Position? pos;
      try {
        pos = await Geolocator.getLastKnownPosition();
      } catch (_) {}

      pos ??= await _currentPosition();

      if (pos != null) {
        final city = await _reverseGeocodeCity(
          latitude: pos.latitude,
          longitude: pos.longitude,
        );
        if (city != null && city.isNotEmpty) {
          _cachedCity = city;
          return city;
        }
      }
    } catch (_) {}

    _cachedCity ??= 'Al Ain';
    return _cachedCity!;
  }

  static Future<Position?> _currentPosition() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _reverseGeocodeCity({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'zoom': '14',
        'addressdetails': '1',
        'accept-language': 'en,ar',
      });

      final res = await http.get(
        uri,
        headers: const {
          'User-Agent': 'el_race_app/1.0 (Flutter; reverse geocoding)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode != 200) return null;

      final body = jsonDecode(res.body);
      final address = body is Map ? body['address'] : null;
      if (address is! Map) return null;

      String? pick(String key) {
        final v = address[key];
        if (v is String && v.trim().isNotEmpty) return v.trim();
        return null;
      }

      return pick('city') ??
          pick('town') ??
          pick('village') ??
          pick('suburb') ??
          pick('neighbourhood') ??
          pick('municipality') ??
          pick('county') ??
          pick('state_district') ??
          pick('state');
    } catch (_) {
      return null;
    }
  }
}

/// Maroon pin with white center — greeting location marker.
class HomeMaroonLocationMarker extends StatelessWidget {
  const HomeMaroonLocationMarker({super.key, this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.location_on,
            size: size,
            color: HomeGlassTheme.maroon,
          ),
          Positioned(
            top: size * 0.22,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const Color maroon = Color(0xFF8B1A2B);
}
