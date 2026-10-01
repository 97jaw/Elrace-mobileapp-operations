import 'package:flutter/material.dart';
import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../data/content_model.dart';
import '../theme/media_theme.dart';
import '../utils/media_pdf_pages.dart';
import 'media_pdf_cover_image.dart';

class MediaContentThumbnail extends StatelessWidget {
  const MediaContentThumbnail({
    super.key,
    required this.content,
    this.imageHeaders,
    this.borderRadius,
    this.showPlayIcon = false,
  });

  final ContentModel content;
  final Map<String, String>? imageHeaders;
  final BorderRadius? borderRadius;
  final bool showPlayIcon;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(MediaTheme.tileRadius);
    final url = content.displayImageUrl;

    Widget placeholder() {
      return Container(
        color: MediaTheme.sheetBg,
        alignment: Alignment.center,
        child: Icon(
          content.is360 ? Icons.threesixty : Icons.image_outlined,
          size: 32.tsp,
          color: MediaTheme.textMuted,
        ),
      );
    }

    final hasCover = (content.thumbnailUrl ?? '').trim().isNotEmpty;

    Widget image;
    if (!hasCover && MediaPdfPages.canRender(content)) {
      image = MediaPdfCoverImage(
        content: content,
        headers: imageHeaders,
        fallback: placeholder(),
      );
    } else if (url.isEmpty) {
      image = placeholder();
    } else {
      image = Image.network(
        url,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        headers: imageHeaders,
        errorBuilder: (_, __, ___) => placeholder(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
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

    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          image,
          if (showPlayIcon)
            Align(
              alignment: Alignment.center,
              child: Icon(
                Icons.play_circle_fill,
                size: 36.tsp,
                color: MediaTheme.white.withValues(alpha: 0.85),
              ),
            ),
          if (content.is360)
            Positioned(
              top: 6.th,
              right: 6.tw,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6.tw, vertical: 2.th),
                decoration: BoxDecoration(
                  color: MediaTheme.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(6.tr),
                ),
                child: Text(
                  '360°',
                  style: GoogleFonts.poppins(
                    fontSize: 9.tsp,
                    fontWeight: FontWeight.w700,
                    color: MediaTheme.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
