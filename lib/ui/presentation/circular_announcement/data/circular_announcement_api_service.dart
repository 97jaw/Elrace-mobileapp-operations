import 'dart:convert';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/circular_announcement/data/circular_announcement_model.dart';
import 'package:el_race/utils/api_logger.dart';
import 'package:http/http.dart' as http;

/// Exception for circular/announcement API errors
class CircularAnnouncementApiException implements Exception {
  final String message;
  final int? statusCode;

  CircularAnnouncementApiException(this.message, {this.statusCode});

  @override
  String toString() =>
      'CircularAnnouncementApiException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

/// Service for fetching circulars and announcements
class CircularAnnouncementApiService {
  static const String baseUrl = 'https://erp.elrace.com/api';

  /// Fetch circulars and announcements from API.
  ///
  /// Without [page] the backend returns every record. [category]
  /// (`circular` / `announcement`) pages a single tab.
  Future<CircularAnnouncementResponse> fetchCircularAnnouncements({
    int? page,
    int? pageSize,
    String? category,
  }) async {
    try {
      // Get authentication token
      final token = SharedPref.getLoginData().result?.token;
      if (token == null || token.isEmpty) {
        throw CircularAnnouncementApiException(
            'Authentication token not found');
      }

      final url = Uri.parse('$baseUrl/v3/get_circular_announcement');

      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final body = jsonEncode({
        'jsonrpc': '2.0',
        'params': {
          if (page != null) 'page': page,
          if (pageSize != null) 'page_size': pageSize,
          if (category != null) 'category': category,
        },
      });

      // Log request
      ApiLogger.logRequest(
        endpoint: url.toString(),
        method: 'POST',
        headers: headers,
        body: body,
      );

      final startTime = DateTime.now();

      // Use POST request (API requires POST, not GET)
      final response = await http.post(
        url,
        headers: headers,
        body: body,
      );

      final duration = DateTime.now().difference(startTime);

      // Log response
      ApiLogger.logResponse(
        endpoint: url.toString(),
        statusCode: response.statusCode,
        responseBody: response.body,
        duration: duration,
      );

      print('📡 CircularAnnouncement API Response:');
      print('   - Status: ${response.statusCode}');
      print('   - Body length: ${response.body.length}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return CircularAnnouncementResponse.fromJson(data);
      } else {
        throw CircularAnnouncementApiException(
          'Failed to fetch data',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      print('❌ CircularAnnouncement API Error: $e');
      if (e is CircularAnnouncementApiException) rethrow;
      throw CircularAnnouncementApiException(
          'Failed to fetch circulars and announcements: $e');
    }
  }
}
