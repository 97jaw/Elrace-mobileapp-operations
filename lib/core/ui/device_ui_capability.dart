import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Detects device tier once at startup and toggles expensive UI (blur, noise, etc.).
///
/// High-end: full glass / blur (unchanged look).
/// Low-end: frosted solid panels — same layout and colors, no [BackdropFilter].
class DeviceUiCapability {
  DeviceUiCapability._();

  static bool _initialized = false;
  static bool _isLowEnd = false;
  static String _reason = 'not initialized';

  static const _forceLowEnd =
      bool.fromEnvironment('FORCE_LOW_END_UI', defaultValue: false);
  static const _forceHighEnd =
      bool.fromEnvironment('FORCE_HIGH_END_UI', defaultValue: false);

  static bool get isLowEnd => _isLowEnd;
  static bool get isHighEnd => !_isLowEnd;
  static bool get useBackdropBlur => !_isLowEnd;
  static String get debugDescription => _reason;

  /// Initialize before [runApp]. Fast (~few ms).
  static Future<void> init() async {
    if (_initialized) return;

    if (_forceHighEnd) {
      _isLowEnd = false;
      _reason = 'forced high-end (dart-define FORCE_HIGH_END_UI)';
    } else if (_forceLowEnd) {
      _isLowEnd = true;
      _reason = 'forced low-end (dart-define FORCE_LOW_END_UI)';
    } else if (kIsWeb) {
      _isLowEnd = false;
      _reason = 'web — full effects';
    } else if (Platform.isIOS) {
      _isLowEnd = _evaluateIos(await DeviceInfoPlugin().iosInfo);
      _reason = _isLowEnd ? 'iOS low-tier' : 'iOS high-tier';
    } else if (Platform.isAndroid) {
      _isLowEnd = _evaluateAndroid(await DeviceInfoPlugin().androidInfo);
      _reason = _isLowEnd ? 'Android low-tier' : 'Android high-tier';
    } else {
      _isLowEnd = false;
      _reason = 'other platform — full effects';
    }

    _initialized = true;
    debugPrint(
      '🎨 DeviceUiCapability: ${_isLowEnd ? "LOW-END (lite UI)" : "HIGH-END (full UI)"} — $_reason',
    );
  }

  /// Scale requested blur sigma; returns 0 when blur is disabled.
  static double adaptiveBlurSigma(double requested) {
    if (!_isLowEnd) return requested;
    return 0;
  }

  /// Slightly shorter transitions on low-end devices.
  static Duration adaptiveDuration(Duration requested) {
    if (!_isLowEnd) return requested;
    return Duration(
      milliseconds: (requested.inMilliseconds * 0.75).round().clamp(120, 280),
    );
  }

  static bool _evaluateIos(IosDeviceInfo info) {
    final machine = info.utsname.machine.toLowerCase();
    final gen = _iosGeneration(machine);
    // iPhone 11 (gen 12) and newer → full effects.
    if (gen >= 12) return false;
    // iPhone X / XS / XR class still OK for most glass.
    if (gen >= 10) return false;
    return true;
  }

  static int _iosGeneration(String machine) {
    final match = RegExp(r'iphone(\d+),').firstMatch(machine);
    if (match == null) return 99;
    return int.tryParse(match.group(1)!) ?? 99;
  }

  static bool _evaluateAndroid(AndroidDeviceInfo info) {
    final ramMb = info.physicalRamSize;
    final ramGb = ramMb > 0 ? ramMb / 1024.0 : 0;
    final blob =
        '${info.manufacturer} ${info.brand} ${info.model} ${info.device} ${info.product}'
            .toLowerCase();

    if (_isAndroidFlagship(blob)) return false;

    // ≤6 GB RAM — safe low-tier default (Oppo F21 class).
    if (ramGb > 0 && ramGb <= 6.5) return true;

    // 6–8 GB mid-range OEMs often struggle with stacked blur.
    if (ramGb > 0 && ramGb <= 8.5 && _isMidRangeAndroidOem(blob)) {
      return true;
    }

    // Unknown RAM on Android — prefer smoothness.
    if (ramGb <= 0) return true;

    return false;
  }

  static bool _isAndroidFlagship(String blob) {
    const flagship = [
      's24',
      's23',
      's22 ultra',
      'sm-s928',
      'sm-s918',
      'sm-s908',
      'pixel 8 pro',
      'pixel 9',
      'oneplus 12',
      'xiaomi 14',
      'mi 14',
      'fold',
      'flip',
    ];
    return flagship.any(blob.contains);
  }

  static bool _isMidRangeAndroidOem(String blob) {
    const mid = [
      'oppo',
      'cph',
      'realme',
      'vivo',
      'redmi',
      'poco',
      'infinix',
      'tecno',
      'motorola moto g',
      'moto g',
      'nokia',
      'honor',
    ];
    return mid.any(blob.contains);
  }
}
