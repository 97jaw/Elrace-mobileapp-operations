import 'dart:async';

import 'package:el_race/ui/presentation/my_notes/bloc/notes_bloc.dart';
import 'package:el_race/ui/presentation/my_notes/data/note_model.dart';
import 'package:el_race/ui/presentation/my_notes/screens/note_detail_screen.dart';
import 'package:el_race/ui/presentation/my_notes/services/notes_audio_recording_service.dart';
import 'package:el_race/ui/presentation/my_notes/theme/notes_theme.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_ai_mode_sheet.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_glass_card.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_royal_bronze_background.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

enum _NotesAudioLanguage { en, ar, auto }

/// Record an audio note, upload to Storage, save Firestore note with recording meta.
class AudioRecordingScreen extends StatefulWidget {
  const AudioRecordingScreen({super.key});

  @override
  State<AudioRecordingScreen> createState() => _AudioRecordingScreenState();
}

class _AudioRecordingScreenState extends State<AudioRecordingScreen> {
  final NotesAudioRecordingService _service = NotesAudioRecordingService();
  final TextEditingController _titleController = TextEditingController();

  _NotesAudioLanguage _language = _NotesAudioLanguage.auto;
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isSaving = false;
  double _amplitude = 0;
  Duration _elapsed = Duration.zero;

  Timer? _tickTimer;
  StreamSubscription<double>? _ampSub;

  @override
  void dispose() {
    _tickTimer?.cancel();
    _ampSub?.cancel();
    _titleController.dispose();
    _service.dispose();
    super.dispose();
  }

  String get _languageCode {
    switch (_language) {
      case _NotesAudioLanguage.en:
        return 'en';
      case _NotesAudioLanguage.ar:
        return 'ar';
      case _NotesAudioLanguage.auto:
        return 'auto';
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _toggleRecord() async {
    if (_isSaving) return;

    if (!_isRecording) {
      final ok = await _service.startRecording();
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Microphone permission is required'),
            backgroundColor: NotesTheme.surface,
          ),
        );
        return;
      }
      setState(() {
        _isRecording = true;
        _isPaused = false;
        _elapsed = Duration.zero;
      });
      _tickTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted) return;
        setState(() => _elapsed = _service.elapsed);
      });
      _ampSub = _service.amplitudeStream.listen((v) {
        if (!mounted) return;
        setState(() => _amplitude = v);
      });
      return;
    }

    if (_isPaused) {
      await _service.resumeRecording();
      setState(() => _isPaused = false);
    } else {
      await _service.pauseRecording();
      setState(() => _isPaused = true);
    }
  }

  Future<void> _cancel() async {
    await _service.cancelRecording();
    _tickTimer?.cancel();
    await _ampSub?.cancel();
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _isPaused = false;
      _elapsed = Duration.zero;
      _amplitude = 0;
    });
  }

  Future<void> _stopAndSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final result = await _service.stopRecording();
      _tickTimer?.cancel();
      await _ampSub?.cancel();

      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _isPaused = false;
      });

      if (result == null || !result.isValid || result.file == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result?.isTooShort == true
                  ? 'Recording too short — try again'
                  : 'Could not save recording',
            ),
            backgroundColor: NotesTheme.surface,
          ),
        );
        setState(() => _isSaving = false);
        return;
      }

      final choice = await showNotesAiModeSheet(context);
      if (choice == null || !mounted) {
        setState(() => _isSaving = false);
        return;
      }

      final noteId = const Uuid().v4();
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final now = DateTime.now();
      final title = _titleController.text.trim().isEmpty
          ? 'Audio note ${_formatDuration(Duration(milliseconds: result.durationMs))}'
          : _titleController.text.trim();

      final needsAi = choice.mode == NoteAiMode.summarize ||
          choice.mode == NoteAiMode.bullets;

      var note = NoteModel(
        id: noteId,
        ownerId: uid,
        title: title,
        content: '',
        noteType: NoteType.audio,
        createdAt: now,
        updatedAt: now,
        aiMode: choice.mode,
        aiStatus: needsAi ? NoteAiStatus.pending : NoteAiStatus.none,
        recording: RecordingInfo(
          audioUrl: '',
          durationSeconds: (result.durationMs / 1000).round(),
          language: _languageCode,
          status: TranscriptionStatus.pending,
        ),
      );

      if (!mounted) return;
      final bloc = context.read<NotesBloc>();
      bloc.add(AddNote(note));

      final created = await bloc.stream
          .firstWhere(
            (s) => s is NotesLoaded || s is NoteActionError || s is NotesError,
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;
      if (created is NoteActionError || created is NotesError) {
        final msg = created is NoteActionError
            ? created.message
            : (created as NotesError).message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: NotesTheme.surface),
        );
        setState(() => _isSaving = false);
        return;
      }

      final audioUrl = await _service.uploadAudio(
        noteId: noteId,
        audioFile: result.file!,
        language: _languageCode,
      );
      final storagePath = 'chat_media/notes/$uid/$noteId/audio.m4a';

      note = note.copyWith(
        updatedAt: DateTime.now(),
        recording: note.recording!.copyWith(
          audioUrl: audioUrl,
          storagePath: storagePath,
          status: TranscriptionStatus.pending,
        ),
      );

      if (!mounted) return;
      bloc.add(UpdateNote(note));

      await bloc.stream
          .firstWhere(
            (s) => s is NotesLoaded || s is NoteActionError || s is NotesError,
          )
          .timeout(const Duration(seconds: 20));

      debugPrint('✅ AudioRecordingScreen: note saved $noteId');
      // Stay in the note — don't dump the user back to My Notes home while
      // transcription / summarize / bullets are still running.
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: bloc,
            child: NoteDetailScreen(note: note),
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ AudioRecordingScreen: save failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save audio note: $e'),
          backgroundColor: NotesTheme.surface,
        ),
      );
      setState(() {
        _isRecording = false;
        _isPaused = false;
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = context.systemBottomInset;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: NotesTheme.systemOverlay,
      child: NotesRoyalBronzeBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding:
                        EdgeInsets.fromLTRB(20.w, 8.h, 20.w, bottomPad + 24.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Language',
                          style: GoogleFonts.poppins(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color:
                                NotesTheme.textPrimary.withValues(alpha: 0.7),
                          ),
                        ),
                        SizedBox(height: 10.h),
                        _buildLanguageChips(),
                        SizedBox(height: 20.h),
                        TextField(
                          controller: _titleController,
                          style: GoogleFonts.poppins(
                            color: NotesTheme.textPrimary,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Optional title',
                            hintStyle: GoogleFonts.poppins(
                              color: NotesTheme.textPrimary
                                  .withValues(alpha: 0.35),
                            ),
                            filled: true,
                            fillColor: NotesTheme.glassFill,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14.r),
                              borderSide:
                                  BorderSide(color: NotesTheme.glassBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14.r),
                              borderSide:
                                  BorderSide(color: NotesTheme.glassBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14.r),
                              borderSide:
                                  const BorderSide(color: NotesTheme.bronze),
                            ),
                          ),
                        ),
                        SizedBox(height: 28.h),
                        NotesGlassCard(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20.w,
                            vertical: 28.h,
                          ),
                          child: Column(
                            children: [
                              Text(
                                _formatDuration(_elapsed),
                                style: GoogleFonts.poppins(
                                  fontSize: 42.sp,
                                  fontWeight: FontWeight.w700,
                                  color: NotesTheme.textPrimary,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                _isSaving
                                    ? 'Uploading…'
                                    : !_isRecording
                                        ? 'Tap to start recording'
                                        : _isPaused
                                            ? 'Paused'
                                            : 'Recording',
                                style: GoogleFonts.poppins(
                                  fontSize: 13.sp,
                                  color: NotesTheme.bronze,
                                ),
                              ),
                              SizedBox(height: 24.h),
                              _buildWaveform(),
                              SizedBox(height: 28.h),
                              _buildControls(),
                            ],
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'After you stop, transcript starts automatically. Optionally request a summary.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 11.sp,
                            color:
                                NotesTheme.textPrimary.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
      child: Row(
        children: [
          IconButton(
            onPressed: _isSaving
                ? null
                : () async {
                    if (_isRecording) await _cancel();
                    if (mounted) Navigator.of(context).pop();
                  },
            icon: Icon(
              Icons.arrow_back_rounded,
              color: NotesTheme.textPrimary,
              size: 24.sp,
            ),
          ),
          Expanded(
            child: Text(
              'Voice Note',
              style: GoogleFonts.poppins(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: NotesTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageChips() {
    Widget chip(String label, _NotesAudioLanguage value) {
      final selected = _language == value;
      return GestureDetector(
        onTap: _isRecording || _isSaving
            ? null
            : () => setState(() => _language = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected
                ? NotesTheme.bronze.withValues(alpha: 0.2)
                : NotesTheme.glassFill,
            border: Border.all(
              color: selected ? NotesTheme.bronze : NotesTheme.glassBorder,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: selected
                  ? NotesTheme.bronze
                  : NotesTheme.textPrimary.withValues(alpha: 0.55),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip('EN', _NotesAudioLanguage.en),
        SizedBox(width: 8.w),
        chip('Arabic (forced)', _NotesAudioLanguage.ar),
        SizedBox(width: 8.w),
        chip('Auto', _NotesAudioLanguage.auto),
      ],
    );
  }

  Widget _buildWaveform() {
    return SizedBox(
      height: 56.h,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(24, (i) {
          final wave = _isRecording && !_isPaused
              ? (0.25 + _amplitude * (0.4 + (i % 5) * 0.12)).clamp(0.15, 1.0)
              : 0.18;
          return Container(
            width: 4.w,
            height: 56.h * wave,
            margin: EdgeInsets.symmetric(horizontal: 2.w),
            decoration: BoxDecoration(
              color: NotesTheme.bronze.withValues(
                alpha: _isRecording && !_isPaused ? 0.85 : 0.35,
              ),
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_isRecording)
          IconButton(
            onPressed: _isSaving ? null : _cancel,
            icon: Icon(Icons.delete_outline,
                color: NotesTheme.textPrimary, size: 28.sp),
          ),
        SizedBox(width: 12.w),
        GestureDetector(
          onTap: _isSaving ? null : _toggleRecord,
          child: Container(
            width: 72.w,
            height: 72.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isRecording && !_isPaused
                  ? NotesTheme.bronze
                  : NotesTheme.bronze.withValues(alpha: 0.85),
              boxShadow: [
                BoxShadow(
                  color: NotesTheme.bronze.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              !_isRecording
                  ? Icons.mic_rounded
                  : _isPaused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded,
              color: NotesTheme.pureBlack,
              size: 34.sp,
            ),
          ),
        ),
        SizedBox(width: 12.w),
        if (_isRecording)
          IconButton(
            onPressed: _isSaving ? null : _stopAndSave,
            icon: _isSaving
                ? SizedBox(
                    width: 24.w,
                    height: 24.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: NotesTheme.bronze,
                    ),
                  )
                : Icon(Icons.check_circle,
                    color: NotesTheme.bronze, size: 32.sp),
          )
        else
          SizedBox(width: 48.w),
      ],
    );
  }
}
