import 'package:el_race/ui/presentation/my_projects/presentation/screens/projects_file_viewer_screen.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

Future<void> openProjectFileInApp(
  BuildContext context, {
  required String rawUrl,
  required String fileName,
}) async {
  final normalizedUrl = normalizeProjectFileUrl(rawUrl);
  if (normalizedUrl.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Invalid file URL'),
        backgroundColor: ProjectsDashboardTheme.maroonDark,
      ),
    );
    return;
  }

  final fileNameLower = fileName.toLowerCase();
  final urlLower = normalizedUrl.toLowerCase();
  final isPdf = fileNameLower.endsWith('.pdf') || urlLower.contains('.pdf');
  final isImage = fileNameLower.endsWith('.jpg') ||
      fileNameLower.endsWith('.jpeg') ||
      fileNameLower.endsWith('.png') ||
      fileNameLower.endsWith('.webp') ||
      fileNameLower.endsWith('.gif') ||
      urlLower.contains('.jpg') ||
      urlLower.contains('.jpeg') ||
      urlLower.contains('.png') ||
      urlLower.contains('.webp') ||
      urlLower.contains('.gif');

  if (isPdf) {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectsFileViewerScreen(
          fileUrl: normalizedUrl,
          title: fileName.isNotEmpty ? fileName : 'Document',
          mode: ProjectsFileViewerMode.pdf,
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
          title: fileName.isNotEmpty ? fileName : 'Image',
          mode: ProjectsFileViewerMode.image,
        ),
      ),
    );
    return;
  }

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
