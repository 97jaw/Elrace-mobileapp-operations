import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

/// What the splash should play this launch.
class SplashVideoSource {
  const SplashVideoSource.bundled()
      : file = null,
        url = null;
  const SplashVideoSource.file(File this.file) : url = null;
  const SplashVideoSource.network(String this.url) : file = null;

  final File? file;
  final String? url;

  bool get isBundled => file == null && url == null;
  bool get isHls => url != null && SplashVideoCache.isHlsUrl(url!);
}

/// Remote splash video (`splash_video_url` from `/api/app/config`).
///
/// The link may be HLS (`.m3u8`, streamed every launch) or MP4 (streamed
/// until a background download finishes, then played from the phone).
/// The bundled asset is used whenever there is no link or it cannot start.
class SplashVideoCache {
  SplashVideoCache._();
  static final SplashVideoCache instance = SplashVideoCache._();

  static const _prefUrl = 'splash_video_remote_url';
  static const _prefPath = 'splash_video_local_path';
  static const _prefKnownUrl = 'splash_video_known_url';
  static const int _maxBytes = 20 * 1024 * 1024;

  /// Keeps the download out of the splash / first screen.
  static const Duration _startDelay = Duration(seconds: 10);

  final Completer<String> _configUrl = Completer<String>();
  bool _syncing = false;

  static bool isHlsUrl(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    return path.endsWith('.m3u8');
  }

  static String _clean(String? url) {
    final value = (url ?? '').trim();
    return value.toLowerCase().startsWith('https://') ? value : '';
  }

  /// Called with `splash_video_url` every time the config answers.
  void onConfig(String? remoteUrl) {
    final url = _clean(remoteUrl);
    unawaited(SharedPref().setPreferencesString(_prefKnownUrl, url));
    if (!_configUrl.isCompleted) _configUrl.complete(url);
    unawaited(sync(url));
  }

  /// Config request failed: keep the saved link, stop the first-launch wait.
  void onConfigUnavailable() {
    if (!_configUrl.isCompleted) _configUrl.complete('');
  }

  /// Uses the link from the last config; on the very first launch waits up
  /// to [firstLaunchWait] for the config to answer.
  Future<SplashVideoSource> resolve({
    Duration firstLaunchWait = const Duration(milliseconds: 2500),
  }) async {
    try {
      String url;
      if (SharedPref().containPreference(_prefKnownUrl)) {
        url = SharedPref().getPreferenceString(_prefKnownUrl);
      } else {
        url = await _configUrl.future
            .timeout(firstLaunchWait, onTimeout: () => '');
      }
      url = _clean(url);
      if (url.isEmpty) return const SplashVideoSource.bundled();
      if (!isHlsUrl(url) && url == SharedPref().getPreferenceString(_prefUrl)) {
        final file = cachedFile();
        if (file != null) return SplashVideoSource.file(file);
      }
      return SplashVideoSource.network(url);
    } catch (_) {
      return const SplashVideoSource.bundled();
    }
  }

  /// Downloaded splash video, or null.
  File? cachedFile() {
    try {
      final path = SharedPref().getPreferenceString(_prefPath);
      if (path.isEmpty) return null;
      final file = File(path);
      if (!file.existsSync() || file.lengthSync() == 0) return null;
      return file;
    } catch (_) {
      return null;
    }
  }

  /// Drops the downloaded video (e.g. it failed to play).
  Future<void> discard() async {
    final file = cachedFile();
    await SharedPref().removePreference(_prefPath);
    await SharedPref().removePreference(_prefUrl);
    try {
      await file?.delete();
    } catch (_) {}
  }

  /// Saves an MP4 link to the phone in the background. HLS links and an
  /// empty link remove any saved file.
  Future<void> sync(String? remoteUrl) async {
    if (remoteUrl == null || _syncing) return;
    final url = _clean(remoteUrl);
    if (url.isEmpty || isHlsUrl(url)) {
      if (SharedPref().getPreferenceString(_prefUrl).isNotEmpty ||
          cachedFile() != null) {
        await discard();
      }
      return;
    }
    if (url == SharedPref().getPreferenceString(_prefUrl) &&
        cachedFile() != null) {
      return;
    }

    _syncing = true;
    File? temp;
    try {
      await Future<void>.delayed(_startDelay);
      final dir =
          Directory('${(await getApplicationSupportDirectory()).path}/splash');
      await dir.create(recursive: true);
      // AVPlayer picks the container from the extension; `.tmp` fails to open.
      temp = File('${dir.path}/download_tmp.mp4');
      if (await temp.exists()) await temp.delete();

      final cancel = CancelToken();
      await Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 60),
      )).download(
        url,
        temp.path,
        cancelToken: cancel,
        onReceiveProgress: (received, total) {
          if (received > _maxBytes || total > _maxBytes) {
            cancel.cancel('splash video larger than limit');
          }
        },
      );

      if (!await _isMp4(temp)) {
        debugPrint('SplashVideoCache: downloaded file is not an MP4');
        return;
      }
      if (!await _plays(temp)) {
        debugPrint('SplashVideoCache: downloaded file does not play');
        return;
      }

      final name = sha1.convert(url.codeUnits).toString().substring(0, 16);
      final target = File('${dir.path}/splash_$name.mp4');
      if (await target.exists()) await target.delete();
      await temp.rename(target.path);
      temp = null;

      final previous = cachedFile();
      await SharedPref().setPreferencesString(_prefPath, target.path);
      await SharedPref().setPreferencesString(_prefUrl, url);
      if (previous != null && previous.path != target.path) {
        try {
          await previous.delete();
        } catch (_) {}
      }
      debugPrint('SplashVideoCache: new splash video saved for next launch');
    } catch (e) {
      debugPrint('SplashVideoCache: download skipped: $e');
    } finally {
      _syncing = false;
      try {
        if (temp != null && await temp.exists()) await temp.delete();
      } catch (_) {}
    }
  }

  static Future<bool> _isMp4(File file) async {
    try {
      final length = await file.length();
      if (length < 12 || length > _maxBytes) return false;
      final raf = await file.open();
      try {
        final head = await raf.read(12);
        return String.fromCharCodes(head.sublist(4, 8)) == 'ftyp';
      } finally {
        await raf.close();
      }
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _plays(File file) async {
    final controller = VideoPlayerController.file(file);
    try {
      await controller.initialize().timeout(const Duration(seconds: 10));
      return controller.value.isInitialized &&
          controller.value.duration > Duration.zero;
    } catch (e) {
      debugPrint('SplashVideoCache: play check failed: $e');
      return false;
    } finally {
      await controller.dispose();
    }
  }
}
