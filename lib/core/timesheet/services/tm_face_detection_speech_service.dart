import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Spoken feedback when foreman capture recognizes an employee on camera.
class TmFaceDetectionSpeechService {
  TmFaceDetectionSpeechService({Duration? cooldown})
      : _cooldown = cooldown ?? const Duration(seconds: 4);

  final Duration _cooldown;
  final FlutterTts _tts = FlutterTts();

  bool _ready = false;
  String? _lastSpokenKey;
  DateTime? _lastSpokenAt;

  Future<void> ensureReady() async {
    if (_ready) return;
    try {
      await _tts.setVolume(1.0);
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      final locale = ui.PlatformDispatcher.instance.locale;
      final lang = locale.languageCode;
      final country = locale.countryCode;
      final candidates = <String>[
        if (country != null && country.isNotEmpty) '$lang-$country',
        if (lang.isNotEmpty) lang,
        'en-US',
      ];
      for (final code in candidates) {
        final ok = await _tts.setLanguage(code);
        if (ok == 1) break;
      }
      _ready = true;
    } catch (error, stack) {
      debugPrint('FaceDetectionSpeech init failed: $error\n$stack');
    }
  }

  Future<void> speakEmployeeDetected(
    String name, {
    Object? employeeId,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    // Announce only the first name for a shorter, friendlier prompt.
    final firstName = trimmed.split(RegExp(r'\s+')).first;
    final idKey = employeeId?.toString() ?? trimmed;
    await _speakOnce(
      key: 'detected:$idKey',
      text: '$firstName detected',
    );
  }

  Future<void> speakAlreadyAttended({Object? employeeId}) async {
    await _speakOnce(
      key: 'attended:${employeeId?.toString() ?? 'generic'}',
      text: 'Already attended',
    );
  }

  Future<void> _speakOnce({
    required String key,
    required String text,
  }) async {
    final now = DateTime.now();
    if (_lastSpokenKey == key &&
        _lastSpokenAt != null &&
        now.difference(_lastSpokenAt!) < _cooldown) {
      return;
    }

    await ensureReady();
    if (!_ready) return;

    try {
      await _tts.stop();
      await _tts.speak(text);
      _lastSpokenKey = key;
      _lastSpokenAt = now;
    } catch (error, stack) {
      debugPrint('FaceDetectionSpeech speak failed: $error\n$stack');
    }
  }

  Future<void> stop() async {
    if (!_ready) return;
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
    _ready = false;
  }
}
