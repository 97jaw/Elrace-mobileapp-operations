import 'dart:convert';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/my_documents/screens/attachment_viewer_screen.dart';
import 'package:el_race/utils/urll_utils.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Shared attachment open flow for My Documents / Shared Documents.
class DocumentAttachmentOpener {
  DocumentAttachmentOpener._();

  static int? firstAttachmentId(Map<String, dynamic> document) {
    final fromList = _firstFromAttachmentIds(document['attachment_ids']);
    if (fromList != null) {
      if (fromList is int) return fromList;
      return int.tryParse(fromList.toString());
    }
    final direct = document['id'] ??
        document['attachment_id'] ??
        document['file_id'];
    if (direct is int) return direct;
    return int.tryParse(direct?.toString() ?? '');
  }

  static dynamic _firstFromAttachmentIds(dynamic attachmentIds) {
    if (attachmentIds is List && attachmentIds.isNotEmpty) {
      final first = attachmentIds.first;
      if (first is Map) {
        return first['attachment_id'] ?? first['id'] ?? first['attachmentId'];
      }
      return first;
    }
    if (attachmentIds is Map) {
      return attachmentIds['attachment_id'] ??
          attachmentIds['id'] ??
          attachmentIds['attachmentId'];
    }
    return null;
  }

  static Future<Map<String, dynamic>> fetchAttachmentDetails({
    required int attachmentId,
  }) async {
    final token = SharedPref.getLoginData().result?.token ?? '';
    final url = Uri.parse('${UrlUtil.baseUrl}get_attachment_details');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'params': {
        'attachment_id': attachmentId,
      },
    });

    final request = http.Request('GET', url)
      ..headers.addAll(headers)
      ..body = body;
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw Exception(
        'Failed to parse attachment details (HTTP ${response.statusCode}).',
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        decoded is Map
            ? (decoded['error']?.toString() ??
                decoded['result']?['message']?.toString() ??
                'Failed to load attachment details (HTTP ${response.statusCode})')
            : 'Failed to load attachment details (HTTP ${response.statusCode})',
      );
    }

    if (decoded is! Map) {
      throw Exception('Invalid attachment details response');
    }

    final result = decoded['result'];
    if (result == null || result['status'] != 'success') {
      throw Exception(
        result?['message']?.toString() ??
            decoded['error']?.toString() ??
            'Failed to load attachment details',
      );
    }

    final data = result['data'];
    if (data is! Map) {
      throw Exception('Invalid attachment details response');
    }

    return Map<String, dynamic>.from(data);
  }

  static Future<void> open(
    BuildContext context,
    Map<String, dynamic> document,
  ) async {
    final attachmentId = firstAttachmentId(document);
    if (attachmentId == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No attachment available for this document'),
        ),
      );
      return;
    }

    if (!context.mounted) return;
    var loaderVisible = true;
    void dismissLoader() {
      if (!loaderVisible) return;
      loaderVisible = false;
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final details = await fetchAttachmentDetails(attachmentId: attachmentId);
      final publicUrl = (details['public_url'] ?? '').toString();
      final name =
          (details['attachment_name'] ?? document['name'] ?? 'Attachment')
              .toString();
      final type = (details['attachment_type'] ?? '').toString().toLowerCase();

      if (publicUrl.isEmpty) {
        throw Exception('Attachment URL is empty');
      }

      dismissLoader();
      if (!context.mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AttachmentViewerScreen(
            publicUrl: publicUrl,
            title: name,
            attachmentType: type,
          ),
        ),
      );
    } catch (e) {
      dismissLoader();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }
}
