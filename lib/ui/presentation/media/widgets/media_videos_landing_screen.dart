import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/media_model.dart';
import '../theme/media_theme.dart';
import '../utils/media_hero_selector.dart';
import '../utils/media_share_utils.dart';
import '../utils/media_video_preloader.dart';
import 'media_filter_tabs.dart';
import 'media_hero_trailer.dart';
import 'media_videos_gallery_sheet.dart';

/// Full-bleed hero trailer + draggable peek/expanded gallery sheet.
class MediaVideosLandingScreen extends StatefulWidget {
  const MediaVideosLandingScreen({
    super.key,
    required this.mediaList,
    required this.onVideoTap,
    required this.onBack,
    required this.activeTabIndex,
    required this.videoCount,
    required this.photoCount,
    required this.view360Count,
    required this.onTabSelected,
  });

  final List<MediaModel> mediaList;
  final void Function(MediaModel media) onVideoTap;
  final VoidCallback onBack;
  final int activeTabIndex;
  final int videoCount;
  final int photoCount;
  final int view360Count;
  final ValueChanged<int> onTabSelected;

  @override
  State<MediaVideosLandingScreen> createState() =>
      _MediaVideosLandingScreenState();
}

class _MediaVideosLandingScreenState extends State<MediaVideosLandingScreen> {
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  bool _isExpanded = false;
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_onSheetChanged);
    _preloadVideos();
  }

  Future<void> _preloadVideos() async {
    await MediaVideoPreloader.preloadLandingVideos(widget.mediaList);
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant MediaVideosLandingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaList != widget.mediaList) {
      _preloadVideos();
    }
  }

  void _onSheetChanged() {
    if (!_sheetController.isAttached) return;
    final expanded = _sheetController.size >
        (MediaTheme.peekSheetSize + MediaTheme.expandedSheetSize) / 2;
    if (expanded != _isExpanded) {
      setState(() => _isExpanded = expanded);
    }
  }

  void _toggleSheet() {
    if (!_sheetController.isAttached) return;
    const mid =
        (MediaTheme.peekSheetSize + MediaTheme.expandedSheetSize) / 2;
    final target = _sheetController.size < mid
        ? MediaTheme.expandedSheetSize
        : MediaTheme.peekSheetSize;
    _sheetController.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _collapseSheet() {
    if (!_sheetController.isAttached) return;
    if (_sheetController.size > MediaTheme.peekSheetSize + 0.02) {
      _sheetController.animateTo(
        MediaTheme.peekSheetSize,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _showHeroMenu(MediaModel hero) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MediaTheme.sheetBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_circle_outline, color: Colors.white),
              title: Text(
                'Play video',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                widget.onVideoTap(hero);
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_rounded, color: Colors.white),
              title: Text(
                'Share',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                MediaShareUtils.shareMedia(context, hero);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetChanged);
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hero = MediaHeroSelector.selectHeroVideo(widget.mediaList);
    final remaining =
        MediaHeroSelector.remainingVideos(widget.mediaList, hero);
    final screenHeight = MediaQuery.sizeOf(context).height;

    if (hero == null) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: MediaTheme.lightStatusBar,
        child: Scaffold(
          backgroundColor: MediaTheme.black,
          body: MediaTheme.glassSheetBackground(
            child: SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(left: 16.w, top: 8.h),
                      child: MediaTheme.backButton(onTap: widget.onBack),
                    ),
                  ),
                  Expanded(child: _buildNoVideosEmpty()),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final filterTabs = MediaFilterTabs(
      activeIndex: widget.activeTabIndex,
      videoCount: widget.videoCount,
      photoCount: widget.photoCount,
      view360Count: widget.view360Count,
      onTabSelected: widget.onTabSelected,
      isGridView: _isGridView,
      onToggleView: () => setState(() => _isGridView = !_isGridView),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: MediaTheme.lightStatusBar,
      child: Scaffold(
        backgroundColor: MediaTheme.black,
        body: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _sheetController,
            builder: (context, _) {
              final extent = _sheetController.isAttached
                  ? _sheetController.size
                  : MediaTheme.peekSheetSize;
              final heroHeight = screenHeight * (1 - extent);

              return Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: heroHeight.clamp(0.0, screenHeight),
                    child: RepaintBoundary(
                      child: MediaHeroTrailer(
                        key: ValueKey(hero.id),
                        media: hero,
                        onTap: _isExpanded
                            ? _collapseSheet
                            : () => widget.onVideoTap(hero),
                        onPlay: () => widget.onVideoTap(hero),
                        onBack: widget.onBack,
                        onMore: () => _showHeroMenu(hero),
                      ),
                    ),
                  ),
                  DraggableScrollableSheet(
                    controller: _sheetController,
                    initialChildSize: MediaTheme.peekSheetSize,
                    minChildSize: MediaTheme.peekSheetSize,
                    maxChildSize: MediaTheme.expandedSheetSize,
                    snap: true,
                    snapSizes: const [
                      MediaTheme.peekSheetSize,
                      MediaTheme.expandedSheetSize,
                    ],
                    builder: (context, scrollController) {
                      return ClipRect(
                        child: MediaVideosGallerySheet(
                          scrollController: scrollController,
                          videos: remaining,
                          isGridView: _isGridView,
                          onVideoTap: widget.onVideoTap,
                          onHandleTap: _toggleSheet,
                          filterTabs: filterTabs,
                          singleVideoHero: remaining.isEmpty,
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNoVideosEmpty() {
    return Padding(
      padding: EdgeInsets.all(32.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.videocam_off_outlined,
            size: 64.sp,
            color: MediaTheme.textMuted,
          ),
          SizedBox(height: 16.h),
          Text(
            'No videos yet',
            style: GoogleFonts.poppins(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: MediaTheme.textSecondary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Your video collection will appear here',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              color: MediaTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
