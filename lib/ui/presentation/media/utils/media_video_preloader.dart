import 'dart:async';

import 'package:video_player/video_player.dart';

import '../data/media_model.dart';
import 'media_hero_selector.dart';

/// Preloads video controllers so hero and full player start faster.
abstract final class MediaVideoPreloader {
  static final Map<String, VideoPlayerController> _cache = {};
  static final Map<String, Future<VideoPlayerController?>> _inFlight = {};

  static VideoPlayerController _createController(MediaModel media) {
    final url = media.streamingUrl;
    if (url.startsWith('assets/')) {
      return VideoPlayerController.asset(url);
    }
    return VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: const {
        'Range': 'bytes=0-',
        'Accept': 'video/*',
      },
    );
  }

  static Future<void> _applyPlaybackSettings(
    VideoPlayerController controller, {
    required bool loop,
    required bool muted,
  }) async {
    await controller.setLooping(loop);
    await controller.setVolume(muted ? 0 : 1);
  }

  static Future<VideoPlayerController?> _initializeController(
    MediaModel media, {
    required bool loop,
    required bool muted,
    required bool autoplay,
  }) async {
    try {
      final controller = _createController(media);
      await controller.initialize();
      await _applyPlaybackSettings(controller, loop: loop, muted: muted);
      if (autoplay) {
        await controller.play();
      }
      _cache[media.id] = controller;
      return controller;
    } catch (_) {
      return null;
    }
  }

  /// Preload a single video. Concurrent calls for the same id share one future.
  static Future<VideoPlayerController?> preload(
    MediaModel media, {
    bool loop = true,
    bool muted = true,
    bool autoplay = false,
  }) async {
    if (!media.isVideo) return null;

    final cached = _cache[media.id];
    if (cached != null) {
      if (cached.value.isInitialized) {
        await _applyPlaybackSettings(cached, loop: loop, muted: muted);
        if (autoplay && !cached.value.isPlaying) {
          await cached.play();
        }
        return cached;
      }
      try {
        await cached.initialize();
        await _applyPlaybackSettings(cached, loop: loop, muted: muted);
        if (autoplay) await cached.play();
        return cached;
      } catch (_) {
        await cached.dispose();
        _cache.remove(media.id);
      }
    }

    final existingFuture = _inFlight[media.id];
    if (existingFuture != null) {
      final controller = await existingFuture;
      if (controller != null) {
        await _applyPlaybackSettings(controller, loop: loop, muted: muted);
        if (autoplay && !controller.value.isPlaying) {
          await controller.play();
        }
      }
      return controller;
    }

    final future = _initializeController(
      media,
      loop: loop,
      muted: muted,
      autoplay: autoplay,
    );
    _inFlight[media.id] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(media.id);
    }
  }

  /// Hero first (autoplay muted), then preload next items in parallel.
  static Future<void> preloadLandingVideos(
    List<MediaModel> videos, {
    int nextCount = 2,
  }) async {
    final hero = MediaHeroSelector.selectHeroVideo(videos);
    if (hero == null) return;

    await preload(hero, loop: true, muted: true, autoplay: true);

    final remaining = MediaHeroSelector.remainingVideos(videos, hero);
    if (remaining.isEmpty || nextCount <= 0) return;

    await Future.wait(
      remaining
          .take(nextCount)
          .map((media) => preload(media, loop: true, muted: true)),
      eagerError: false,
    );
  }

  static Future<void> preloadMany(
    Iterable<MediaModel> mediaList, {
    int limit = 3,
  }) async {
    var count = 0;
    final futures = <Future<VideoPlayerController?>>[];
    for (final media in mediaList) {
      if (!media.isVideo || count >= limit) break;
      if (_cache.containsKey(media.id) &&
          (_cache[media.id]?.value.isInitialized ?? false)) {
        count++;
        continue;
      }
      futures.add(preload(media));
      count++;
    }
    if (futures.isNotEmpty) {
      await Future.wait(futures, eagerError: false);
    }
  }

  static VideoPlayerController? peek(String mediaId) => _cache[mediaId];

  static bool isReady(String mediaId) {
    final controller = _cache[mediaId];
    return controller != null && controller.value.isInitialized;
  }

  /// Removes from cache and returns controller for caller to own/dispose.
  static VideoPlayerController? take(String mediaId) {
    return _cache.remove(mediaId);
  }

  static void release(String mediaId, VideoPlayerController controller) {
    if (!_cache.containsKey(mediaId)) {
      _cache[mediaId] = controller;
    }
  }

  static Future<void> disposeId(String mediaId) async {
    _inFlight.remove(mediaId);
    final controller = _cache.remove(mediaId);
    await controller?.dispose();
  }

  static Future<void> disposeAll() async {
    _inFlight.clear();
    final controllers = _cache.values.toList();
    _cache.clear();
    for (final controller in controllers) {
      await controller.dispose();
    }
  }
}
