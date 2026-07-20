import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// One page in [MediaPhotoViewer].
class MediaPhotoViewerItem {
  const MediaPhotoViewerItem({
    required this.imageUrl,
    this.title,
    this.subtitle,
  });

  final String imageUrl;
  final String? title;
  final String? subtitle;
}

/// Fullscreen photo gallery: dark backdrop, [PageView], pinch-zoom, close,
/// and page indicator.
class MediaPhotoViewer extends StatefulWidget {
  const MediaPhotoViewer({
    super.key,
    required this.items,
    this.initialIndex = 0,
    this.imageHeaders,
  });

  final List<MediaPhotoViewerItem> items;
  final int initialIndex;
  final Map<String, String>? imageHeaders;

  /// Opens as a fullscreen opaque route (preferred over [Dialog]).
  static Future<void> open(
    BuildContext context, {
    required List<MediaPhotoViewerItem> items,
    int initialIndex = 0,
    Map<String, String>? imageHeaders,
  }) {
    if (items.isEmpty) return Future.value();
    final safeIndex = initialIndex.clamp(0, items.length - 1).toInt();
    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, __, ___) => MediaPhotoViewer(
          items: items,
          initialIndex: safeIndex,
          imageHeaders: imageHeaders,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<MediaPhotoViewer> createState() => _MediaPhotoViewerState();
}

class _MediaPhotoViewerState extends State<MediaPhotoViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex =
        widget.initialIndex.clamp(0, widget.items.length - 1).toInt();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _safeImageUrl(String rawUrl) {
    final input = rawUrl.trim();
    if (input.isEmpty) return input;
    return Uri.encodeFull(input);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_currentIndex];
    final title = item.title?.trim();
    final subtitle = item.subtitle?.trim();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: widget.items.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemBuilder: (context, index) {
                  final page = widget.items[index];
                  return InteractiveViewer(
                    key: ValueKey('photo-zoom-$index'),
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: page.imageUrl.isEmpty
                          ? Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white54,
                              size: 48.sp,
                            )
                          : Image.network(
                              _safeImageUrl(page.imageUrl),
                              headers: widget.imageHeaders,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                );
                              },
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.error_outline,
                                color: Colors.white54,
                                size: 48.sp,
                              ),
                            ),
                    ),
                  );
                },
              ),
              Positioned(
                top: 4.h,
                right: 8.w,
                child: IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  tooltip: 'Close',
                  icon: Container(
                    padding: EdgeInsets.all(6.w),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 22.sp,
                    ),
                  ),
                ),
              ),
              if (widget.items.length > 1)
                Positioned(
                  top: 12.h,
                  left: 16.w,
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      '${_currentIndex + 1}/${widget.items.length}',
                      style: GoogleFonts.poppins(
                        fontSize: 12.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if ((title != null && title.isNotEmpty) ||
                  (subtitle != null && subtitle.isNotEmpty))
                Positioned(
                  left: 16.w,
                  right: 16.w,
                  bottom: 16.h,
                  child: Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (title != null && title.isNotEmpty)
                          Text(
                            title,
                            style: GoogleFonts.poppins(
                              fontSize: 15.sp,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (subtitle != null && subtitle.isNotEmpty) ...[
                          SizedBox(height: 4.h),
                          Text(
                            subtitle,
                            style: GoogleFonts.poppins(
                              fontSize: 12.sp,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
