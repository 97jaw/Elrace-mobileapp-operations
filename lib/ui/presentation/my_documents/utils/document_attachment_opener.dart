import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/my_documents/screens/attachment_viewer_screen.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/project_file_opening.dart';
import 'package:el_race/utils/urll_utils.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Shared attachment open flow for My Documents / Shared Documents / Petty Cash.
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

  /// Odoo `attachment_binary_data` is often padded/noisy base64; harden decode.
  static Uint8List? decodeBinaryData(dynamic raw) {
    var binary = (raw ?? '').toString().trim();
    if (binary.isEmpty) return null;

    // Strip data-URI prefix if present.
    final dataUri = RegExp(
      r'^data:([^;]+);base64,',
      caseSensitive: false,
    ).firstMatch(binary);
    if (dataUri != null) {
      binary = binary.substring(dataUri.end);
    }

    // Remove whitespace / newlines commonly injected in JSON.
    binary = binary.replaceAll(RegExp(r'\s+'), '');
    if (binary.isEmpty) return null;

    // Normalize URL-safe base64.
    binary = binary.replaceAll('-', '+').replaceAll('_', '/');

    // Restore missing padding.
    final mod = binary.length % 4;
    if (mod > 0) {
      binary = binary.padRight(binary.length + (4 - mod), '=');
    }

    try {
      return base64Decode(binary);
    } catch (_) {
      return null;
    }
  }

  static bool isPdfBytes(Uint8List? bytes) {
    if (bytes == null || bytes.length < 5) return false;
    // Allow UTF-8 BOM before %PDF
    var offset = 0;
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      offset = 3;
    }
    if (bytes.length < offset + 4) return false;
    return bytes[offset] == 0x25 && // %
        bytes[offset + 1] == 0x50 && // P
        bytes[offset + 2] == 0x44 && // D
        bytes[offset + 3] == 0x46; // F
  }

  static bool isImageBytes(Uint8List? bytes) {
    if (bytes == null || bytes.length < 3) return false;
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true;
    }
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return true;
    return false;
  }

  /// True when decoded API bytes look usable for in-app preview.
  static bool isPreviewableBinary(Uint8List? bytes) {
    return isPdfBytes(bytes) || isImageBytes(bytes);
  }

  static bool looksLikeExcel({
    required String fileName,
    String mime = '',
    String url = '',
  }) {
    final type = mime.toLowerCase();
    if (type.contains('spreadsheet') ||
        type.contains('excel') ||
        type.contains('sheet')) {
      return true;
    }
    final name = fileName.toLowerCase();
    final u = url.toLowerCase();
    return name.endsWith('.xlsx') ||
        name.endsWith('.xls') ||
        u.contains('.xlsx') ||
        u.contains('.xls');
  }

  static String excelMimeForName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.xls') && !lower.endsWith('.xlsx')) {
      return 'application/vnd.ms-excel';
    }
    return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  }

  static String _ensureExcelExtension(String fileName) {
    final trimmed = fileName.trim().isEmpty ? 'spreadsheet' : fileName.trim();
    final safe = trimmed.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
    final lower = safe.toLowerCase();
    if (lower.endsWith('.xlsx') || lower.endsWith('.xls')) return safe;
    return '$safe.xlsx';
  }

  static bool _looksLikeHtmlBytes(Uint8List bytes) {
    if (bytes.isEmpty) return false;
    final sampleLength = bytes.length < 64 ? bytes.length : 64;
    final head = String.fromCharCodes(bytes.sublist(0, sampleLength))
        .trimLeft()
        .toLowerCase();
    return head.startsWith('<!doctype') ||
        head.startsWith('<html') ||
        head.startsWith('<head') ||
        head.startsWith('<body');
  }

  /// Downloads attachment bytes. Prefer Odoo `/web/content` (raw file) over
  /// JSON base64, which is frequently truncated for larger PDFs.
  static Future<Uint8List?> fetchAttachmentBytes({
    required int? attachmentId,
    required String publicUrl,
    Uint8List? seededBytes,
    bool requirePreviewable = false,
  }) async {
    if (seededBytes != null &&
        seededBytes.isNotEmpty &&
        (!requirePreviewable || isPreviewableBinary(seededBytes))) {
      return seededBytes;
    }

    final token = SharedPref.getLoginData().result?.token ?? '';
    final authHeaders = <String, String>{
      'Accept': '*/*',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    Future<Uint8List?> tryGet(Uri uri, Map<String, String> headers) async {
      final response = await http.get(uri, headers: headers);
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) return null;
      final ctype = (response.headers['content-type'] ?? '').toLowerCase();
      if (ctype.contains('text/html') || ctype.contains('text/plain')) {
        return null;
      }
      if (_looksLikeHtmlBytes(response.bodyBytes)) return null;
      if (requirePreviewable && !isPreviewableBinary(response.bodyBytes)) {
        return null;
      }
      return response.bodyBytes;
    }

    // 1) Authenticated Odoo content download (most reliable for account.move).
    if (attachmentId != null) {
      final webUrls = <String>[
        'https://erp.elrace.com/web/content/$attachmentId?download=true',
        'https://erp.elrace.com/web/content/$attachmentId',
        'https://erp.elrace.com/web/content/ir.attachment/$attachmentId/datas?download=true',
        if (token.isNotEmpty)
          'https://erp.elrace.com/web/content/$attachmentId?download=true&access_token=$token',
      ];
      for (final candidate in webUrls) {
        final bytes = await tryGet(Uri.parse(candidate), authHeaders);
        if (bytes != null) return bytes;
        final publicBytes =
            await tryGet(Uri.parse(candidate), const {'Accept': '*/*'});
        if (publicBytes != null) return publicBytes;
      }
    }

    // 2) Public preview URL
    final url = normalizeProjectFileUrl(publicUrl);
    if (url.isNotEmpty) {
      final uri = Uri.parse(url);
      var bytes = await tryGet(uri, const {'Accept': '*/*'});
      bytes ??= await tryGet(uri, authHeaders);
      if (bytes != null) return bytes;
    }

    // 3) API base64 last — can be truncated for large PDFs.
    if (attachmentId != null) {
      try {
        final details =
            await fetchAttachmentDetails(attachmentId: attachmentId);
        final fromApi = decodeBinaryData(
          details['attachment_binary_data'] ?? details['datas'],
        );
        if (fromApi != null &&
            fromApi.isNotEmpty &&
            (!requirePreviewable || isPreviewableBinary(fromApi))) {
          return fromApi;
        }
      } catch (_) {
        // ignore
      }
    }
    return null;
  }

  /// Writes bytes to a temp file and opens the OS share / “Open with” sheet
  /// so the user can view in Excel/Numbers or share.
  static Future<void> presentSystemOpenShareSheet(
    BuildContext context, {
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    final resolvedName = _ensureExcelExtension(fileName);
    final mime = mimeType?.trim().isNotEmpty == true
        ? mimeType!.trim()
        : excelMimeForName(resolvedName);

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$resolvedName');
    await file.writeAsBytes(bytes, flush: true);

    if (!context.mounted) return;
    final renderObject = context.findRenderObject();
    final shareOrigin = renderObject is RenderBox
        ? (renderObject.localToGlobal(Offset.zero) & renderObject.size)
        : const Rect.fromLTWH(1, 1, 1, 1);

    await Share.shareXFiles(
      [
        XFile(
          file.path,
          mimeType: mime,
          name: resolvedName,
        ),
      ],
      sharePositionOrigin: shareOrigin,
    );
  }

  /// Opens a resolved attachment id with optional hint name (Petty Cash).
  static Future<void> openById(
    BuildContext context, {
    required int attachmentId,
    String hintName = '',
  }) async {
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
      final publicUrlRaw = (details['public_url'] ?? '').toString().trim();
      final publicUrl = publicUrlRaw.isNotEmpty
          ? normalizeProjectFileUrl(publicUrlRaw)
          : publicPreviewUrlForAttachment(attachmentId);

      final rawName = (details['attachment_name'] ?? '').toString().trim();
      final looksLikeKey = rawName.isEmpty ||
          rawName.toLowerCase() == 'attachment_id' ||
          rawName.toLowerCase() == 'false' ||
          rawName.toLowerCase() == 'null';
      final name = looksLikeKey
          ? (hintName.trim().isNotEmpty ? hintName.trim() : 'Attachment')
          : rawName;
      final type = (details['attachment_type'] ?? '').toString().toLowerCase();
      final rawSeeded = decodeBinaryData(
        details['attachment_binary_data'] ?? details['datas'],
      );
      // Only seed when magic bytes prove the payload is a real file. Truncated
      // JSON base64 is the usual cause of “corrupted PDF” in Syncfusion.
      final seededBytes =
          isPreviewableBinary(rawSeeded) ? rawSeeded : null;

      final isExcel = looksLikeExcel(
        fileName: name,
        mime: type,
        url: publicUrl,
      );

      if (isExcel) {
        final bytes = await fetchAttachmentBytes(
          attachmentId: attachmentId,
          publicUrl: publicUrl,
          seededBytes: rawSeeded,
        );
        dismissLoader();
        if (!context.mounted) return;
        if (bytes == null || bytes.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not download Excel file: $name')),
          );
          return;
        }
        await presentSystemOpenShareSheet(
          context,
          bytes: bytes,
          fileName: name,
          mimeType: type.isNotEmpty ? type : excelMimeForName(name),
        );
        return;
      }

      // Resolve bytes before opening viewer so Petty Cash / waiting records
      // don't flash Syncfusion's “corrupted PDF” on bad base64 seeds.
      final previewBytes = await fetchAttachmentBytes(
        attachmentId: attachmentId,
        publicUrl: publicUrl,
        seededBytes: seededBytes,
        requirePreviewable: true,
      );
      dismissLoader();
      if (!context.mounted) return;
      if (previewBytes == null || previewBytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open attachment: $name')),
        );
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AttachmentViewerScreen(
            publicUrl: publicUrl,
            title: name,
            attachmentType: type.isNotEmpty ? type : null,
            attachmentId: attachmentId,
            initialBytes: previewBytes,
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

    final hintName = (document['name'] ??
            document['document_name'] ??
            document['file_name'] ??
            '')
        .toString();
    await openById(context, attachmentId: attachmentId, hintName: hintName);
  }
}
