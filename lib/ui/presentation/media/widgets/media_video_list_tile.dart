import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../data/media_model.dart';
import '../theme/media_theme.dart';
import 'media_video_thumbnail.dart';

/// Faded row for peek-state vertical list.
class MediaVideoListTile extends StatelessWidget {
  const MediaVideoListTile({
    super.key,
    required this.media,
    required this.onTap,
    this.onShare,
    this.faded = true,
  });

  final MediaModel media;
  final VoidCallback onTap;
  final VoidCallback? onShare;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final opacity = faded ? 0.85 : 1.0;
    final description = (media.description ?? media.client ?? '').trim();
    final date = DateFormat('dd/MM/yyyy').format(media.dateCreated);

    return Opacity(
      opacity: opacity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MediaTheme.tileRadius),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 88.w,
                  height: 56.h,
                  child: MediaVideoThumbnail(
                    media: media,
                    showPlayIcon: true,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        media.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: MediaTheme.white,
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        SizedBox(height: 3.h),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w400,
                            color: MediaTheme.textMuted,
                          ),
                        ),
                      ],
                      SizedBox(height: 4.h),
                      Text(
                        date,
                        style: MediaTheme.labelSm,
                      ),
                    ],
                  ),
                ),
                if (onShare != null)
                  IconButton(
                    onPressed: onShare,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: 32.w, minHeight: 32.w),
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      color: MediaTheme.textSecondary,
                      size: 22.sp,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
