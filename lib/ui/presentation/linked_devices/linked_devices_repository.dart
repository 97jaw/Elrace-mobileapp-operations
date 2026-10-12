import 'dart:convert';

import 'package:el_race/core/services/device_details_headers.dart';
import 'package:el_race/services/api_client.dart';
import 'package:el_race/utils/di.dart';

class LinkedDevice {
  const LinkedDevice({
    required this.kind,
    required this.id,
    required this.name,
    required this.os,
    required this.browser,
    required this.appVersion,
    required this.deviceType,
    required this.lastActiveAt,
    required this.loginAt,
    required this.current,
  });

  /// `app` (El Race app) or `web` (Odoo in a browser).
  final String kind;
  final int id;
  final String name;
  final String os;
  final String browser;
  final String appVersion;
  final String deviceType;
  final DateTime? lastActiveAt;
  final DateTime? loginAt;
  final bool current;

  bool get isWeb => kind == 'web';

  factory LinkedDevice.fromJson(Map<String, dynamic> json) {
    return LinkedDevice(
      kind: (json['kind'] ?? 'app').toString(),
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '').toString(),
      os: (json['os'] ?? '').toString(),
      browser: (json['browser'] ?? '').toString(),
      appVersion: (json['app_version'] ?? '').toString(),
      deviceType: (json['device_type'] ?? '').toString(),
      lastActiveAt: _serverTime(json['last_active_at']),
      loginAt: _serverTime(json['login_at']),
      current: json['current'] == true,
    );
  }

  /// Odoo sends UTC as `YYYY-MM-DD HH:MM:SS`.
  static DateTime? _serverTime(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse('${value.replaceFirst(' ', 'T')}Z')?.toLocal();
  }
}

class LinkedDevicesData {
  const LinkedDevicesData({required this.current, required this.others});

  final LinkedDevice? current;
  final List<LinkedDevice> others;
}

class LinkedDevicesException implements Exception {
  const LinkedDevicesException(this.message);
  final String message;

  @override
  String toString() => message;
}

class LinkedDevicesRepository {
  const LinkedDevicesRepository();

  static const _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<Map<String, dynamic>> _call(
    String path, [
    Map<String, dynamic> params = const {},
    Map<String, String>? extraHeaders,
  ]) async {
    final res = await sl<ApiClient>().post(
      path,
      headers: {..._headers, ...?extraHeaders},
      data: jsonEncode({'jsonrpc': '2.0', 'method': 'call', 'params': params}),
    );
    final payload = res.data;
    final result = payload is Map ? payload['result'] : null;
    if (result is! Map) {
      throw const LinkedDevicesException(
          'Could not reach the server. Please try again.');
    }
    if (result['status'] != 'success') {
      throw LinkedDevicesException(
        (result['message'] ?? 'Something went wrong. Please try again.')
            .toString(),
      );
    }
    final data = result['data'];
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  Future<LinkedDevicesData> fetch() async {
    final data = await _call(
      'linked-devices',
      const {},
      await DeviceDetailsHeaders.get(),
    );
    final current = data['current'];
    final devices = data['devices'];
    return LinkedDevicesData(
      current: current is Map
          ? LinkedDevice.fromJson(Map<String, dynamic>.from(current))
          : null,
      others: devices is List
          ? devices
              .whereType<Map>()
              .map((d) => LinkedDevice.fromJson(Map<String, dynamic>.from(d)))
              .toList()
          : const [],
    );
  }

  Future<void> logout(LinkedDevice device) =>
      _call('linked-devices/logout', {'kind': device.kind, 'id': device.id});

  Future<void> logoutOthers() => _call('linked-devices/logout-others');

  /// Removes this phone from Linked Devices when the user logs out. The
  /// token is passed in because local storage is cleared right after.
  Future<void> logoutCurrent(String token) => _call(
        'linked-devices/logout-current',
        const {},
        {'Authorization': 'Bearer $token'},
      );
}
