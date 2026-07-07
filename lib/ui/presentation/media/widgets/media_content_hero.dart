import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../data/content_model.dart';
import '../theme/media_theme.dart';
import 'media_content_thumbnail.dart';

/// Profile-style swipeable hero card for photos / 360° content.
class MediaContentHero extends StatefulWidget {
  const MediaContentHero({
    super.key,
    required this.items,
    required this.pageController,
    required this.currentIndex,
    required this.onPageChanged,
    required this.is360Mode,
    this.onBack,
    this.onMore,
    this.onPrimaryAction,
    this.imageHeaders,
  });

  final List<ContentModel> items;
  final PageController pageController;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  final bool is360Mode;
  final VoidCallback? onBack;
  final VoidCallback? onMore;
  final VoidCallback? onPrimaryAction;
  final Map<String, String>? imageHeaders;

  @override
  State<MediaContentHero> createState() => _MediaContentHeroState();
}

class _MediaContentHeroState extends State<MediaContentHero> {
  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('dd MMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final topPadding = MediaQuery.paddingOf(context).top + 8.h;
    final index = widget.currentIndex.clamp(0, widget.items.length - 1);
    final item = widget.items[index];

    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, topPadding, 12.w, 10.h),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(MediaTheme.heroCardRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: widget.pageController,
                itemCount: widget.items.length,
                onPageChanged: widget.onPageChanged,
                itemBuilder: (context, index) {
                  return MediaContentThumbnail(
                    content: widget.items[index],
                    imageHeaders: widget.imageHeaders,
                    borderRadius: BorderRadius.zero,
                  );
                },
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: MediaTheme.heroBottomScrim,
                ),
              ),
              Positioned(
                top: 8.h,
                left: 8.w,
                right: 8.w,
                child: Row(
                  children: [
                    if (widget.onBack != null)
                      MediaTheme.backButton(onTap: widget.onBack!)
                    else
                      SizedBox(width: 40.w),
                    const Spacer(),
                    if (widget.items.length > 1)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: MediaTheme.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${index + 1}/${widget.items.length}',
                          style: GoogleFonts.poppins(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: MediaTheme.white,
                          ),
                        ),
                      ),
                    SizedBox(width: 8.w),
                    if (widget.onMore != null)
                      MediaTheme.moreButton(onTap: widget.onMore!),
                  ],
                ),
              ),
              Positioned(
                left: 16.w,
                right: 16.w,
                bottom: 16.h,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: MediaTheme.titleLg,
                          ),
                          if (item.projectName.isNotEmpty) ...[
                            SizedBox(height: 4.h),
                            Text(
                              item.projectName,
                              style: GoogleFonts.poppins(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w500,
                                color: MediaTheme.textSecondary,
                              ),
                            ),
                          ],
                          if (item.dateCreated != null) ...[
                            SizedBox(height: 4.h),
                            Text(
                              _formatDate(item.dateCreated),
                              style: MediaTheme.labelSm,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.onPrimaryAction != null) ...[
                      SizedBox(width: 12.w),
                      MediaTheme.pillButton(
                        label: widget.is360Mode ? 'View 360°' : 'View',
                        onTap: widget.onPrimaryAction!,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
    );
  }
}
