import 'package:flutter/material.dart';
import 'package:el_race/core/utils/responsive_breakpoints.dart';
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
  String? _pinnedId;

  @override
  void initState() {
    super.initState();
    MediaVideoPreloader.suspended.addListener(_onSuspendedChanged);
    _initPlayer();
  }

  void _onSuspendedChanged() {
    if (!mounted) return;
    if (MediaVideoPreloader.suspended.value) {
      // The preloader disposes the controller after this frame.
      _releaseController();
      setState(() {});
    } else {
      _initPlayer();
    }
  }

  void _onControllerValue() {
    final controller = _controller;
    if (controller == null || !controller.value.hasError || _failed) return;
    debugPrint(
        'MediaHeroTrailer: playback error: ${controller.value.errorDescription}');
    _releaseController();
    MediaVideoPreloader.disposeId(widget.media.id);
    if (mounted) setState(() => _failed = true);
  }

  void _releaseController() {
    _controller?.removeListener(_onControllerValue);
    final pinned = _pinnedId;
    _pinnedId = null;
    if (pinned != null) MediaVideoPreloader.unpin(pinned);
    _controller = null;
    _initialized = false;
  }

  @override
  void didUpdateWidget(covariant MediaHeroTrailer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.id != widget.media.id) {
      _releaseController();
      _initPlayer();
    }
  }

  Future<void> _initPlayer() async {
    if (MediaVideoPreloader.suspended.value) return;
    setState(() {
      _initialized = false;
      _failed = false;
    });

    final mediaId = widget.media.id;
    MediaVideoPreloader.pin(mediaId);
    _pinnedId = mediaId;
    final controller = await MediaVideoPreloader.preload(
      widget.media,
      loop: true,
      muted: true,
      autoplay: true,
    );

    if (!mounted || _pinnedId != mediaId) return;

    if (controller == null) {
      // Suspended mid-load is not a failure; the thumbnail shows until resume.
      if (!MediaVideoPreloader.suspended.value) {
        setState(() => _failed = true);
      }
      return;
    }

    _controller = controller..addListener(_onControllerValue);
    setState(() => _initialized = true);
  }

  @override
  void dispose() {
    MediaVideoPreloader.suspended.removeListener(_onSuspendedChanged);
    _releaseController();
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
      borderRadius: BorderRadius.circular(8.tr),
      child: Image.network(
        logoUrl,
        width: 28.tw,
        height: 28.tw,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top + 8.th;

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
            left: 16.tw,
            right: 16.tw,
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
            left: 16.tw,
            right: 16.tw,
            bottom: 20.th,
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
                            SizedBox(width: 10.tw),
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
                        SizedBox(height: 4.th),
                        Text(
                          widget.media.client!,
                          style: GoogleFonts.poppins(
                            fontSize: 13.tsp,
                            fontWeight: FontWeight.w500,
                            color: MediaTheme.textSecondary,
                          ),
                        ),
                      ],
                      SizedBox(height: 4.th),
                      Text(
                        _formatDate(widget.media.dateCreated),
                        style: MediaTheme.labelSm,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12.tw),
                MediaTheme.playButton(onTap: widget.onPlay),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
