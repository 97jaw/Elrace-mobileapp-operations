import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import '../data/media_model.dart';
import '../theme/media_theme.dart';
import '../utils/media_share_utils.dart';
import '../utils/media_video_preloader.dart';
import '../widgets/media_video_thumbnail.dart';

class YoYoVideoPlayerScreen extends StatefulWidget {
  const YoYoVideoPlayerScreen({
    super.key,
    required this.media,
    this.playlist,
    this.preloadedController,
  });

  final MediaModel media;
  final List<MediaModel>? playlist;
  final VideoPlayerController? preloadedController;

  @override
  State<YoYoVideoPlayerScreen> createState() => _YoYoVideoPlayerScreenState();
}

class _YoYoVideoPlayerScreenState extends State<YoYoVideoPlayerScreen> {
  VideoPlayerController? _videoController;
  bool _isInitialized = false;
  bool _ownsController = true;
  bool _isLandscape = false;
  late MediaModel _currentMedia;

  @override
  void initState() {
    super.initState();
    _currentMedia = widget.media;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initPlayer();
  }

  Future<void> _initPlayer({MediaModel? media}) async {
    final target = media ?? _currentMedia;
    await _disposePlayer();

    setState(() => _isInitialized = false);

    try {
      VideoPlayerController? controller = widget.preloadedController;
      if (controller != null &&
          target.id == widget.media.id &&
          controller.value.isInitialized) {
        _ownsController = false;
        MediaVideoPreloader.take(target.id);
      } else {
        controller = MediaVideoPreloader.peek(target.id);
        if (controller != null && controller.value.isInitialized) {
          _ownsController = false;
        } else {
          controller = await MediaVideoPreloader.preload(
            target,
            loop: false,
            muted: false,
          );
          _ownsController = false;
        }
      }

      if (controller == null) {
        final url = target.streamingUrl;
        controller = url.startsWith('assets/')
            ? VideoPlayerController.asset(url)
            : VideoPlayerController.networkUrl(
                Uri.parse(url),
                httpHeaders: const {
                  'Range': 'bytes=0-',
                  'Accept': 'video/*',
                },
              );
        _ownsController = true;
        await controller.initialize();
      }

      await controller.setLooping(false);
      await controller.setVolume(1);
      _videoController = controller;

      if (mounted) {
        setState(() => _isInitialized = true);
        await controller.play();
      }
    } catch (_) {
      if (mounted) setState(() => _isInitialized = false);
    }
  }

  Future<void> _disposePlayer() async {
    if (_videoController != null) {
      if (_ownsController) {
        await _videoController!.dispose();
      } else {
        await _videoController!.pause();
        MediaVideoPreloader.release(_currentMedia.id, _videoController!);
      }
    }
    _videoController = null;
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _disposePlayer();
    super.dispose();
  }

  Future<void> _toggleOrientation() async {
    if (_isLandscape) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    setState(() => _isLandscape = !_isLandscape);
  }

  Future<void> _shareVideo() async {
    await MediaShareUtils.shareMedia(context, _currentMedia);
  }

  void _openPlaylist() {
    final items = widget.playlist ?? [_currentMedia];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          maxChildSize: 0.85,
          minChildSize: 0.35,
          builder: (context, scrollController) {
            return MediaTheme.glassSheetBackground(
              child: Column(
                children: [
                  SizedBox(height: 10.h),
                  Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: MediaTheme.white.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Text(
                      'Videos',
                      style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: MediaTheme.white,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final isCurrent = item.id == _currentMedia.id;
                        return ListTile(
                          leading: SizedBox(
                            width: 56.w,
                            height: 40.h,
                            child: MediaVideoThumbnail(
                              media: item,
                              showPlayIcon: false,
                            ),
                          ),
                          title: Text(
                            item.displayName,
                            style: GoogleFonts.poppins(
                              color: isCurrent
                                  ? MediaTheme.white
                                  : MediaTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.sp,
                            ),
                          ),
                          subtitle: Text(
                            item.client ?? '',
                            style: GoogleFonts.poppins(
                              color: MediaTheme.textMuted,
                              fontSize: 11.sp,
                            ),
                          ),
                          onTap: () async {
                            Navigator.pop(context);
                            if (item.id == _currentMedia.id) return;
                            setState(() => _currentMedia = item);
                            await _initPlayer(media: item);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showMoreMenu() {
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
              leading: const Icon(Icons.share_outlined, color: Colors.white),
              title: Text('Share', style: GoogleFonts.poppins(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _shareVideo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.screen_rotation_outlined, color: Colors.white),
              title: Text('Rotate', style: GoogleFonts.poppins(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _toggleOrientation();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _videoController;
    final description =
        (_currentMedia.description ?? _currentMedia.client ?? '').trim();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_isInitialized && controller != null)
            Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio == 0
                    ? 16 / 9
                    : controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            )
          else
            Stack(
              fit: StackFit.expand,
              children: [
                MediaVideoThumbnail(
                  media: _currentMedia,
                  showPlayIcon: false,
                ),
                Container(
                  color: Colors.black45,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(color: Colors.white),
                ),
              ],
            ),
          if (!_isLandscape)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.82),
                  ],
                  stops: const [0.0, 0.22, 0.55, 1.0],
                ),
              ),
            ),
          if (_isLandscape)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 4.h,
              left: 4.w,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white,
                  size: 28.sp,
                ),
              ),
            )
          else
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            size: 30.sp,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _currentMedia.displayName,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _showMoreMenu,
                          icon: Icon(
                            Icons.more_horiz_rounded,
                            color: Colors.white,
                            size: 26.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (_isInitialized && controller != null)
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: _buildControls(controller, description),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControls(
    VideoPlayerController controller,
    String description,
  ) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final position = value.position;
        final duration = value.duration;
        final progress = duration.inMilliseconds > 0
            ? position.inMilliseconds / duration.inMilliseconds
            : 0.0;
        final remaining = duration - position;

        return Padding(
          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 52.w,
                    height: 52.w,
                    child: MediaVideoThumbnail(
                      media: _currentMedia,
                      showPlayIcon: false,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentMedia.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        if (description.isNotEmpty)
                          Text(
                            description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 12.sp,
                              color: Colors.white70,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape:
                      RoundSliderThumbShape(enabledThumbRadius: 5.r),
                  overlayShape:
                      RoundSliderOverlayShape(overlayRadius: 12.r),
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                ),
                child: Slider(
                  value: progress.clamp(0.0, 1.0),
                  onChanged: (v) {
                    final target = Duration(
                      milliseconds: (duration.inMilliseconds * v).round(),
                    );
                    controller.seekTo(target);
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(position),
                      style: GoogleFonts.poppins(
                        fontSize: 11.sp,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      '-${_formatDuration(remaining)}',
                      style: GoogleFonts.poppins(
                        fontSize: 11.sp,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      final target = position - const Duration(seconds: 10);
                      controller.seekTo(
                        target < Duration.zero ? Duration.zero : target,
                      );
                    },
                    icon: Icon(Icons.replay_10_rounded,
                        color: Colors.white, size: 28.sp),
                  ),
                  SizedBox(width: 24.w),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        value.isPlaying
                            ? controller.pause()
                            : controller.play();
                      },
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 64.w,
                        height: 64.w,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.black,
                          size: 36.sp,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 24.w),
                  IconButton(
                    onPressed: () {
                      final target = position + const Duration(seconds: 10);
                      controller.seekTo(
                        target > duration ? duration : target,
                      );
                    },
                    icon: Icon(Icons.forward_10_rounded,
                        color: Colors.white, size: 28.sp),
                  ),
                ],
              ),
              SizedBox(height: 4.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: _toggleOrientation,
                    icon: Icon(Icons.screen_rotation_outlined,
                        color: Colors.white, size: 24.sp),
                  ),
                  IconButton(
                    onPressed: _shareVideo,
                    icon: Icon(Icons.ios_share_rounded,
                        color: Colors.white, size: 24.sp),
                  ),
                  IconButton(
                    onPressed: _openPlaylist,
                    icon: Icon(Icons.queue_music_rounded,
                        color: Colors.white, size: 24.sp),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
