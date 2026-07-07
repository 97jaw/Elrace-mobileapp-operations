import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/media_model.dart';
import '../theme/media_theme.dart';
import 'media_video_thumbnail.dart';

/// Grid/masonry cell with thumbnail + title.
class MediaVideoGridTile extends StatelessWidget {
  const MediaVideoGridTile({
    super.key,
    required this.media,
    required this.onTap,
  });

  final MediaModel media;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final description = (media.description ?? media.client ?? '').trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MediaTheme.gridRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: MediaVideoThumbnail(
                media: media,
                borderRadius: BorderRadius.circular(MediaTheme.gridRadius),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              media.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: MediaTheme.white,
              ),
            ),
            if (description.isNotEmpty) ...[
              SizedBox(height: 2.h),
              Text(
                description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w400,
                  color: MediaTheme.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
