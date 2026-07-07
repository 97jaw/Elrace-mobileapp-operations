import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../data/content_model.dart';
import '../theme/media_theme.dart';
import 'media_content_thumbnail.dart';

class MediaContentListTile extends StatelessWidget {
  const MediaContentListTile({
    super.key,
    required this.content,
    required this.onTap,
    this.onShare,
    this.imageHeaders,
    this.isActive = false,
  });

  final ContentModel content;
  final VoidCallback onTap;
  final VoidCallback? onShare;
  final Map<String, String>? imageHeaders;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final date = content.dateCreated == null
        ? ''
        : DateFormat('dd/MM/yyyy').format(content.dateCreated!);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MediaTheme.tileRadius),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
          decoration: isActive
              ? BoxDecoration(
                  color: MediaTheme.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(MediaTheme.tileRadius),
                )
              : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 88.w,
                height: 56.h,
                child: MediaContentThumbnail(
                  content: content,
                  imageHeaders: imageHeaders,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      content.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: MediaTheme.white,
                      ),
                    ),
                    if (content.projectName.isNotEmpty) ...[
                      SizedBox(height: 3.h),
                      Text(
                        content.projectName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11.sp,
                          color: MediaTheme.textMuted,
                        ),
                      ),
                    ],
                    if (date.isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      Text(date, style: MediaTheme.labelSm),
                    ],
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
    );
  }
}
