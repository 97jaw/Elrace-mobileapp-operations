import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/media_model.dart';
import '../theme/media_theme.dart';
import '../utils/media_share_utils.dart';
import 'media_gallery_sheet.dart';
import 'media_staggered_video_grid.dart';
import 'media_video_list_tile.dart';

/// Draggable sheet: pinned tabs + list or masonry grid.
class MediaVideosGallerySheet extends StatelessWidget {
  const MediaVideosGallerySheet({
    super.key,
    required this.scrollController,
    required this.videos,
    required this.isGridView,
    required this.onVideoTap,
    required this.onHandleTap,
    required this.filterTabs,
    this.singleVideoHero = false,
    this.emptyTitle,
    this.emptySubtitle,
  });

  final ScrollController scrollController;
  final List<MediaModel> videos;
  final bool isGridView;
  final void Function(MediaModel media) onVideoTap;
  final VoidCallback onHandleTap;
  final Widget filterTabs;
  final bool singleVideoHero;
  final String? emptyTitle;
  final String? emptySubtitle;

  @override
  Widget build(BuildContext context) {
    final title = emptyTitle ??
        (singleVideoHero ? 'No other videos yet' : 'No videos to show');
    return MediaGallerySheet(
      scrollController: scrollController,
      onHandleTap: onHandleTap,
      filterTabs: filterTabs,
      bodySlivers: videos.isEmpty
          ? [
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptySheetMessage(
                  title,
                  subtitle: emptySubtitle,
                ),
              ),
            ]
          : _buildContentSlivers(context),
    );
  }

  List<Widget> _buildContentSlivers(BuildContext context) {
    if (isGridView) {
      return [
        SliverToBoxAdapter(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 360),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.96, end: 1).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                  child: child,
                ),
              );
            },
            child: Padding(
              key: const ValueKey('grid'),
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
              child: MediaStaggeredVideoGrid(
                videos: videos,
                onVideoTap: onVideoTap,
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final media = videos[index];
            return Padding(
              padding: EdgeInsets.fromLTRB(16.w, index == 0 ? 8.h : 0, 8.w, 0),
              child: MediaVideoListTile(
                media: media,
                onTap: () => onVideoTap(media),
                onShare: () => _showShareMenu(context, media),
              ),
            );
          },
          childCount: videos.length,
        ),
      ),
    ];
  }

  void _showShareMenu(BuildContext context, MediaModel media) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MediaTheme.sheetBg,
      shape: const RoundedRectangleBorder(),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.ios_share_rounded, color: Colors.white),
              title: Text(
                'Share',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                MediaShareUtils.shareMedia(context, media);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySheetMessage(String message, {String? subtitle}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: MediaTheme.textSecondary,
              ),
            ),
            if (subtitle != null && subtitle.isNotEmpty) ...[
              SizedBox(height: 6.h),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
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
