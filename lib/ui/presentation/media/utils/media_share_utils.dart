import 'dart:io';

import 'package:el_race/utils/di.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/media_model.dart';
import '../repository/i_media_repository.dart';

abstract final class MediaShareUtils {
  static Future<void> shareMedia(
    BuildContext context,
    MediaModel media, {
    Rect? sharePositionOrigin,
  }) async {
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final origin = sharePositionOrigin ?? _defaultShareOrigin(context);

    messenger.showSnackBar(
      SnackBar(
        content: Text('Preparing share...', style: GoogleFonts.poppins()),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final repo = sl.get<IMediaRepository>();
      var shareUrl = await repo.prepareShare(media.id);
      shareUrl ??= media.xWebUrl ?? media.streamingUrl;
      shareUrl = _normalizeShareUrl(shareUrl.trim());

      if (shareUrl.isEmpty) {
        throw Exception('No URL available to share');
      }

      final thumbnail = await _downloadThumbnail(media.thumbnail);

      if (!context.mounted) return;

      if (thumbnail != null) {
        await SharePlus.instance.share(
          ShareParams(
            files: [thumbnail],
            text: '${media.displayName}\n$shareUrl',
            sharePositionOrigin: origin,
          ),
        );
      } else {
        await SharePlus.instance.share(
          ShareParams(
            text: '${media.displayName}\n$shareUrl',
            sharePositionOrigin: origin,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Failed to share: $e',
            style: GoogleFonts.poppins(),
          ),
        ),
      );
    }
  }

  static String _normalizeShareUrl(String raw) {
    if (raw.isEmpty) return raw;
    try {
      final uri = Uri.parse(raw);
      return uri
          .replace(
            path: uri.pathSegments
                .map((segment) => Uri.encodeComponent(segment))
                .join('/'),
          )
          .toString();
    } catch (_) {
      return raw.replaceAll(' ', '%20');
    }
  }

  static Rect _defaultShareOrigin(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final offset = box.localToGlobal(Offset.zero);
      return offset & box.size;
    }
    final size = MediaQuery.sizeOf(context);
    return Rect.fromLTWH(size.width / 2, size.height / 2, 1, 1);
  }

  static Future<XFile?> _downloadThumbnail(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;
      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/share_thumbnail_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      return XFile(filePath);
    } catch (_) {
      return null;
    }
  }
}
