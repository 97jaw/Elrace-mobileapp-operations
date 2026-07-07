import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../utils/di.dart';
import '../../../../utils/urll_utils.dart';
import '../../signin/data/repository.dart';
import '../data/media_model.dart';
import '../data/content_model.dart';
import 'i_media_repository.dart';

class MediaRepository implements IMediaRepository {
  final userRepo = sl.get<UserRepo>();

  @override
  Future<List<MediaModel>> getMediaList() async {
    try {
      final loginResponse = await userRepo.getLoginResponse();
      var token = loginResponse!.result!.token!;

      Map<String, String> headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token"
      };

      final body = jsonEncode({"jsonrpc": "2.0", "params": {}});
      final url = Uri.parse("${UrlUtil.baseUrl}${UrlUtil.mediaAttachmentsApi}");
      final request = http.Request('GET', url)
        ..headers.addAll(headers)
        ..body = body;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['result'] != null && json['result']['data'] != null) {
          List<dynamic> mediaData = json['result']['data'];
          return mediaData.map((item) => MediaModel.fromJson(item)).toList();
        }
      }
      return [];
    } catch (e) {
      log('Error in getMediaList: $e');
      return [];
    }
  }

  @override
  Future<void> addMedia(MediaModel media) async {
    throw UnimplementedError('Add media functionality not implemented in API');
  }

  @override
  Future<void> updateMedia(MediaModel media) async {
    throw UnimplementedError(
        'Update media functionality not implemented in API');
  }

  @override
  Future<void> deleteMedia(String mediaId) async {
    throw UnimplementedError(
        'Delete media functionality not implemented in API');
  }

  @override
  Future<List<MediaModel>> getMediaByType(MediaType type) async {
    final allMedia = await getMediaList();
    return allMedia.where((media) => media.type == type).toList();
  }

  @override
  Future<List<MediaModel>> searchMedia(String keyword) async {
    final allMedia = await getMediaList();
    return allMedia
        .where((media) =>
            media.name.toLowerCase().contains(keyword.toLowerCase()) ||
            media.type.name.toLowerCase().contains(keyword.toLowerCase()) ||
            media.fileExtension.toLowerCase().contains(keyword.toLowerCase()))
        .toList();
  }

  @override
  Future<String?> prepareShare(String mediaId) async {
    try {
      final loginResponse = await userRepo.getLoginResponse();
      if (loginResponse == null || loginResponse.result == null) {
        return null;
      }

      var token = loginResponse.result!.token!;

      Map<String, String> headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token"
      };

      final parsedAttachmentId = int.tryParse(mediaId.trim());
      if (parsedAttachmentId == null) {
        log('prepareShare: invalid attachment id "$mediaId"');
        return null;
      }

      final body = jsonEncode({
        "jsonrpc": "2.0",
        "params": {
          "attachment_id": parsedAttachmentId,
        }
      });

      final url = Uri.parse("${UrlUtil.baseUrl}${UrlUtil.prepareShareApi}");

      var response = await _sendPrepareShareRequest(
        url: url,
        headers: headers,
        body: body,
        method: 'GET',
      );

      if (response.statusCode != 200) {
        response = await _sendPrepareShareRequest(
          url: url,
          headers: headers,
          body: body,
          method: 'POST',
        );
      }

      if (response.statusCode != 200) {
        log(
          'prepareShare HTTP ${response.statusCode}: ${response.body}',
        );
        return null;
      }

      final json = jsonDecode(response.body);

      if (json is Map && json['error'] is Map) {
        final err = json['error'] as Map;
        final errData = err['data'];
        final message = errData is Map
            ? errData['message']?.toString() ??
                errData['name']?.toString() ??
                err['message']?.toString()
            : err['message']?.toString();
        log('prepareShare API error: $message');
        return null;
      }

      final shareUrl = _extractShareUrl(json is Map ? json['result'] : null);
      if (shareUrl != null && shareUrl.isNotEmpty) {
        return shareUrl;
      }

      log('prepareShare: no share URL in response: ${response.body}');
      return null;
    } catch (e, stackTrace) {
      log('Error in prepareShare: $e\n$stackTrace');
      return null;
    }
  }

  static Future<http.Response> _sendPrepareShareRequest({
    required Uri url,
    required Map<String, String> headers,
    required String body,
    required String method,
  }) async {
    if (method == 'POST') {
      return http.post(url, headers: headers, body: body);
    }

    final request = http.Request('GET', url)
      ..headers.addAll(headers)
      ..body = body;
    final streamedResponse = await request.send();
    return http.Response.fromStream(streamedResponse);
  }

  static String? _extractShareUrl(dynamic result) {
    if (result == null) return null;
    if (result is String && result.trim().isNotEmpty) {
      return result.trim();
    }
    if (result is! Map) return null;

    final map = Map<String, dynamic>.from(result);
    final status = map['status']?.toString();
    if (status != null && status != 'success') {
      log('prepareShare status=$status message=${map['message']}');
      return null;
    }

    const urlKeys = [
      'share_url',
      'url',
      'x_web_url',
      'web_url',
      'public_url',
      'link',
    ];

    final data = map['data'];
    if (data is Map) {
      for (final key in urlKeys) {
        final value = data[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
    }

    for (final key in urlKeys) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }

    return null;
  }

  @override
  Future<ContentsResponse?> getContents() async {
    try {
      final loginResponse = await userRepo.getLoginResponse();
      var token = loginResponse?.result?.token;

      Map<String, String> headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        if (token != null) "Authorization": "Bearer $token"
      };

      final body = jsonEncode({"jsonrpc": "2.0", "params": {}});
      final url = Uri.parse("${UrlUtil.baseUrl}${UrlUtil.getContentsGroupedApi}");

      // Use GET request with body (similar to other API calls in this app)
      final request = http.Request('GET', url)
        ..headers.addAll(headers)
        ..body = body;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json['result'] != null && json['result']['status'] == 'success') {
          return ContentsResponse.fromJson(json);
        }
      }
      return null;
    } catch (e, stackTrace) {
      log('Error in getContents: $e\n$stackTrace');
      return null;
    }
  }
}
