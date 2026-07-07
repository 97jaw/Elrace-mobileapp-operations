import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../data/content_model.dart';
import '../theme/media_theme.dart';

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
          size: 32.sp,
          color: MediaTheme.textMuted,
        ),
      );
    }

    Widget image;
    if (url.isEmpty) {
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
          if (content.is360)
            Positioned(
              top: 6.h,
              right: 6.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: MediaTheme.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  '360°',
                  style: GoogleFonts.poppins(
                    fontSize: 9.sp,
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
