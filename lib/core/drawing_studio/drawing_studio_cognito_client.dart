import 'dart:convert';

import 'package:el_race/core/drawing_studio/drawing_studio_access.dart';
import 'package:el_race/core/drawing_studio/drawing_studio_token_storage.dart';
import 'package:http/http.dart' as http;

/// Cognito Identity Provider client for AI Drawing Studio only.
///
/// Uses `USER_PASSWORD_AUTH` against the Drawing Studio user pool — not the
/// Face Liveness Amplify pool and not Elrace/Odoo auth.
class DrawingStudioCognitoClient {
  DrawingStudioCognitoClient({
    http.Client? httpClient,
    DrawingStudioTokenStorage? tokenStorage,
  })  : _http = httpClient ?? http.Client(),
        _tokens = tokenStorage ?? DrawingStudioTokenStorage.instance;

  final http.Client _http;
  final DrawingStudioTokenStorage _tokens;

  /// Sign in with email + password; stores IdToken + RefreshToken on success.
  Future<DrawingStudioAuthResult> signIn({
    required String email,
    required String password,
  }) async {
    final clientId = DrawingStudioAccess.poolClientId();
    final region = DrawingStudioAccess.cognitoRegion();
    if (clientId == null || clientId.isEmpty) {
      throw DrawingStudioAuthException(
        'Drawing Studio Cognito client is not configured.',
      );
    }

    final body = await _post(
      region: region,
      target: 'AWSCognitoIdentityProviderService.InitiateAuth',
      payload: {
        'AuthFlow': 'USER_PASSWORD_AUTH',
        'ClientId': clientId,
        'AuthParameters': {
          'USERNAME': email.trim(),
          'PASSWORD': password,
        },
      },
    );

    final challenge = body['ChallengeName']?.toString();
    if (challenge != null && challenge.isNotEmpty) {
      throw DrawingStudioAuthException(
        'Additional Cognito challenge required: $challenge',
      );
    }

    final auth = body['AuthenticationResult'];
    if (auth is! Map) {
      throw DrawingStudioAuthException(
        'Cognito did not return authentication tokens.',
      );
    }

    final idToken = auth['IdToken']?.toString() ?? '';
    final refreshToken = auth['RefreshToken']?.toString() ?? '';
    final accessToken = auth['AccessToken']?.toString();

    if (idToken.isEmpty || refreshToken.isEmpty) {
      throw DrawingStudioAuthException(
        'Cognito response missing IdToken or RefreshToken.',
      );
    }

    await _tokens.saveTokens(
      idToken: idToken,
      refreshToken: refreshToken,
      accessToken: accessToken,
    );

    return DrawingStudioAuthResult(
      idToken: idToken,
      refreshToken: refreshToken,
      accessToken: accessToken,
    );
  }

  /// Refresh IdToken using stored RefreshToken. Returns new IdToken or null.
  Future<String?> refreshIdToken() async {
    final clientId = DrawingStudioAccess.poolClientId();
    final region = DrawingStudioAccess.cognitoRegion();
    final refreshToken = await _tokens.getRefreshToken();
    if (clientId == null ||
        clientId.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      return null;
    }

    try {
      final body = await _post(
        region: region,
        target: 'AWSCognitoIdentityProviderService.InitiateAuth',
        payload: {
          'AuthFlow': 'REFRESH_TOKEN_AUTH',
          'ClientId': clientId,
          'AuthParameters': {
            'REFRESH_TOKEN': refreshToken,
          },
        },
      );

      final auth = body['AuthenticationResult'];
      if (auth is! Map) return null;

      final idToken = auth['IdToken']?.toString() ?? '';
      final accessToken = auth['AccessToken']?.toString();
      if (idToken.isEmpty) return null;

      await _tokens.saveTokens(
        idToken: idToken,
        refreshToken: refreshToken,
        accessToken: accessToken,
      );
      return idToken;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _post({
    required String region,
    required String target,
    required Map<String, dynamic> payload,
  }) async {
    final uri = Uri.parse('https://cognito-idp.$region.amazonaws.com/');
    final response = await _http.post(
      uri,
      headers: {
        'Content-Type': 'application/x-amz-json-1.1',
        'X-Amz-Target': target,
      },
      body: jsonEncode(payload),
    );

    Map<String, dynamic> decoded = {};
    if (response.body.isNotEmpty) {
      final raw = jsonDecode(response.body);
      if (raw is Map<String, dynamic>) {
        decoded = raw;
      } else if (raw is Map) {
        decoded = Map<String, dynamic>.from(raw);
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded['message']?.toString() ??
          decoded['Message']?.toString() ??
          decoded['__type']?.toString() ??
          'Cognito auth failed (${response.statusCode})';
      throw DrawingStudioAuthException(_friendlyMessage(message));
    }

    return decoded;
  }

  String _friendlyMessage(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('notauthorized') ||
        lower.contains('incorrect username') ||
        lower.contains('incorrect password')) {
      return 'Incorrect email or password.';
    }
    if (lower.contains('userNotConfirmed'.toLowerCase()) ||
        lower.contains('user is not confirmed')) {
      return 'This Cognito user is not confirmed yet.';
    }
    if (lower.contains('passwordresetrequired') ||
        lower.contains('password reset')) {
      return 'Password reset is required for this Cognito user.';
    }
    return raw;
  }
}

class DrawingStudioAuthResult {
  const DrawingStudioAuthResult({
    required this.idToken,
    required this.refreshToken,
    this.accessToken,
  });

  final String idToken;
  final String refreshToken;
  final String? accessToken;
}

class DrawingStudioAuthException implements Exception {
  DrawingStudioAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
