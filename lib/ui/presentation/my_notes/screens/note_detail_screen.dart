import 'dart:async';
import 'dart:ui' as ui show TextDirection;

import 'package:el_race/ui/presentation/my_notes/bloc/notes_bloc.dart';
import 'package:el_race/ui/presentation/my_notes/data/note_model.dart';
import 'package:el_race/ui/presentation/my_notes/repository/firebase_notes_repository.dart';
import 'package:el_race/ui/presentation/my_notes/screens/add_note_screen.dart';
import 'package:el_race/ui/presentation/my_notes/services/notes_ai_service.dart';
import 'package:el_race/ui/presentation/my_notes/theme/notes_theme.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_ai_actions_section.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_audio_player_widget.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_checklist_content.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_glass_card.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_royal_bronze_background.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_share_sheet.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class NoteDetailScreen extends StatelessWidget {
  final NoteModel note;
  final bool readOnly;

  const NoteDetailScreen({
    super.key,
    required this.note,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return _NoteDetailView(note: note, readOnly: readOnly);
  }
}

class _NoteDetailView extends StatefulWidget {
  final NoteModel note;
  final bool readOnly;

  const _NoteDetailView({required this.note, required this.readOnly});

  @override
  State<_NoteDetailView> createState() => _NoteDetailViewState();
}

class _NoteDetailViewState extends State<_NoteDetailView> {
  late NoteModel _note;
  final NotesAiService _aiService = NotesAiService();
  final FirebaseNotesRepository _repo = FirebaseNotesRepository();
  bool _aiCallInFlight = false;
  StreamSubscription<NoteModel?>? _noteSub;

  @override
  void initState() {
    super.initState();
    _note = widget.note;
    _subscribeToNote();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeTriggerAi());
  }

  void _subscribeToNote() {
    if (widget.readOnly) {
      // Shared notes: still listen on owner path via getShared if needed later.
      // Owner path watch works for owner; for shared, message may be elsewhere.
    }
    _noteSub?.cancel();
    _noteSub = _repo.watchNoteById(_note.id).listen((live) {
      if (!mounted || live == null) return;
      final prev = _note;
      setState(() => _note = live);
      // When transcript lands, kick AI if still pending.
      final transcriptJustReady =
          (prev.recording?.transcript?.trim().isEmpty ?? true) &&
              (live.recording?.transcript?.trim().isNotEmpty ?? false);
      if (transcriptJustReady || live.needsAiProcessing) {
        _maybeTriggerAi();
      }
    }, onError: (e) {
      debugPrint('NoteDetail live watch error: $e');
    });
  }

  @override
  void dispose() {
    _noteSub?.cancel();
    super.dispose();
  }

  Future<void> _maybeTriggerAi() async {
    if (widget.readOnly || _aiCallInFlight) return;
    final transcriptDone =
        _note.recording?.status == TranscriptionStatus.done &&
            (_note.recording?.transcript?.trim().isNotEmpty ?? false);
    final textReady = _note.content.trim().isNotEmpty;
    final needs = _note.needsAiProcessing &&
        (_note.aiMode == NoteAiMode.summarize ||
            _note.aiMode == NoteAiMode.bullets);
    if (!needs) return;
    if (_note.recording != null && !transcriptDone) return;
    if (_note.recording == null && !textReady) return;

    _aiCallInFlight = true;
    try {
      await _aiService.processNoteAi(
        noteId: _note.id,
        mode: _note.aiMode.name,
      );
    } catch (e) {
      debugPrint('Notes AI trigger failed: $e');
    } finally {
      _aiCallInFlight = false;
    }
  }

  void _editNote() {
    final notesBloc = context.read<NotesBloc>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: notesBloc,
          child: AddNoteScreen(existingNote: _note),
        ),
      ),
    );
  }

  void _onChecklistChanged(String nextContent) {
    final updated = _note.copyWith(
      content: nextContent,
      updatedAt: DateTime.now(),
    );
    setState(() => _note = updated);
    if (!widget.readOnly) {
      context.read<NotesBloc>().add(UpdateNote(updated));
    }
  }

  void _deleteNote() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NotesTheme.surface,
        title: Text(
          'Delete note?',
          style: GoogleFonts.poppins(
            color: NotesTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'This action cannot be undone.',
          style: GoogleFonts.poppins(
            color: NotesTheme.textPrimary.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: NotesTheme.textPrimary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<NotesBloc>().add(DeleteNote(_note.id));
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.red.withValues(alpha: 0.2),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareNote() async {
    final updated = await showNotesShareSheet(context, note: _note);
    if (updated != null && mounted) {
      setState(() => _note = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = context.systemBottomInset;
    final formattedDate =
        DateFormat('EEEE, MMM dd, yyyy • hh:mm a').format(_note.updatedAt);

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
                  child: BlocListener<NotesBloc, NotesState>(
                    listener: (context, state) {
                      if (state is NotesLoaded) {
                        for (final n in state.notes) {
                          if (n.id == _note.id) {
                            setState(() => _note = n);
                            _maybeTriggerAi();
                            break;
                          }
                        }
                      }
                    },
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding:
                          EdgeInsets.fromLTRB(20.w, 0, 20.w, bottomPad + 20.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 8.h),
                          _buildMetadata(formattedDate),
                          SizedBox(height: 20.h),
                          _buildTitle(),
                          if (_note.images.isNotEmpty) ...[
                            SizedBox(height: 16.h),
                            _buildImages(),
                          ],
                          if (_note.content.trim().isNotEmpty) ...[
                            SizedBox(height: 16.h),
                            _buildContent(),
                          ],
                          if (_note.recording != null) ...[
                            SizedBox(height: 16.h),
                            _buildAudioSection(),
                            SizedBox(height: 16.h),
                            _buildTranscriptSection(),
                          ],
                          if (_shouldShowAiSection) ...[
                            SizedBox(height: 16.h),
                            _buildAiResultSection(),
                          ],
                          if (_note.translatedText != null &&
                              _note.translatedText!.isNotEmpty) ...[
                            SizedBox(height: 16.h),
                            _buildTranslatedSection(),
                          ],
                          if (_note.actionItems.isNotEmpty) ...[
                            SizedBox(height: 16.h),
                            _buildActionItems(),
                          ],
                          if (!widget.readOnly) ...[
                            SizedBox(height: 20.h),
                            NotesAiActionsSection(
                              note: _note,
                              onUpdated: (n) => setState(() => _note = n),
                            ),
                          ],
                        ],
                      ),
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

  bool get _shouldShowAiSection {
    return (_note.aiSummary?.trim().isNotEmpty ?? false) ||
        (_note.aiBulletPoints?.trim().isNotEmpty ?? false) ||
        _note.aiStatus == NoteAiStatus.processing ||
        _note.aiStatus == NoteAiStatus.pending ||
        _note.aiStatus == NoteAiStatus.error;
  }

  Widget _buildAiResultSection() {
    final summary = _note.aiSummary?.trim() ?? '';
    final bullets = _note.aiBulletPoints?.trim() ?? '';
    final busy = _note.aiStatus == NoteAiStatus.pending ||
        _note.aiStatus == NoteAiStatus.processing;
    final error = _note.aiStatus == NoteAiStatus.error;
    final waitingSummary =
        busy && _note.aiMode == NoteAiMode.summarize && summary.isEmpty;
    final waitingBullets =
        busy && _note.aiMode == NoteAiMode.bullets && bullets.isEmpty;

    final blocks = <Widget>[];

    if (summary.isNotEmpty) {
      blocks.add(_aiTextBlock(title: 'Summary', body: summary));
    } else if (waitingSummary) {
      blocks.add(_aiPendingBlock(title: 'Summary', isError: false));
    }

    if (bullets.isNotEmpty || waitingBullets) {
      if (blocks.isNotEmpty) blocks.add(SizedBox(height: 16.h));
      if (bullets.isNotEmpty) {
        blocks.add(_aiTextBlock(title: 'Bullet points', body: bullets));
      } else {
        blocks.add(_aiPendingBlock(title: 'Bullet points', isError: false));
      }
    }

    if (error && summary.isEmpty && bullets.isEmpty && !busy) {
      blocks.add(
        _aiPendingBlock(title: 'AI results', isError: true),
      );
    }

    if (blocks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }

  Widget _aiTextBlock({required String title, required String body}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: NotesTheme.textPrimary.withValues(alpha: 0.7),
          ),
        ),
        SizedBox(height: 8.h),
        NotesGlassCard(
          padding: EdgeInsets.all(16.w),
          child: Text(
            body,
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              color: NotesTheme.textPrimary.withValues(alpha: 0.9),
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _aiPendingBlock({required String title, required bool isError}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: NotesTheme.textPrimary.withValues(alpha: 0.7),
          ),
        ),
        SizedBox(height: 8.h),
        NotesGlassCard(
          padding: EdgeInsets.all(16.w),
          child: Row(
            children: [
              if (!isError)
                SizedBox(
                  width: 16.w,
                  height: 16.w,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: NotesTheme.bronze,
                  ),
                ),
              if (!isError) SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  isError
                      ? 'AI processing failed. Use AI actions to retry.'
                      : 'Generating…',
                  style: GoogleFonts.poppins(
                    fontSize: 13.sp,
                    color: NotesTheme.textPrimary.withValues(alpha: 0.5),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.arrow_back_rounded,
              color: NotesTheme.textPrimary,
              size: 24.sp,
            ),
          ),
          if (widget.readOnly)
            Padding(
              padding: EdgeInsets.only(left: 4.w),
              child: Text(
                'Shared · View only',
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  color: NotesTheme.bronze,
                ),
              ),
            ),
          const Spacer(),
          if (!widget.readOnly) ...[
            IconButton(
              onPressed: _editNote,
              icon: Icon(
                Icons.edit_outlined,
                color: NotesTheme.textPrimary,
                size: 22.sp,
              ),
            ),
            IconButton(
              onPressed: _shareNote,
              icon: Icon(
                Icons.share_outlined,
                color: NotesTheme.textPrimary,
                size: 22.sp,
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: NotesTheme.textPrimary,
                size: 22.sp,
              ),
              color: NotesTheme.charcoal,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline,
                          color: Colors.red, size: 20),
                      SizedBox(width: 8.w),
                      Text(
                        'Delete',
                        style: GoogleFonts.poppins(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'delete') {
                  _deleteNote();
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetadata(String formattedDate) {
    return Row(
      children: [
        Icon(
          _getNoteTypeIcon(),
          size: 16.sp,
          color: NotesTheme.bronze,
        ),
        SizedBox(width: 6.w),
        Text(
          _getNoteTypeLabel(),
          style: GoogleFonts.poppins(
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            color: NotesTheme.bronze,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            formattedDate,
            style: GoogleFonts.poppins(
              fontSize: 11.sp,
              color: NotesTheme.textPrimary.withValues(alpha: 0.5),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getNoteTypeIcon() {
    switch (_note.noteType) {
      case NoteType.audio:
        return Icons.mic_none_rounded;
      case NoteType.image:
        return Icons.image_outlined;
      case NoteType.text:
        return Icons.sticky_note_2_outlined;
    }
  }

  String _getNoteTypeLabel() {
    switch (_note.noteType) {
      case NoteType.audio:
        return 'Audio Note';
      case NoteType.image:
        return 'Scan Note';
      case NoteType.text:
        return 'Text Note';
    }
  }

  Widget _buildTitle() {
    return Text(
      _note.title,
      style: GoogleFonts.poppins(
        fontSize: 26.sp,
        fontWeight: FontWeight.w700,
        color: NotesTheme.textPrimary,
        height: 1.2,
      ),
    );
  }

  Widget _buildContent() {
    if (_note.content.isEmpty) {
      return NotesGlassCard(
        padding: EdgeInsets.all(20.w),
        child: Center(
          child: Text(
            'No content',
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              color: NotesTheme.textPrimary.withValues(alpha: 0.4),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return NotesGlassCard(
      padding: EdgeInsets.all(20.w),
      child: NotesChecklistContent(
        content: _note.content,
        readOnly: widget.readOnly,
        onContentChanged: _onChecklistChanged,
      ),
    );
  }

  Widget _buildImages() {
    return SizedBox(
      height: 140.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _note.images.length,
        separatorBuilder: (_, __) => SizedBox(width: 10.w),
        itemBuilder: (context, i) {
          final img = _note.images[i];
          return ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: Image.network(
              img.imageUrl,
              width: 140.w,
              height: 140.h,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 140.w,
                height: 140.h,
                color: NotesTheme.glassFill,
                child: Icon(Icons.broken_image_outlined,
                    color: NotesTheme.textPrimary.withValues(alpha: 0.4)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAudioSection() {
    final recording = _note.recording!;
    if (recording.audioUrl.isEmpty) {
      return NotesGlassCard(
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            SizedBox(
              width: 18.w,
              height: 18.w,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: NotesTheme.bronze,
              ),
            ),
            SizedBox(width: 10.w),
            Text(
              'Uploading audio…',
              style: GoogleFonts.poppins(
                fontSize: 13.sp,
                color: NotesTheme.textPrimary.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return NotesGlassCard(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mic_none_rounded,
                  color: NotesTheme.bronze, size: 18.sp),
              SizedBox(width: 8.w),
              Text(
                'Audio',
                style: GoogleFonts.poppins(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: NotesTheme.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          NotesAudioPlayerWidget(
            audioUrl: recording.audioUrl,
            durationSeconds: recording.durationSeconds,
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptSection() {
    final recording = _note.recording!;
    final transcript = recording.transcript?.trim() ?? '';
    final isPending = transcript.isEmpty &&
        (recording.status == TranscriptionStatus.pending ||
            recording.status == TranscriptionStatus.processing);
    final isError = recording.status == TranscriptionStatus.error;
    final isIdle = recording.status == TranscriptionStatus.idle ||
        (transcript.isEmpty &&
            recording.status != TranscriptionStatus.pending &&
            recording.status != TranscriptionStatus.processing &&
            recording.status != TranscriptionStatus.error);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transcript',
          style: GoogleFonts.poppins(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: NotesTheme.textPrimary.withValues(alpha: 0.7),
          ),
        ),
        SizedBox(height: 8.h),
        NotesGlassCard(
          padding: EdgeInsets.all(16.w),
          child: transcript.isNotEmpty
              ? Text(
                  transcript,
                  textDirection: noteTranscriptLooksArabic(
                    language: recording.language,
                    transcript: transcript,
                  )
                      ? ui.TextDirection.rtl
                      : ui.TextDirection.ltr,
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    color: NotesTheme.textPrimary.withValues(alpha: 0.9),
                    height: 1.6,
                  ),
                )
              : Row(
                  children: [
                    if (isPending)
                      SizedBox(
                        width: 16.w,
                        height: 16.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: NotesTheme.bronze,
                        ),
                      ),
                    if (isPending) SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        isError
                            ? 'Transcription failed. Re-upload audio to try again.'
                            : isPending
                                ? 'Transcribing audio…'
                                : isIdle
                                    ? 'Transcript unavailable'
                                    : 'No transcript yet.',
                        style: GoogleFonts.poppins(
                          fontSize: 13.sp,
                          color: NotesTheme.textPrimary.withValues(alpha: 0.5),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildTranslatedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Translation (${_note.translatedLanguage ?? ''})',
          style: GoogleFonts.poppins(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: NotesTheme.textPrimary.withValues(alpha: 0.7),
          ),
        ),
        SizedBox(height: 8.h),
        NotesGlassCard(
          padding: EdgeInsets.all(16.w),
          child: Text(
            _note.translatedText!,
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              color: NotesTheme.textPrimary.withValues(alpha: 0.9),
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionItems() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Action items',
          style: GoogleFonts.poppins(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: NotesTheme.textPrimary.withValues(alpha: 0.7),
          ),
        ),
        SizedBox(height: 8.h),
        NotesGlassCard(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          child: Column(
            children: _note.actionItems.map((item) {
              return CheckboxListTile(
                value: item.isDone,
                onChanged: widget.readOnly
                    ? null
                    : (v) {
                        final updated = _note.actionItems.map((a) {
                          if (a.id == item.id) {
                            return a.copyWith(isDone: v ?? false);
                          }
                          return a;
                        }).toList();
                        final next = _note.copyWith(actionItems: updated);
                        setState(() => _note = next);
                        context.read<NotesBloc>().add(UpdateNote(next));
                      },
                activeColor: NotesTheme.bronze,
                title: Text(
                  item.description,
                  style: GoogleFonts.poppins(
                    fontSize: 13.sp,
                    color: NotesTheme.textPrimary,
                    decoration:
                        item.isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
