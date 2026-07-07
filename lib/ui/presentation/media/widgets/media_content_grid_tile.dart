import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/content_model.dart';
import '../theme/media_theme.dart';
import 'media_content_thumbnail.dart';

class MediaContentGridTile extends StatelessWidget {
  const MediaContentGridTile({
    super.key,
    required this.content,
    required this.onTap,
    this.imageHeaders,
  });

  final ContentModel content;
  final VoidCallback onTap;
  final Map<String, String>? imageHeaders;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MediaTheme.gridRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: MediaContentThumbnail(
                content: content,
                imageHeaders: imageHeaders,
                borderRadius: BorderRadius.circular(MediaTheme.gridRadius),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              content.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: MediaTheme.white,
              ),
            ),
            if (content.projectName.isNotEmpty) ...[
              SizedBox(height: 2.h),
              Text(
                content.projectName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 10.sp,
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
