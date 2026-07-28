import 'package:el_race/ui/presentation/my_documents/utils/document_attachment_opener.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/screens/projects_file_viewer_screen.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:typed_data';

const String _erpBaseUrl = 'https://erp.elrace.com';

/// Normalizes file URLs returned by my-project APIs.
///
/// Handles malformed URLs like:
/// https://erp.elrace.comhttps//erp.elrace.com/my/public/file/490765
String normalizeProjectFileUrl(String rawUrl) {
  var url = rawUrl.trim();
  if (url.isEmpty) return '';

  // Remove accidental wrapping quotes and normalize slashes.
  url = url.replaceAll('"', '').replaceAll('\\\\', '/');

  // Remove duplicated host prefix when backend returns malformed links.
  const malformedPrefixes = <String>[
    'https://erp.elrace.comhttps://',
    'https://erp.elrace.comhttp://',
    'https://erp.elrace.comhttps//',
    'https://erp.elrace.comhttp//',
  ];
  for (final prefix in malformedPrefixes) {
    if (url.startsWith(prefix)) {
      url = url.substring('https://erp.elrace.com'.length);
      break;
    }
  }

  if (url.startsWith('https//')) {
    url = 'https://${url.substring('https//'.length)}';
  } else if (url.startsWith('http//')) {
    url = 'http://${url.substring('http//'.length)}';
  } else if (url.startsWith('//')) {
    url = 'https:$url';
  }

  if (url.startsWith('http://') || url.startsWith('https://')) {
    return url;
  }

  if (url.startsWith('/')) {
    return '$_erpBaseUrl$url';
  }

  return '$_erpBaseUrl/$url';
}

/// Extracts Odoo attachment id from `/my/public/file/<id>` style URLs.
int? extractPublicAttachmentId(String rawUrl) {
  final url = normalizeProjectFileUrl(rawUrl);
  if (url.isEmpty) return null;
  final match = RegExp(
    r'/my/public/file/(\d+)',
    caseSensitive: false,
  ).firstMatch(url);
  if (match == null) return null;
  return int.tryParse(match.group(1) ?? '');
}

int? parseProjectAttachmentId(String? rawId) {
  if (rawId == null) return null;
  final trimmed = rawId.trim();
  if (trimmed.isEmpty) return null;
  // Skip cloud stubs like "cloud-project-123".
  if (!RegExp(r'^\d+$').hasMatch(trimmed)) return null;
  return int.tryParse(trimmed);
}

bool _looksLikeImage({
  required String fileName,
  required String url,
  String? mime,
}) {
  final type = (mime ?? '').toLowerCase();
  if (type.startsWith('image/')) return true;

  final name = fileName.toLowerCase();
  final u = url.toLowerCase();
  return name.endsWith('.jpg') ||
      name.endsWith('.jpeg') ||
      name.endsWith('.png') ||
      name.endsWith('.webp') ||
      name.endsWith('.gif') ||
      name.endsWith('.bmp') ||
      u.contains('.jpg') ||
      u.contains('.jpeg') ||
      u.contains('.png') ||
      u.contains('.webp') ||
      u.contains('.gif') ||
      u.contains('.bmp');
}

bool _looksLikePdf({
  required String fileName,
  required String url,
  String? mime,
}) {
  final type = (mime ?? '').toLowerCase();
  if (type.contains('pdf')) return true;

  final name = fileName.toLowerCase();
  final u = url.toLowerCase();
  if (name.endsWith('.pdf') || u.contains('.pdf')) return true;

  return false;
}

bool _looksLikeExcel({
  required String fileName,
  required String url,
  String? mime,
}) {
  final type = (mime ?? '').toLowerCase();
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

bool _isPdfBytes(Uint8List? bytes) {
  if (bytes == null || bytes.length < 4) return false;
  return bytes[0] == 0x25 && // %
      bytes[1] == 0x50 && // P
      bytes[2] == 0x44 && // D
      bytes[3] == 0x46; // F

}

String publicPreviewUrlForAttachment(int attachmentId) =>
    '$_erpBaseUrl/my/public/file/$attachmentId';

/// Opens a project document in the themed in-app viewer when possible.
///
/// Prefer [attachmentId] so we resolve via `/api/get_attachment_details`
/// → `public_url` (`/my/public/file/<id>`) instead of external/broken URLs
/// that can 502 when launched outside the app.
Future<void> openProjectFileInApp(
  BuildContext context, {
  required String rawUrl,
  required String fileName,
  int? attachmentId,
}) async {
  final resolvedId =
      attachmentId ?? extractPublicAttachmentId(rawUrl);

  var displayName = fileName.trim().isNotEmpty ? fileName.trim() : 'Document';
  var mime = '';
  var normalizedUrl = normalizeProjectFileUrl(rawUrl);
  Uint8List? seededBytes;

  if (resolvedId != null) {
    // Always prefer the public preview endpoint for Odoo attachments.
    normalizedUrl = publicPreviewUrlForAttachment(resolvedId);

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
      final details = await DocumentAttachmentOpener.fetchAttachmentDetails(
        attachmentId: resolvedId,
      );
      final publicUrl = (details['public_url'] ?? '').toString().trim();
      if (publicUrl.isNotEmpty) {
        normalizedUrl = normalizeProjectFileUrl(publicUrl);
      }
      final apiName = (details['attachment_name'] ?? '').toString().trim();
      if (apiName.isNotEmpty) displayName = apiName;
      mime = (details['attachment_type'] ?? '').toString();
      final binary = (details['attachment_binary_data'] ?? '').toString().trim();
      if (binary.isNotEmpty) {
        try {
          seededBytes = base64Decode(binary);
        } catch (_) {
          seededBytes = null;
        }
      }
      dismissLoader();
    } catch (_) {
      dismissLoader();
      // Keep constructed /my/public/file/<id> — still better than external 502 URLs.
    }
  }

  if (normalizedUrl.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invalid file URL'),
        backgroundColor: ProjectsDashboardTheme.maroonDark,
      ),
    );
    return;
  }

  final isExcel = _looksLikeExcel(
    fileName: displayName,
    url: normalizedUrl,
    mime: mime,
  );
  if (isExcel) {
    final uri = Uri.parse(normalizedUrl);
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!context.mounted) return;
    if (!launched) {
      final launchedInBrowserView =
          await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      if (!context.mounted) return;
      if (!launchedInBrowserView) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open Excel file: $displayName'),
            backgroundColor: ProjectsDashboardTheme.maroonDark,
          ),
        );
      }
    }
    return;
  }

  final isImage = _looksLikeImage(
    fileName: displayName,
    url: normalizedUrl,
    mime: mime,
  );
  final isPdf = _isPdfBytes(seededBytes) ||
      (!isImage &&
      _looksLikePdf(
        fileName: displayName,
        url: normalizedUrl,
        mime: mime,
      ));

  if (!context.mounted) return;

  if (isPdf) {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectsFileViewerScreen(
          fileUrl: normalizedUrl,
          title: displayName,
          mode: ProjectsFileViewerMode.pdf,
          preferUnauthenticated: normalizedUrl.contains('/my/public/file/'),
          attachmentId: resolvedId,
          initialBytes: seededBytes,
        ),
      ),
    );
    return;
  }

  if (isImage) {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectsFileViewerScreen(
          fileUrl: normalizedUrl,
          title: displayName,
          mode: ProjectsFileViewerMode.image,
          preferUnauthenticated: normalizedUrl.contains('/my/public/file/'),
          attachmentId: resolvedId,
          initialBytes: seededBytes,
        ),
      ),
    );
    return;
  }

  // Non-previewable office/binary types only.
  final uri = Uri.parse(normalizedUrl);
  final launched = await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  );
  if (!context.mounted) return;
  if (!launched) {
    final launchedInBrowserView =
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!context.mounted) return;
    if (!launchedInBrowserView) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open file: $normalizedUrl'),
          backgroundColor: ProjectsDashboardTheme.maroonDark,
        ),
      );
    }
  }
}
