import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:el_race/core/utils/responsive_breakpoints.dart';

import '../data/content_model.dart';
import '../theme/media_theme.dart';
import '../utils/media_pdf_pages.dart';

/// Card image for a Photos-tab file without an uploaded cover: the first
/// page of the PDF (or the image itself).
class MediaPdfCoverImage extends StatefulWidget {
  const MediaPdfCoverImage({
    super.key,
    required this.content,
    required this.fallback,
    this.headers,
    this.fit = BoxFit.cover,
  });

  final ContentModel content;
  final Widget fallback;
  final Map<String, String>? headers;
  final BoxFit fit;

  @override
  State<MediaPdfCoverImage> createState() => _MediaPdfCoverImageState();
}

class _MediaPdfCoverImageState extends State<MediaPdfCoverImage> {
  Uint8List? _bytes;
  Future<Uint8List>? _future;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant MediaPdfCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (MediaPdfPages.cacheKey(oldWidget.content) !=
        MediaPdfPages.cacheKey(widget.content)) {
      _resolve();
    }
  }

  void _resolve() {
    _bytes = MediaPdfPages.cachedCover(widget.content);
    _future = _bytes == null
        ? MediaPdfPages.cover(widget.content, headers: widget.headers)
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final ready = _bytes;
    if (ready != null) return _image(ready);

    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data != null) return _image(data);
        if (snapshot.hasError) return widget.fallback;
        return Container(
          color: MediaTheme.sheetBg,
          alignment: Alignment.center,
          child: SizedBox(
            width: 20.tw,
            height: 20.tw,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: MediaTheme.textMuted,
            ),
          ),
        );
      },
    );
  }

  Widget _image(Uint8List bytes) {
    return Image.memory(
      bytes,
      fit: widget.fit,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => widget.fallback,
    );
  }
}
