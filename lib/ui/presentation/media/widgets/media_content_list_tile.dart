import 'package:flutter/material.dart';
import 'package:el_race/core/utils/responsive_breakpoints.dart';
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
          padding: EdgeInsets.symmetric(vertical: 8.th, horizontal: 4.tw),
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
                width: 88.tw,
                height: 56.th,
                child: MediaContentThumbnail(
                  content: content,
                  imageHeaders: imageHeaders,
                ),
              ),
              SizedBox(width: 12.tw),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      content.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14.tsp,
                        fontWeight: FontWeight.w600,
                        color: MediaTheme.white,
                      ),
                    ),
                    if (content.projectName.isNotEmpty) ...[
                      SizedBox(height: 3.th),
                      Text(
                        content.projectName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11.tsp,
                          color: MediaTheme.textMuted,
                        ),
                      ),
                    ],
                    if (date.isNotEmpty) ...[
                      SizedBox(height: 4.th),
                      Text(date, style: MediaTheme.labelSm),
                    ],
                  ],
                ),
              ),
              if (onShare != null)
                IconButton(
                  onPressed: onShare,
                  padding: EdgeInsets.zero,
                  constraints:
                      BoxConstraints(minWidth: 32.tw, minHeight: 32.tw),
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: MediaTheme.textSecondary,
                    size: 22.tsp,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
