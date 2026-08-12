import 'dart:async';
import 'dart:io';

import 'package:el_race/chat/services/firebase_chat_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

/// Records note audio locally, then uploads to Firebase Storage.
class NotesAudioRecordingService {
  NotesAudioRecordingService({
    AudioRecorder? recorder,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  })  : _recorder = recorder ?? AudioRecorder(),
        _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final AudioRecorder _recorder;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;
  final Uuid _uuid = const Uuid();

  static const int maxDurationSeconds = 30 * 60; // 30 minutes
  static const int minDurationMs = 800;

  bool _isRecording = false;
  bool _isPaused = false;
  DateTime? _recordingStartTime;
  Duration _elapsedBeforePause = Duration.zero;
  String? _currentRecordingPath;
  Timer? _maxDurationTimer;

  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;

  Duration get elapsed {
    if (_recordingStartTime == null) return _elapsedBeforePause;
    if (_isPaused) return _elapsedBeforePause;
    return _elapsedBeforePause + DateTime.now().difference(_recordingStartTime!);
  }

  int get elapsedSeconds => elapsed.inSeconds;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<bool> startRecording() async {
    if (_isRecording) return false;

    if (!await _recorder.hasPermission()) {
      debugPrint('❌ NotesAudio: microphone permission denied');
      return false;
    }

    try {
      await FirebaseChatAuthService.instance.ensureAuthenticated();

      final directory = await getTemporaryDirectory();
      final fileName = 'note_audio_${_uuid.v4()}.m4a';
      _currentRecordingPath = '${directory.path}/$fileName';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      _isPaused = false;
      _elapsedBeforePause = Duration.zero;
      _recordingStartTime = DateTime.now();

      _maxDurationTimer?.cancel();
      _maxDurationTimer = Timer(
        const Duration(seconds: maxDurationSeconds),
        () async {
          debugPrint('⚠️ NotesAudio: max duration reached');
          await stopRecording();
        },
      );

      debugPrint('🎙️ NotesAudio: started $_currentRecordingPath');
      return true;
    } catch (e) {
      debugPrint('❌ NotesAudio: start failed: $e');
      _isRecording = false;
      _currentRecordingPath = null;
      _recordingStartTime = null;
      return false;
    }
  }

  Future<void> pauseRecording() async {
    if (!_isRecording || _isPaused) return;
    try {
      await _recorder.pause();
      _elapsedBeforePause = elapsed;
      _isPaused = true;
      _recordingStartTime = null;
    } catch (e) {
      debugPrint('❌ NotesAudio: pause failed: $e');
    }
  }

  Future<void> resumeRecording() async {
    if (!_isRecording || !_isPaused) return;
    try {
      await _recorder.resume();
      _isPaused = false;
      _recordingStartTime = DateTime.now();
    } catch (e) {
      debugPrint('❌ NotesAudio: resume failed: $e');
    }
  }

  Future<NotesAudioRecordingResult?> stopRecording() async {
    if (!_isRecording) return null;

    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;

    try {
      final durationMs = elapsed.inMilliseconds;
      final path = await _recorder.stop();

      _isRecording = false;
      _isPaused = false;
      _recordingStartTime = null;
      _elapsedBeforePause = Duration.zero;

      if (path == null || path.isEmpty) return null;

      final file = File(path);
      if (!await file.exists()) return null;

      if (durationMs < minDurationMs) {
        await file.delete();
        return NotesAudioRecordingResult(
          file: null,
          durationMs: durationMs,
          isTooShort: true,
        );
      }

      debugPrint('🎙️ NotesAudio: stopped ${durationMs}ms');
      return NotesAudioRecordingResult(
        file: file,
        durationMs: durationMs,
        isTooShort: false,
      );
    } catch (e) {
      debugPrint('❌ NotesAudio: stop failed: $e');
      _isRecording = false;
      _isPaused = false;
      return null;
    }
  }

  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;

    try {
      final path = await _recorder.stop();
      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    } catch (e) {
      debugPrint('❌ NotesAudio: cancel failed: $e');
    } finally {
      _isRecording = false;
      _isPaused = false;
      _recordingStartTime = null;
      _elapsedBeforePause = Duration.zero;
      _currentRecordingPath = null;
    }
  }

  Stream<double> get amplitudeStream {
    return Stream.periodic(const Duration(milliseconds: 100)).asyncMap((_) async {
      if (!_isRecording || _isPaused) return 0.0;
      try {
        final amplitude = await _recorder.getAmplitude();
        final normalized = (amplitude.current + 160) / 160;
        return normalized.clamp(0.0, 1.0);
      } catch (_) {
        return 0.0;
      }
    });
  }

  /// Uploads audio to `chat_media/notes/{uid}/{noteId}/audio.m4a`
  /// (uses existing Storage rules that already allow chat_media/**).
  Future<String> uploadAudio({
    required String noteId,
    required File audioFile,
    required String language,
  }) async {
    await FirebaseChatAuthService.instance.ensureAuthenticated();
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception('Firebase auth required to upload audio');
    }

    final storagePath = 'chat_media/notes/$uid/$noteId/audio.m4a';
    final ref = _storage.ref(storagePath);

    debugPrint('☁️ NotesAudio: uploading $storagePath');

    final metadata = SettableMetadata(
      contentType: 'audio/mp4',
      customMetadata: {
        'ownerUid': uid,
        'noteId': noteId,
        'language': language,
        'purpose': 'notes_transcription',
      },
    );

    try {
      await ref.putFile(audioFile, metadata);
    } on FirebaseException catch (e) {
      if (e.code == 'unauthorized' ||
          e.code == 'permission-denied' ||
          e.code == 'unauthenticated') {
        await FirebaseChatAuthService.instance.ensureAuthenticated();
        await ref.putFile(audioFile, metadata);
      } else {
        rethrow;
      }
    }

    final url = await ref.getDownloadURL();
    debugPrint('✅ NotesAudio: uploaded $url');
    return url;
  }

  Future<void> dispose() async {
    await cancelRecording();
    await _recorder.dispose();
  }
}

class NotesAudioRecordingResult {
  final File? file;
  final int durationMs;
  final bool isTooShort;
  /// Whisper language hint: `en` | `ar` | `auto`.
  final String language;

  const NotesAudioRecordingResult({
    required this.file,
    required this.durationMs,
    required this.isTooShort,
    this.language = 'auto',
  });

  bool get isValid => file != null && !isTooShort;

  String get durationText {
    final seconds = (durationMs / 1000).floor();
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
  }

  NotesAudioRecordingResult copyWith({
    File? file,
    int? durationMs,
    bool? isTooShort,
    String? language,
  }) {
    return NotesAudioRecordingResult(
      file: file ?? this.file,
      durationMs: durationMs ?? this.durationMs,
      isTooShort: isTooShort ?? this.isTooShort,
      language: language ?? this.language,
    );
  }
}
