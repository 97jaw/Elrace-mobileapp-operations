import 'dart:convert';

import 'package:el_race/core/drawing_studio/drawing_studio_api_config.dart';
import 'package:el_race/core/drawing_studio/drawing_studio_cognito_client.dart';
import 'package:el_race/core/drawing_studio/drawing_studio_config.dart';
import 'package:el_race/core/drawing_studio/drawing_studio_project.dart';
import 'package:el_race/core/drawing_studio/drawing_studio_token_storage.dart';
import 'package:http/http.dart' as http;

/// Studio REST client — Authorization header is the Cognito IdToken (raw).
class DrawingStudioApiClient {
  DrawingStudioApiClient({
    http.Client? httpClient,
    DrawingStudioTokenStorage? tokenStorage,
    DrawingStudioCognitoClient? cognitoClient,
    String? baseUrl,
  })  : _http = httpClient ?? http.Client(),
        _tokens = tokenStorage ?? DrawingStudioTokenStorage.instance,
        _cognito = cognitoClient ?? DrawingStudioCognitoClient(),
        _baseUrl = baseUrl ?? DrawingStudioApiConfig.baseUrl;

  final http.Client _http;
  final DrawingStudioTokenStorage _tokens;
  final DrawingStudioCognitoClient _cognito;
  final String _baseUrl;

  static DrawingStudioConfig? _cachedConfig;

  Future<List<DrawingStudioProject>> listProjects({int limit = 20}) async {
    final uri = Uri.parse('$_baseUrl/projects').replace(
      queryParameters: {'limit': '$limit'},
    );
    final body = await _getJson(uri);
    return _parseProjectList(body);
  }

  Future<DrawingStudioProject> getProject(String projectId) async {
    final uri = Uri.parse('$_baseUrl/projects/$projectId');
    final body = await _getJson(uri);
    if (body is Map) {
      final map = Map<String, dynamic>.from(body);
      final nested = map['project'] ?? map['data'] ?? map;
      if (nested is Map) {
        return DrawingStudioProject.fromJson(
          Map<String, dynamic>.from(nested),
        );
      }
    }
    throw DrawingStudioApiException('Invalid project response.');
  }

  Future<DrawingStudioConfig> getStudioConfig({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedConfig != null) return _cachedConfig!;
    final uri = Uri.parse('$_baseUrl/studio/config');
    final body = await _getJson(uri);
    if (body is! Map) {
      throw DrawingStudioApiException('Invalid studio config response.');
    }
    final config = DrawingStudioConfig.fromJson(
      Map<String, dynamic>.from(body),
    );
    _cachedConfig = config;
    return config;
  }

  /// Form mode: `{ form, instructions? }` → 202 accepted.
  Future<DrawingStudioGenerateAccepted> generateForm(
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$_baseUrl/generate');
    final response = await _authorizedPost(uri, body);
    return _parseGenerateResponse(response);
  }

  /// Chat mode: `{ brief }` → 202 accepted.
  Future<DrawingStudioGenerateAccepted> generateBrief(String brief) async {
    final uri = Uri.parse('$_baseUrl/generate');
    final response = await _authorizedPost(uri, {'brief': brief.trim()});
    return _parseGenerateResponse(response);
  }

  DrawingStudioGenerateAccepted _parseGenerateResponse(
    http.Response response,
  ) {
    final decoded = _tryDecode(response.body);
    final map = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};

    if (response.statusCode == 400) {
      final issuesRaw = map['issues'];
      final issues = <DrawingStudioFormIssue>[];
      if (issuesRaw is List) {
        for (final item in issuesRaw) {
          if (item is Map) {
            issues.add(
              DrawingStudioFormIssue.fromJson(Map<String, dynamic>.from(item)),
            );
          }
        }
      }
      throw DrawingStudioValidationException(
        map['message']?.toString() ?? 'Invalid form',
        issues: issues,
      );
    }

    if (response.statusCode == 401) {
      throw DrawingStudioApiException(
        map['message']?.toString() ?? 'Session expired. Please authorize again.',
        statusCode: 401,
      );
    }

    if (response.statusCode != 202 &&
        (response.statusCode < 200 || response.statusCode >= 300)) {
      throw DrawingStudioApiException(
        map['message']?.toString() ??
            map['error']?.toString() ??
            'Generate failed (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    final accepted = DrawingStudioGenerateAccepted.fromJson(map);
    if (accepted.projectId.isEmpty) {
      throw DrawingStudioApiException('Generate response missing project_id.');
    }
    return accepted;
  }

  Future<dynamic> _getJson(Uri uri) async {
    var response = await _authorizedGet(uri);
    if (response.statusCode == 401) {
      final refreshed = await _cognito.refreshIdToken();
      if (refreshed == null || refreshed.isEmpty) {
        throw DrawingStudioApiException(
          'Session expired. Please authorize again.',
          statusCode: 401,
        );
      }
      response = await _authorizedGet(uri, idToken: refreshed);
    }
    return _decodeSuccessOrThrow(response);
  }

  Future<http.Response> _authorizedGet(Uri uri, {String? idToken}) async {
    final token = await _requireToken(idToken);
    return _http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'Authorization': token,
      },
    );
  }

  Future<http.Response> _authorizedPost(
    Uri uri,
    Map<String, dynamic> body,
  ) async {
    Future<http.Response> send(String token) {
      return _http.post(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': token,
        },
        body: jsonEncode(body),
      );
    }

    var token = await _requireToken(null);
    var response = await send(token);
    if (response.statusCode == 401) {
      final refreshed = await _cognito.refreshIdToken();
      if (refreshed == null || refreshed.isEmpty) {
        throw DrawingStudioApiException(
          'Session expired. Please authorize again.',
          statusCode: 401,
        );
      }
      response = await send(refreshed);
    }
    return response;
  }

  Future<String> _requireToken(String? idToken) async {
    final token = idToken ?? await _tokens.getIdToken();
    if (token == null || token.isEmpty) {
      throw DrawingStudioApiException(
        'Not authorized. Sign in to Drawing Studio first.',
        statusCode: 401,
      );
    }
    return token;
  }

  dynamic _decodeSuccessOrThrow(http.Response response) {
    final decoded = _tryDecode(response.body);
    Map<String, dynamic>? map;
    if (decoded is Map<String, dynamic>) {
      map = decoded;
    } else if (decoded is Map) {
      map = Map<String, dynamic>.from(decoded);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = map?['message']?.toString() ??
          map?['error']?.toString() ??
          'Request failed (${response.statusCode})';
      throw DrawingStudioApiException(message, statusCode: response.statusCode);
    }
    return decoded ?? map ?? {};
  }

  dynamic _tryDecode(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  List<DrawingStudioProject> _parseProjectList(dynamic body) {
    List<dynamic>? raw;
    if (body is List) {
      raw = body;
    } else if (body is Map) {
      final map = Map<String, dynamic>.from(body);
      final candidate = map['projects'] ??
          map['items'] ??
          map['data'] ??
          map['results'];
      if (candidate is List) {
        raw = candidate;
      } else if (candidate is Map && candidate['projects'] is List) {
        raw = candidate['projects'] as List;
      }
    }
    if (raw == null) return const [];

    final out = <DrawingStudioProject>[];
    for (final item in raw) {
      if (item is Map) {
        final project = DrawingStudioProject.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (project.projectId.isNotEmpty) out.add(project);
      }
    }
    return out;
  }
}

class DrawingStudioApiException implements Exception {
  DrawingStudioApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class DrawingStudioValidationException implements Exception {
  DrawingStudioValidationException(this.message, {required this.issues});

  final String message;
  final List<DrawingStudioFormIssue> issues;

  @override
  String toString() => message;
}
