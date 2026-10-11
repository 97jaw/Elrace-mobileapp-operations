import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Device name, OS and app version sent as headers at login so Linked
/// Devices can show which phone a session belongs to.
class DeviceDetailsHeaders {
  DeviceDetailsHeaders._();

  static Future<Map<String, String>>? _cached;

  static Future<Map<String, String>> get() {
    return _cached ??= _load().catchError((Object e) {
      debugPrint('[DeviceDetailsHeaders] $e');
      _cached = null;
      return const <String, String>{};
    });
  }

  static Future<Map<String, String>> _load() async {
    final info = DeviceInfoPlugin();
    var name = '';
    var os = '';
    if (Platform.isIOS) {
      final ios = await info.iosInfo;
      name = ios.modelName.isNotEmpty ? ios.modelName : ios.model;
      os = '${ios.systemName} ${ios.systemVersion}';
    } else if (Platform.isAndroid) {
      final android = await info.androidInfo;
      final brand = _capitalize(android.manufacturer);
      final model = android.model;
      name = model.toLowerCase().startsWith(brand.toLowerCase())
          ? model
          : '$brand $model';
      os = 'Android ${android.version.release}';
    }
    final package = await PackageInfo.fromPlatform();
    return {
      if (name.trim().isNotEmpty) 'X-Device-Name': _ascii(name),
      if (os.trim().isNotEmpty) 'X-Device-OS': _ascii(os),
      'X-App-Version': '${package.version}+${package.buildNumber}',
    };
  }

  static String _capitalize(String value) {
    final v = value.trim();
    if (v.isEmpty) return v;
    return '${v[0].toUpperCase()}${v.substring(1)}';
  }

  /// HTTP header values must be plain ASCII.
  static String _ascii(String value) =>
      value.replaceAll(RegExp(r'[^\x20-\x7E]'), '').trim();
}
