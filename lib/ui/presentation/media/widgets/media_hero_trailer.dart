import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../data/media_model.dart';
import '../theme/media_theme.dart';
import '../utils/media_video_preloader.dart';
import 'media_video_thumbnail.dart';

/// Muted looping hero trailer with plain-text metadata overlay.
class MediaHeroTrailer extends StatefulWidget {
  const MediaHeroTrailer({
    super.key,
    required this.media,
    required this.onTap,
    required this.onPlay,
    this.onBack,
    this.onMore,
  });

  final MediaModel media;
  final VoidCallback onTap;
  final VoidCallback onPlay;
  final VoidCallback? onBack;
  final VoidCallback? onMore;

  @override
  State<MediaHeroTrailer> createState() => _MediaHeroTrailerState();
}

class _MediaHeroTrailerState extends State<MediaHeroTrailer> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _failed = false;
  bool _ownsController = true;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void didUpdateWidget(covariant MediaHeroTrailer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.id != widget.media.id) {
      _disposePlayer();
      _initPlayer();
    }
  }

  Future<void> _initPlayer() async {
    setState(() {
      _initialized = false;
      _failed = false;
    });

    final controller = await MediaVideoPreloader.preload(
      widget.media,
      loop: true,
      muted: true,
      autoplay: true,
    );

    if (!mounted) return;

    if (controller == null) {
      setState(() => _failed = true);
      return;
    }

    _controller = controller;
    _ownsController = false;
    setState(() => _initialized = true);
  }

  Future<void> _disposePlayer() async {
    if (_controller != null && _ownsController) {
      await _controller!.dispose();
    }
    _controller = null;
    _initialized = false;
    _ownsController = true;
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  Widget _buildClientLogo() {
    final logoUrl = widget.media.clientLogo;
    if (logoUrl == null || logoUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8.r),
      child: Image.network(
        logoUrl,
        width: 28.w,
        height: 28.w,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top + 8.h;

    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: MediaTheme.black),
          if (_initialized && _controller != null)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),
            )
          else if (_failed)
            MediaVideoThumbnail(media: widget.media, showPlayIcon: true)
          else
            Stack(
              fit: StackFit.expand,
              children: [
                MediaVideoThumbnail(media: widget.media, showPlayIcon: false),
                Container(
                  color: MediaTheme.black.withValues(alpha: 0.35),
                  alignment: Alignment.center,
                  child: CircularProgressIndicator(
                    color: MediaTheme.textMuted,
                    strokeWidth: 2,
                  ),
                ),
              ],
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: MediaTheme.heroBottomScrim,
            ),
          ),
          Positioned(
            top: topPadding,
            left: 16.w,
            right: 16.w,
            child: Row(
              children: [
                if (widget.onBack != null)
                  MediaTheme.backButton(onTap: widget.onBack!)
                else
                  const SizedBox(width: 40),
                const Spacer(),
                if (widget.onMore != null)
                  MediaTheme.moreButton(onTap: widget.onMore!),
              ],
            ),
          ),
          Positioned(
            left: 16.w,
            right: 16.w,
            bottom: 20.h,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildClientLogo(),
                          if (widget.media.clientLogo != null &&
                              widget.media.clientLogo!.isNotEmpty)
                            SizedBox(width: 10.w),
                          Expanded(
                            child: Text(
                              widget.media.displayName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: MediaTheme.titleLg,
                            ),
                          ),
                        ],
                      ),
                      if ((widget.media.client ?? '').isNotEmpty) ...[
                        SizedBox(height: 4.h),
                        Text(
                          widget.media.client!,
                          style: GoogleFonts.poppins(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            color: MediaTheme.textSecondary,
                          ),
                        ),
                      ],
                      SizedBox(height: 4.h),
                      Text(
                        _formatDate(widget.media.dateCreated),
                        style: MediaTheme.labelSm,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12.w),
                MediaTheme.playButton(onTap: widget.onPlay),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
