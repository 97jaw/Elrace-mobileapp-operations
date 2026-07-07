import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/content_model.dart';

abstract final class MediaContentShareUtils {
  static Future<void> shareContent(ContentModel content) async {
    final url = content.previewUrl.trim();
    if (url.isEmpty) return;
    await SharePlus.instance.share(
      ShareParams(text: '${content.displayName}\n$url'),
    );
  }
}
