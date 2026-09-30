import 'dart:async';
import 'package:el_race/core/utils/responsive_breakpoints.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import '../data/media_model.dart';
import '../theme/media_theme.dart';
import 'package:el_race/core/utils/app_orientations.dart';

import '../utils/media_layout.dart';
import '../utils/media_share_utils.dart';
import '../utils/media_video_preloader.dart';
import '../widgets/media_video_thumbnail.dart';

class YoYoVideoPlayerScreen extends StatefulWidget {
  const YoYoVideoPlayerScreen({
    super.key,
    required this.media,
    this.playlist,
  });

  final MediaModel media;
  final List<MediaModel>? playlist;

  @override
  State<YoYoVideoPlayerScreen> createState() => _YoYoVideoPlayerScreenState();
}

enum _PlayerPhase { loading, ready, error }

class _YoYoVideoPlayerScreenState extends State<YoYoVideoPlayerScreen> {
  static const Duration _initTimeout = Duration(seconds: 30);

  /// Decoders are released asynchronously by the OS, so the first attempt
  /// right after freeing them can still hit NO_MEMORY.
  static const Duration _decoderRetryDelay = Duration(milliseconds: 700);

  static const Duration _controlsHideDelay = Duration(seconds: 3);
  static const Duration _seekStep = Duration(seconds: 10);

  VideoPlayerController? _videoController;
  _PlayerPhase _phase = _PlayerPhase.loading;
  String? _errorMessage;
  late MediaModel _currentMedia;

  /// Bumped on every load so a slow load for a previous video is discarded.
  int _loadId = 0;
  bool _autoRetried = false;

  bool _controlsVisible = true;
  Timer? _hideTimer;

  /// Slider position while the user drags; seeking happens on release so
  /// streams are not asked to seek on every frame of the drag.
  double? _dragValue;
  double _doubleTapDx = 0;

  bool _isFullscreen = false;

  bool get _isLandscape =>
      MediaQuery.orientationOf(context) == Orientation.landscape;

  @override
  void initState() {
    super.initState();
    _currentMedia = widget.media;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initPlayer();
  }

  Future<void> _initPlayer({MediaModel? media, bool isRetry = false}) async {
    final target = media ?? _currentMedia;
    final loadId = ++_loadId;
    if (!isRetry) _autoRetried = false;

    await _disposePlayer();
    if (!mounted || loadId != _loadId) return;
    setState(() {
      _phase = _PlayerPhase.loading;
      _errorMessage = null;
      _dragValue = null;
    });

    await MediaVideoPreloader.suspend();
    if (!mounted || loadId != _loadId) return;

    final controller = _createController(target);
    try {
      await controller.initialize().timeout(_initTimeout);
      if (!mounted || loadId != _loadId) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(false);
      await controller.setVolume(1);
      controller.addListener(_onControllerValue);
      _videoController = controller;
      setState(() => _phase = _PlayerPhase.ready);
      await controller.play();
      _showControls();
    } catch (e) {
      await controller.dispose();
      if (!mounted || loadId != _loadId) return;
      _handleError(e.toString());
    }
  }

  VideoPlayerController _createController(MediaModel media) {
    final url = media.streamingUrl;
    final options = VideoPlayerOptions(mixWithOthers: false);
    if (url.startsWith('assets/')) {
      return VideoPlayerController.asset(url, videoPlayerOptions: options);
    }
    return VideoPlayerController.networkUrl(
      Uri.parse(url),
      videoPlayerOptions: options,
    );
  }

  /// Decoder failures surface after initialize(), while rendering, so they
  /// only show up on the controller value.
  void _onControllerValue() {
    final controller = _videoController;
    if (controller == null) return;
    final value = controller.value;

    if (value.hasError) {
      controller.removeListener(_onControllerValue);
      final raw = value.errorDescription ?? 'Playback error';
      final loadId = _loadId;
      // A ChangeNotifier cannot be disposed from inside its own notification.
      scheduleMicrotask(() {
        if (mounted && loadId == _loadId) _handleError(raw);
      });
      return;
    }

    // Bring the controls back when the video ends so replay is one tap away.
    if (_isAtEnd(value) && !_controlsVisible && mounted) {
      setState(() => _controlsVisible = true);
    }
  }

  static bool _isAtEnd(VideoPlayerValue value) {
    return value.isInitialized &&
        !value.isPlaying &&
        value.duration > Duration.zero &&
        value.position >= value.duration - const Duration(milliseconds: 300);
  }

  void _handleError(String raw) {
    debugPrint('YoYoVideoPlayer: ${_currentMedia.id} failed: $raw');
    final isDecoder = _isDecoderError(raw);
    if (isDecoder && !_autoRetried) {
      _autoRetried = true;
      final loadId = _loadId;
      Future<void>.delayed(_decoderRetryDelay, () {
        if (mounted && loadId == _loadId) _initPlayer(isRetry: true);
      });
      return;
    }
    _disposePlayer();
    _hideTimer?.cancel();
    setState(() {
      _phase = _PlayerPhase.error;
      _controlsVisible = true;
      _errorMessage = isDecoder
          ? "This video's quality is higher than this device can play."
          : _isNetworkError(raw)
              ? "Couldn't load the video. Check your connection and try again."
              : "This video couldn't be played.";
    });
  }

  static bool _isDecoderError(String raw) {
    final text = raw.toUpperCase();
    return text.contains('NO_MEMORY') ||
        text.contains('DECODERINITIALIZATION') ||
        text.contains('DECODER INIT') ||
        text.contains('EXCEEDS_CAPABILITIES') ||
        text.contains('MEDIACODEC');
  }

  static bool _isNetworkError(String raw) {
    final text = raw.toLowerCase();
    return text.contains('timeout') ||
        text.contains('source error') ||
        text.contains('httpdatasource') ||
        text.contains('unable to connect') ||
        text.contains('403') ||
        text.contains('404');
  }

  Future<void> _disposePlayer() async {
    final controller = _videoController;
    _videoController = null;
    if (controller == null) return;
    controller.removeListener(_onControllerValue);
    await controller.dispose();
  }

  @override
  void dispose() {
    _loadId++;
    _hideTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _restoreOrientationPolicy();
    _disposePlayer().whenComplete(MediaVideoPreloader.resume);
    super.dispose();
  }

  // ── Controls visibility ────────────────────────────────────────────────

  void _showControls() {
    if (!mounted) return;
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  /// Hides only while playing and not mid-drag; paused or ended stays visible.
  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_controlsHideDelay, () {
      final playing = _videoController?.value.isPlaying ?? false;
      if (!mounted || !playing || _dragValue != null) return;
      setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    if (_phase != _PlayerPhase.ready) return;
    if (_controlsVisible) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _showControls();
    }
  }

  // ── Playback actions ───────────────────────────────────────────────────

  Future<void> _togglePlay() async {
    final controller = _videoController;
    if (controller == null) return;
    final value = controller.value;
    if (value.isPlaying) {
      await controller.pause();
    } else {
      if (_isAtEnd(value)) await controller.seekTo(Duration.zero);
      await controller.play();
    }
    _showControls();
  }

  Future<void> _seekBy(Duration delta) async {
    final controller = _videoController;
    if (controller == null) return;
    final value = controller.value;
    var target = value.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (value.duration > Duration.zero && target > value.duration) {
      target = value.duration;
    }
    await controller.seekTo(target);
    _showControls();
  }

  void _onDoubleTap() {
    if (_phase != _PlayerPhase.ready) return;
    final width = MediaQuery.sizeOf(context).width;
    if (_doubleTapDx < width / 3) {
      _seekBy(-_seekStep);
    } else if (_doubleTapDx > width * 2 / 3) {
      _seekBy(_seekStep);
    } else {
      _togglePlay();
    }
  }

  /// Full screen is what the user asked for with the button, not "the screen
  /// is landscape": tablets sit in landscape naturally, and deriving it from
  /// orientation left back stuck trying to exit a mode it never entered.
  Future<void> _toggleFullscreen() async {
    final enter = !_isFullscreen;
    setState(() => _isFullscreen = enter);
    if (enter) {
      await SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
      );
    } else {
      await _restoreOrientationPolicy();
    }
    _showControls();
  }

  /// Tablets rotate freely on sub-screens; phones are portrait-only.
  static Future<void> _restoreOrientationPolicy() {
    if (ResponsiveBreakpoints.isTabletScreen) {
      return AppOrientations.allowTabletRotation();
    }
    return SystemChrome.setPreferredOrientations(AppOrientations.phone);
  }

  /// Back leaves full screen first, the way system video players behave.
  void _onBack() {
    if (_isFullscreen) {
      _toggleFullscreen();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _shareVideo() async {
    await MediaShareUtils.shareMedia(context, _currentMedia);
  }

  Future<void> _playMedia(MediaModel item) async {
    if (item.id == _currentMedia.id) return;
    setState(() => _currentMedia = item);
    await _initPlayer(media: item);
  }

  void _openPlaylist() {
    _hideTimer?.cancel();
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
                  SizedBox(height: 10.th),
                  Container(
                    width: 40.tw,
                    height: 4.th,
                    decoration: BoxDecoration(
                      color: MediaTheme.white.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16.tw),
                    child: Text(
                      'Videos',
                      style: GoogleFonts.poppins(
                        fontSize: 16.tsp,
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
                            width: 56.tw,
                            height: 40.th,
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
                              fontSize: 13.tsp,
                            ),
                          ),
                          subtitle: Text(
                            item.client ?? '',
                            style: GoogleFonts.poppins(
                              color: MediaTheme.textMuted,
                              fontSize: 11.tsp,
                            ),
                          ),
                          trailing: isCurrent
                              ? const Icon(Icons.equalizer_rounded,
                                  color: Colors.white)
                              : null,
                          onTap: () {
                            Navigator.pop(context);
                            _playMedia(item);
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
    ).whenComplete(_showControls);
  }

  void _showMoreMenu() {
    _hideTimer?.cancel();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MediaTheme.sheetBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.tr)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share_outlined, color: Colors.white),
              title: Text('Share',
                  style: GoogleFonts.poppins(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _shareVideo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.screen_rotation_outlined,
                  color: Colors.white),
              title: Text(_isFullscreen ? 'Exit full screen' : 'Full screen',
                  style: GoogleFonts.poppins(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _toggleFullscreen();
              },
            ),
          ],
        ),
      ),
    ).whenComplete(_showControls);
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final controller = _videoController;
    final ready = _phase == _PlayerPhase.ready && controller != null;
    final showOverlay = _controlsVisible || !ready;

    return PopScope(
      canPop: !_isFullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _toggleFullscreen();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (ready)
              _buildVideo(controller)
            else if (_phase == _PlayerPhase.error)
              _buildErrorView()
            else
              _buildLoadingView(),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _toggleControls,
              onDoubleTapDown: (d) => _doubleTapDx = d.localPosition.dx,
              onDoubleTap: _onDoubleTap,
            ),
            IgnorePointer(
              ignoring: !showOverlay,
              child: AnimatedOpacity(
                opacity: showOverlay ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: _buildOverlay(ready ? controller : null),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideo(VideoPlayerController controller) {
    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio == 0
            ? 16 / 9
            : controller.value.aspectRatio,
        child: VideoPlayer(controller),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        MediaVideoThumbnail(media: _currentMedia, showPlayIcon: false),
        Container(
          color: Colors.black45,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        MediaVideoThumbnail(media: _currentMedia, showPlayIcon: false),
        Container(
          color: Colors.black.withValues(alpha: 0.7),
          padding: EdgeInsets.symmetric(horizontal: 32.tw),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  color: Colors.white70, size: 44.tsp),
              SizedBox(height: 12.th),
              Text(
                _errorMessage ?? "This video couldn't be played.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14.tsp,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 16.th),
              OutlinedButton.icon(
                onPressed: () => _initPlayer(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: Text('Retry', style: GoogleFonts.poppins()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Same controls in portrait and landscape; landscape drops the thumbnail
  /// row and uses tighter spacing so the video stays visible.
  Widget _buildOverlay(VideoPlayerController? controller) {
    final landscape = _isLandscape;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (controller != null)
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                  stops: const [0.0, 0.25, 0.55, 1.0],
                ),
              ),
            ),
          ),
        SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: controller == null
                    ? const SizedBox.shrink()
                    : Center(child: _buildTransport(controller)),
              ),
              if (controller != null)
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: MediaLayout.playerControlsMaxWidth,
                    ),
                    child: _buildBottomBar(controller, landscape),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.tw, vertical: 4.th),
      child: Row(
        children: [
          IconButton(
            onPressed: _onBack,
            icon: Icon(
              _isFullscreen
                  ? Icons.arrow_back_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 28.tsp,
            ),
          ),
          Expanded(
            child: Text(
              _currentMedia.displayName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 14.tsp,
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
              size: 26.tsp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransport(VideoPlayerController controller) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final atEnd = _isAtEnd(value);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _seekBy(-_seekStep),
              icon: Icon(Icons.replay_10_rounded,
                  color: Colors.white, size: 32.tsp),
            ),
            SizedBox(width: 28.tw),
            SizedBox(
              width: 68.tw,
              height: 68.tw,
              child: value.isBuffering && value.isPlaying
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: _togglePlay,
                        customBorder: const CircleBorder(),
                        child: Icon(
                          atEnd
                              ? Icons.replay_rounded
                              : value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                          color: Colors.black,
                          size: 36.tsp,
                        ),
                      ),
                    ),
            ),
            SizedBox(width: 28.tw),
            IconButton(
              onPressed: () => _seekBy(_seekStep),
              icon: Icon(Icons.forward_10_rounded,
                  color: Colors.white, size: 32.tsp),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomBar(VideoPlayerController controller, bool landscape) {
    final description =
        (_currentMedia.description ?? _currentMedia.client ?? '').trim();

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final duration = value.duration;
        final totalMs = duration.inMilliseconds;
        final progress = _dragValue ??
            (totalMs > 0 ? value.position.inMilliseconds / totalMs : 0.0);
        final shownPosition = _dragValue != null
            ? Duration(milliseconds: (totalMs * _dragValue!).round())
            : value.position;
        final remaining = duration - shownPosition;

        return Padding(
          padding:
              EdgeInsets.fromLTRB(16.tw, 0, 16.tw, landscape ? 4.th : 12.th),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!landscape) ...[
                Row(
                  children: [
                    SizedBox(
                      width: 52.tw,
                      height: 52.tw,
                      child: MediaVideoThumbnail(
                        media: _currentMedia,
                        showPlayIcon: false,
                        borderRadius: BorderRadius.circular(8.tr),
                      ),
                    ),
                    SizedBox(width: 12.tw),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentMedia.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 16.tsp,
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
                                fontSize: 12.tsp,
                                color: Colors.white70,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10.th),
              ],
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                ),
                child: Slider(
                  value: progress.clamp(0.0, 1.0),
                  onChangeStart: (v) {
                    _hideTimer?.cancel();
                    setState(() => _dragValue = v);
                  },
                  onChanged: (v) => setState(() => _dragValue = v),
                  onChangeEnd: (v) async {
                    await controller.seekTo(
                      Duration(milliseconds: (totalMs * v).round()),
                    );
                    if (!mounted) return;
                    setState(() => _dragValue = null);
                    _showControls();
                  },
                ),
              ),
              Row(
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: 4.tw),
                    child: Text(
                      '${_formatDuration(shownPosition)} / '
                      '${_formatDuration(duration)}',
                      style: GoogleFonts.poppins(
                        fontSize: 11.tsp,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (!landscape)
                    Text(
                      '-${_formatDuration(remaining.isNegative ? Duration.zero : remaining)}',
                      style: GoogleFonts.poppins(
                        fontSize: 11.tsp,
                        color: Colors.white70,
                      ),
                    ),
                  if (landscape) ..._buildActionButtons(compact: true),
                ],
              ),
              if (!landscape) ...[
                SizedBox(height: 6.th),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _buildActionButtons(compact: false),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildActionButtons({required bool compact}) {
    final size = compact ? 22.tsp : 24.tsp;
    return [
      IconButton(
        tooltip: _isFullscreen ? 'Exit full screen' : 'Full screen',
        onPressed: _toggleFullscreen,
        icon: Icon(
          _isFullscreen
              ? Icons.fullscreen_exit_rounded
              : Icons.fullscreen_rounded,
          color: Colors.white,
          size: size,
        ),
      ),
      IconButton(
        tooltip: 'Share',
        onPressed: _shareVideo,
        icon: Icon(Icons.ios_share_rounded, color: Colors.white, size: size),
      ),
      IconButton(
        tooltip: 'Videos',
        onPressed: _openPlaylist,
        icon: Icon(Icons.queue_music_rounded, color: Colors.white, size: size),
      ),
    ];
  }
}
