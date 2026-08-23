import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage for AI Drawing Studio Cognito tokens.
///
/// Separate from Face Liveness Amplify Cognito and from Elrace/Odoo login.
class DrawingStudioTokenStorage {
  static DrawingStudioTokenStorage? _instance;
  static DrawingStudioTokenStorage get instance =>
      _instance ??= DrawingStudioTokenStorage._();

  DrawingStudioTokenStorage._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _keyIdToken = 'drawing_studio_id_token';
  static const _keyRefreshToken = 'drawing_studio_refresh_token';
  static const _keyAccessToken = 'drawing_studio_access_token';

  Future<void> saveTokens({
    required String idToken,
    required String refreshToken,
    String? accessToken,
  }) async {
    await Future.wait([
      _storage.write(key: _keyIdToken, value: idToken),
      _storage.write(key: _keyRefreshToken, value: refreshToken),
      if (accessToken != null && accessToken.isNotEmpty)
        _storage.write(key: _keyAccessToken, value: accessToken),
    ]);
  }

  Future<String?> getIdToken() => _storage.read(key: _keyIdToken);

  Future<String?> getRefreshToken() => _storage.read(key: _keyRefreshToken);

  Future<String?> getAccessToken() => _storage.read(key: _keyAccessToken);

  Future<bool> hasSession() async {
    final id = await getIdToken();
    return id != null && id.isNotEmpty;
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _keyIdToken),
      _storage.delete(key: _keyRefreshToken),
      _storage.delete(key: _keyAccessToken),
    ]);
  }
}
