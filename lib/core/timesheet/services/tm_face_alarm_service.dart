import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Short alarm for a wrong-person face on the capture camera.
class TmFaceAlarmService {
  TmFaceAlarmService({Duration? cooldown})
      : _cooldown = cooldown ?? const Duration(seconds: 3);

  static const String _asset = 'sounds/face_mismatch_alarm.wav';

  final Duration _cooldown;
  AudioPlayer? _player;
  String? _lastKey;
  DateTime? _lastPlayedAt;

  /// Plays once per [key] within the cooldown; [force] bypasses it (shutter).
  Future<void> playMismatch({Object? key, bool force = false}) async {
    final now = DateTime.now();
    final k = key?.toString() ?? 'mismatch';
    if (!force &&
        _lastKey == k &&
        _lastPlayedAt != null &&
        now.difference(_lastPlayedAt!) < _cooldown) {
      return;
    }
    _lastKey = k;
    _lastPlayedAt = now;
    unawaited(HapticFeedback.heavyImpact());
    try {
      final player =
          _player ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      await player.stop();
      await player.play(AssetSource(_asset), volume: 1.0);
    } catch (error) {
      debugPrint('FaceAlarm: play failed: $error');
    }
  }

  Future<void> dispose() async {
    final player = _player;
    _player = null;
    if (player == null) return;
    try {
      await player.dispose();
    } catch (_) {}
  }
}
