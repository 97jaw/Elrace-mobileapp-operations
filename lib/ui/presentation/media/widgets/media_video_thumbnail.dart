import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../data/media_model.dart';
import '../theme/media_theme.dart';

/// Shared thumbnail for list/grid tiles.
class MediaVideoThumbnail extends StatelessWidget {
  const MediaVideoThumbnail({
    super.key,
    required this.media,
    this.borderRadius,
    this.showPlayIcon = true,
  });

  final MediaModel media;
  final BorderRadius? borderRadius;
  final bool showPlayIcon;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(MediaTheme.tileRadius);
    final url = media.previewUrl;

    Widget placeholder() {
      return Container(
        color: MediaTheme.sheetBg,
        alignment: Alignment.center,
        child: Icon(
          Icons.play_circle_outline,
          size: 32.sp,
          color: MediaTheme.textMuted,
        ),
      );
    }

    Widget image;
    if (url.startsWith('assets/')) {
      image = Image.asset(
        url,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => placeholder(),
      );
    } else if (url.isEmpty) {
      image = placeholder();
    } else {
      image = Image.network(
        url,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => placeholder(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            color: MediaTheme.sheetBg,
            alignment: Alignment.center,
            child: SizedBox(
              width: 20.w,
              height: 20.w,
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
                size: 36.sp,
                color: MediaTheme.white.withValues(alpha: 0.85),
              ),
            ),
        ],
      ),
    );
  }
}
