import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/content_model.dart';
import '../theme/media_theme.dart';
import '../utils/media_content_share_utils.dart';
import 'media_content_hero.dart';
import 'media_content_list_tile.dart';
import 'media_filter_tabs.dart';
import 'media_gallery_sheet.dart';
import 'media_photo_viewer.dart';
import 'media_staggered_content_grid.dart';

/// Photos / 360° landing with swipeable hero card + pinned tabs + list/grid.
class MediaContentLandingScreen extends StatefulWidget {
  const MediaContentLandingScreen({
    super.key,
    required this.items,
    required this.is360Mode,
    required this.onBack,
    required this.activeTabIndex,
    required this.videoCount,
    required this.photoCount,
    required this.view360Count,
    required this.onTabSelected,
    this.showProjectVideos = false,
    this.projectVideoCount = 0,
    this.imageHeaders,
    this.onOpenPhoto,
    this.onOpen360,
  });

  final List<ContentModel> items;
  final bool is360Mode;
  final VoidCallback onBack;
  final int activeTabIndex;
  final int videoCount;
  final int photoCount;
  final int view360Count;
  final ValueChanged<int> onTabSelected;
  final bool showProjectVideos;
  final int projectVideoCount;
  final Map<String, String>? imageHeaders;
  final void Function(ContentModel content)? onOpenPhoto;
  final void Function(ContentModel content)? onOpen360;

  @override
  State<MediaContentLandingScreen> createState() =>
      _MediaContentLandingScreenState();
}

class _MediaContentLandingScreenState extends State<MediaContentLandingScreen> {
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final PageController _heroPageController = PageController();

  bool _isExpanded = false;
  bool _isGridView = false;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_onSheetChanged);
  }

  @override
  void didUpdateWidget(covariant MediaContentLandingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items && widget.items.isNotEmpty) {
      _currentIndex = 0;
      if (_heroPageController.hasClients) {
        _heroPageController.jumpToPage(0);
      }
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

  void _jumpToIndex(int index) {
    if (index < 0 || index >= widget.items.length) return;
    setState(() => _currentIndex = index);
    _heroPageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  ContentModel? get _current =>
      widget.items.isEmpty ? null : widget.items[_currentIndex];

  Future<void> _openPrimary() async {
    final item = _current;
    if (item == null) return;
    if (widget.is360Mode) {
      widget.onOpen360?.call(item);
      final url = Uri.parse(item.previewUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } else if (widget.onOpenPhoto != null) {
      widget.onOpenPhoto!(item);
    } else {
      _showPhotoPreview(item);
    }
  }

  void _showPhotoPreview(ContentModel item) {
    final index = widget.items.indexWhere((e) => e.id == item.id);
    MediaPhotoViewer.open(
      context,
      items: widget.items
          .map(
            (e) => MediaPhotoViewerItem(
              imageUrl: e.displayImageUrl,
              title: e.displayName,
              subtitle: e.projectName,
            ),
          )
          .toList(),
      initialIndex: index < 0 ? 0 : index,
      imageHeaders: widget.imageHeaders,
    );
  }

  void _showShareMenu(ContentModel item) {
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
              title: Text('Share', style: GoogleFonts.poppins(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheetContext);
                MediaContentShareUtils.shareContent(item);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showHeroMenu() {
    final item = _current;
    if (item == null) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MediaTheme.sheetBg,
      shape: const RoundedRectangleBorder(),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                widget.is360Mode ? Icons.threesixty : Icons.image_outlined,
                color: Colors.white,
              ),
              title: Text(
                widget.is360Mode ? 'Open 360° view' : 'View photo',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(context);
                _openPrimary();
              },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share_rounded, color: Colors.white),
              title: Text('Share', style: GoogleFonts.poppins(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                MediaContentShareUtils.shareContent(item);
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
    _heroPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    if (widget.items.isEmpty) {
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
                  Expanded(
                    child: Center(
                      child: Text(
                        widget.is360Mode ? 'No 360° content yet' : 'No photos yet',
                        style: GoogleFonts.poppins(
                          color: MediaTheme.textMuted,
                          fontSize: 16.sp,
                        ),
                      ),
                    ),
                  ),
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
      showProjectVideos: widget.showProjectVideos,
      projectVideoCount: widget.projectVideoCount,
      isGridView: _isGridView,
      onToggleView: () => setState(() => _isGridView = !_isGridView),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: MediaTheme.lightStatusBar,
      child: Scaffold(
        backgroundColor: MediaTheme.black,
        body: AnimatedBuilder(
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
                  child: MediaContentHero(
                    items: widget.items,
                    pageController: _heroPageController,
                    currentIndex: _currentIndex,
                    onPageChanged: (i) => setState(() => _currentIndex = i),
                    is360Mode: widget.is360Mode,
                    onBack: widget.onBack,
                    onMore: _showHeroMenu,
                    onPrimaryAction: _openPrimary,
                    imageHeaders: widget.imageHeaders,
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
                        child: MediaGallerySheet(
                          scrollController: scrollController,
                          onHandleTap: _toggleSheet,
                          filterTabs: filterTabs,
                          bodySlivers: _buildBodySlivers(),
                        ),
                      );
                    },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildBodySlivers() {
    if (_isGridView) {
      return [
        SliverToBoxAdapter(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 360),
            child: Padding(
              key: const ValueKey('grid'),
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
              child: MediaStaggeredContentGrid(
                items: widget.items,
                imageHeaders: widget.imageHeaders,
                onItemTap: (item) {
                  final idx = widget.items.indexWhere((e) => e.id == item.id);
                  _jumpToIndex(idx);
                },
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
            final item = widget.items[index];
            return Padding(
              padding: EdgeInsets.fromLTRB(16.w, index == 0 ? 8.h : 0, 8.w, 0),
              child: MediaContentListTile(
                content: item,
                imageHeaders: widget.imageHeaders,
                isActive: index == _currentIndex,
                onTap: () => _jumpToIndex(index),
                onShare: () => _showShareMenu(item),
              ),
            );
          },
          childCount: widget.items.length,
        ),
      ),
    ];
  }
}
