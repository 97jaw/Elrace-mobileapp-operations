import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Persistent device id for mobile API calls (login + UAE PASS).
///
/// Matches the email-login pattern: one stable UUID per app install,
/// not a hardware string that changes format or breaks device binding.
class MobileDeviceIdService {
  MobileDeviceIdService._();

  static const _storageKey = 'device_id_mobile_installation';
  static const _storage = FlutterSecureStorage();

  static Future<String> getOrCreate() async {
    final existing = await _storage.read(key: _storageKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = const Uuid().v4();
    await _storage.write(key: _storageKey, value: id);
    return id;
  }
}
