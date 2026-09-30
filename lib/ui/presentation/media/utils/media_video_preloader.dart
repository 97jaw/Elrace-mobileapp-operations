import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import '../data/media_model.dart';
import 'media_hero_selector.dart';

/// Preloads video controllers so hero and full player start faster.
///
/// Every initialized controller holds a hardware decoder, and phones only have
/// a few for 1080p (the next init fails with MediaCodec NO_MEMORY). So the
/// cache is capped, and controllers on screen are pinned against eviction.
abstract final class MediaVideoPreloader {
  static const int _maxCached = 2;

  static final Map<String, VideoPlayerController> _cache = {};
  static final Map<String, Future<VideoPlayerController?>> _inFlight = {};
  static final Map<String, int> _pins = {};
  static final Set<String> _autoplayIds = {};

  /// Marks [mediaId] as on screen so it is not evicted. Calls are counted.
  static void pin(String mediaId) {
    _pins[mediaId] = (_pins[mediaId] ?? 0) + 1;
  }

  static void unpin(String mediaId) {
    final count = (_pins[mediaId] ?? 0) - 1;
    if (count > 0) {
      _pins[mediaId] = count;
    } else {
      _pins.remove(mediaId);
    }
    unawaited(_evict());
  }

  /// Disposes the oldest unpinned controllers until at most
  /// `_maxCached - reserve` remain.
  static Future<void> _evict({int reserve = 0}) async {
    final limit = _maxCached - reserve;
    final victims = <VideoPlayerController>[];
    for (final id in _cache.keys.toList()) {
      if (_cache.length <= limit) break;
      if (_pins.containsKey(id)) continue;
      final controller = _cache.remove(id);
      _autoplayIds.remove(id);
      if (controller != null) victims.add(controller);
    }
    for (final controller in victims) {
      await controller.dispose();
    }
  }

  /// True while the full player owns the decoder. Hero widgets listen to this
  /// to drop their controller and re-create it once playback ends.
  static final ValueNotifier<bool> suspended = ValueNotifier(false);

  /// Frees every cached decoder so the full player gets the hardware to
  /// itself. A paused controller still holds its decoder, and High-profile
  /// Level 5.1 streams fail with NO_MEMORY if another one is alive.
  static Future<void> suspend() async {
    if (suspended.value) return;
    suspended.value = true;
    // Listeners drop their VideoPlayer widgets this frame; dispose after.
    await WidgetsBinding.instance.endOfFrame;
    await disposeAll();
  }

  static void resume() {
    suspended.value = false;
  }

  static VideoPlayerController _createController(MediaModel media) {
    final url = media.streamingUrl;
    if (url.startsWith('assets/')) {
      return VideoPlayerController.asset(url);
    }
    return VideoPlayerController.networkUrl(Uri.parse(url));
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
    await _evict(reserve: 1);
    final controller = _createController(media);
    try {
      await controller.initialize();
      if (suspended.value) {
        await controller.dispose();
        return null;
      }
      await _applyPlaybackSettings(controller, loop: loop, muted: muted);
      if (autoplay) {
        await controller.play();
        _autoplayIds.add(media.id);
      }
      _cache[media.id] = controller;
      return controller;
    } catch (e) {
      debugPrint('MediaVideoPreloader: init failed for ${media.id}: $e');
      await controller.dispose();
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
    if (!media.isVideo || suspended.value) return null;

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
    int nextCount = 0,
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
    unawaited(_evict());
  }

  static Future<void> disposeId(String mediaId) async {
    _inFlight.remove(mediaId);
    _autoplayIds.remove(mediaId);
    final controller = _cache.remove(mediaId);
    await controller?.dispose();
  }

  static Future<void> disposeAll() async {
    _inFlight.clear();
    _pins.clear();
    _autoplayIds.clear();
    final controllers = _cache.values.toList();
    _cache.clear();
    for (final controller in controllers) {
      await controller.dispose();
    }
  }
}
