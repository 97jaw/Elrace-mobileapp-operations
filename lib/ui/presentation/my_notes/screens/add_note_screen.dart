import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui show TextDirection;

import 'package:el_race/ui/presentation/my_notes/bloc/notes_bloc.dart';
import 'package:el_race/ui/presentation/my_notes/data/note_model.dart';
import 'package:el_race/ui/presentation/my_notes/repository/firebase_notes_repository.dart';
import 'package:el_race/ui/presentation/my_notes/services/notes_ai_service.dart';
import 'package:el_race/ui/presentation/my_notes/services/notes_audio_recording_service.dart';
import 'package:el_race/ui/presentation/my_notes/services/notes_cache_service.dart';
import 'package:el_race/ui/presentation/my_notes/services/notes_image_service.dart';
import 'package:el_race/ui/presentation/my_notes/theme/notes_theme.dart';
import 'package:el_race/ui/presentation/my_notes/utils/notes_markdown_format.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_audio_player_widget.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_composer_ai_sheet.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_composer_toolbar.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_format_sheet.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_glass_card.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_royal_bronze_background.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

/// iPhone Notes–style composer: title + body, format, photo, audio, AI.
class AddNoteScreen extends StatefulWidget {
  final NoteModel? existingNote;

  const AddNoteScreen({
    super.key,
    this.existingNote,
  });

  @override
  State<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends State<AddNoteScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _contentFocusNode = FocusNode();

  final NotesImageService _imageService = NotesImageService();
  final NotesAudioRecordingService _audioService = NotesAudioRecordingService();
  final NotesAiService _aiService = NotesAiService();
  final FirebaseNotesRepository _notesRepo = FirebaseNotesRepository();

  late final String _noteId;
  late final DateTime _createdAt;
  bool _persisted = false;
  bool _saving = false;
  bool _aiBusy = false;

  /// Remote images already on the note (edit) + freshly uploaded.
  List<ImageAttachment> _images = [];
  /// Local picks not yet uploaded.
  final List<XFile> _pendingImages = [];
  RecordingInfo? _recording;

  NoteAiMode _aiMode = NoteAiMode.none;
  NoteAiStatus _aiStatus = NoteAiStatus.none;
  String? _aiSummary;
  String? _aiBulletPoints;
  String? _translatedText;
  String? _translatedLanguage;
  List<ActionItem> _actionItems = const [];

  StreamSubscription<NoteModel?>? _liveSub;
  Timer? _autoSaveTimer;
  bool _draftRestored = false;

  TextAlign _contentAlign = TextAlign.start;
  ui.TextDirection _contentDirection = ui.TextDirection.ltr;

  bool get _isEditing => widget.existingNote != null;

  bool get _hasContent =>
      _titleController.text.trim().isNotEmpty ||
      _contentController.text.trim().isNotEmpty ||
      _images.isNotEmpty ||
      _pendingImages.isNotEmpty ||
      _recording != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final n = widget.existingNote!;
      _noteId = n.id;
      _createdAt = n.createdAt;
      _persisted = true;
      _titleController.text = n.title;
      _contentController.text = n.content;
      _images = List.from(n.images);
      _recording = n.recording;
      _aiMode = n.aiMode;
      _aiStatus = n.aiStatus;
      _aiSummary = n.aiSummary;
      _aiBulletPoints = n.aiBulletPoints;
      _translatedText = n.translatedText;
      _translatedLanguage = n.translatedLanguage;
      _actionItems = List.from(n.actionItems);
      _ensureLiveWatch();
    } else {
      _noteId = const Uuid().v4();
      _createdAt = DateTime.now();
      _restoreDraft();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isEditing && mounted) {
        _titleFocusNode.requestFocus();
      }
    });
    _contentController.addListener(_onContentControllerChanged);
    _startAutoSave();
  }

  void _onContentControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _liveSub?.cancel();
    _contentController.removeListener(_onContentControllerChanged);
    _titleController.dispose();
    _contentController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    _audioService.dispose();
    super.dispose();
  }

  void _ensureLiveWatch() {
    if (_liveSub != null) return;
    _liveSub = _notesRepo.watchNoteById(_noteId).listen((live) {
      if (!mounted || live == null) return;
      setState(() {
        // Pull server AI / transcript without clobbering in-progress typing.
        _aiMode = live.aiMode;
        _aiStatus = live.aiStatus;
        _aiSummary = live.aiSummary;
        _aiBulletPoints = live.aiBulletPoints;
        _translatedText = live.translatedText;
        _translatedLanguage = live.translatedLanguage;
        _actionItems = List.from(live.actionItems);
        if (live.images.isNotEmpty) {
          _images = List.from(live.images);
        }
        final liveRec = live.recording;
        if (liveRec != null) {
          final local = _recording;
          final liveHasTranscript =
              liveRec.transcript?.trim().isNotEmpty ?? false;
          final localEmpty = local == null ||
              local.transcript == null ||
              local.transcript!.trim().isEmpty;
          if (localEmpty || liveHasTranscript || liveRec.audioUrl.isNotEmpty) {
            _recording = liveRec;
          }
        }
        if (_aiStatus == NoteAiStatus.done ||
            _aiStatus == NoteAiStatus.error ||
            (_aiSummary?.isNotEmpty ?? false) ||
            (_aiBulletPoints?.isNotEmpty ?? false)) {
          _aiBusy = false;
        }
      });
    }, onError: (e) {
      debugPrint('AddNoteScreen live watch error: $e');
    });
  }

  void _startAutoSave() {
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_hasContent && !_isEditing && !_persisted) {
        _saveDraft();
      }
    });
  }

  Future<void> _saveDraft() async {
    await NotesCacheService.instance.saveCurrentDraft(
      title: _titleController.text,
      content: _contentController.text,
    );
  }

  Future<void> _restoreDraft() async {
    if (_draftRestored) return;
    _draftRestored = true;

    final draft = await NotesCacheService.instance.getCurrentDraft();
    if (draft == null || !mounted) return;
    final title = draft['title'] as String? ?? '';
    final content = draft['content'] as String? ?? '';
    if (title.isEmpty && content.isEmpty) return;

    final shouldRestore = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NotesTheme.surface,
        title: Text(
          'Restore draft?',
          style: GoogleFonts.poppins(
            color: NotesTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'You have an unsaved draft. Would you like to restore it?',
          style: GoogleFonts.poppins(
            color: NotesTheme.textPrimary.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              NotesCacheService.instance.clearCurrentDraft();
              Navigator.of(context).pop(false);
            },
            child: Text(
              'Discard',
              style: GoogleFonts.poppins(color: NotesTheme.textPrimary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Restore',
              style: GoogleFonts.poppins(color: NotesTheme.bronze),
            ),
          ),
        ],
      ),
    );

    if (shouldRestore == true && mounted) {
      setState(() {
        _titleController.text = title;
        _contentController.text = content;
      });
    }
  }

  NoteModel _buildNoteModel({
    List<ImageAttachment>? images,
    RecordingInfo? recording,
  }) {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final existing = widget.existingNote;
    return NoteModel(
      id: _noteId,
      ownerId: FirebaseAuth.instance.currentUser?.uid ??
          existing?.ownerId ??
          '',
      title: title.isEmpty ? 'Untitled' : title,
      content: content,
      noteType: NoteType.text,
      // Preserve legacy flags/tags when editing; never set from this UI.
      tags: existing?.tags ?? const [],
      isImportant: existing?.isImportant ?? false,
      isTodo: existing?.isTodo ?? false,
      createdAt: _createdAt,
      updatedAt: DateTime.now(),
      images: images ?? _images,
      recording: recording ?? _recording,
      aiMode: _aiMode,
      aiStatus: _aiStatus,
      aiSummary: _aiSummary,
      aiBulletPoints: _aiBulletPoints,
      translatedText: _translatedText,
      translatedLanguage: _translatedLanguage,
      actionItems: _actionItems,
      sharedWithUids: existing?.sharedWithUids ?? const [],
      sharedWith: existing?.sharedWith ?? const [],
      aiContext: existing?.aiContext,
    );
  }

  Future<bool> _persistNote({
    bool popAfter = false,
    bool allowEmpty = false,
  }) async {
    if (_saving && !allowEmpty) return false;
    if (!allowEmpty && !_hasContent) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Add a title, text, photo, or audio'),
            backgroundColor: NotesTheme.surface,
          ),
        );
      }
      return false;
    }

    setState(() => _saving = true);
    try {
      // Upload pending photos first.
      if (_pendingImages.isNotEmpty) {
        final uploaded = await _imageService.uploadFiles(
          noteId: _noteId,
          files: List.from(_pendingImages),
        );
        _images = [..._images, ...uploaded];
        _pendingImages.clear();
      }

      final note = _buildNoteModel();
      if (!mounted) return false;
      final bloc = context.read<NotesBloc>();
      if (_persisted || _isEditing) {
        bloc.add(UpdateNote(note));
      } else {
        bloc.add(AddNote(note));
        await NotesCacheService.instance.clearCurrentDraft();
      }

      final next = await bloc.stream
          .firstWhere(
            (s) => s is NotesLoaded || s is NoteActionError || s is NotesError,
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return false;
      if (next is NoteActionError || next is NotesError) {
        final message = next is NoteActionError
            ? next.message
            : (next as NotesError).message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: NotesTheme.surface,
          ),
        );
        return false;
      }

      _persisted = true;
      _ensureLiveWatch();
      if (popAfter && mounted) {
        Navigator.of(context).pop();
      } else if (mounted) {
        setState(() {});
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: NotesTheme.surface,
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onDone() async {
    await _persistNote(popAfter: true);
  }

  Future<bool> _onWillPop() async {
    if (!_hasContent || _persisted) return true;
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NotesTheme.surface,
        title: Text(
          'Discard note?',
          style: GoogleFonts.poppins(
            color: NotesTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'You have unsaved changes.',
          style: GoogleFonts.poppins(
            color: NotesTheme.textPrimary.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Keep editing',
              style: GoogleFonts.poppins(color: NotesTheme.textPrimary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Discard',
              style: GoogleFonts.poppins(color: NotesTheme.bronze),
            ),
          ),
        ],
      ),
    );
    if (shouldDiscard == true) {
      await NotesCacheService.instance.clearCurrentDraft();
    }
    return shouldDiscard ?? false;
  }

  Future<void> _attachPhotoLibrary() async {
    final picked = await _imageService.pickImages(fromCamera: false);
    if (picked.isEmpty || !mounted) return;
    setState(() => _pendingImages.addAll(picked));
  }

  Future<void> _attachTakePhoto() async {
    final picked = await _imageService.pickImages(fromCamera: true);
    if (picked.isEmpty || !mounted) return;
    setState(() => _pendingImages.addAll(picked));
  }

  Future<void> _attachVideo() async {
    try {
      final picker = ImagePicker();
      final video = await picker.pickVideo(source: ImageSource.camera);
      if (!mounted) return;
      if (video == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Video attachments coming soon'),
          backgroundColor: NotesTheme.surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open camera: $e'),
          backgroundColor: NotesTheme.surface,
        ),
      );
    }
  }

  Future<void> _attachFile() async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );
      if (result == null || !mounted) return;
      final images = <XFile>[];
      var skipped = 0;
      for (final f in result.files) {
        final path = f.path;
        if (path == null || path.isEmpty) {
          skipped++;
          continue;
        }
        final lower = (f.extension ?? path).toLowerCase();
        final isImage = lower.endsWith('jpg') ||
            lower.endsWith('jpeg') ||
            lower.endsWith('png') ||
            lower.endsWith('gif') ||
            lower.endsWith('webp') ||
            lower.endsWith('heic');
        if (isImage) {
          images.add(XFile(path));
        } else {
          skipped++;
        }
      }
      if (images.isNotEmpty) {
        setState(() => _pendingImages.addAll(images));
      }
      if (skipped > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              images.isEmpty
                  ? 'File attachments coming soon'
                  : 'Added ${images.length} image(s). Other file types coming soon.',
            ),
            backgroundColor: NotesTheme.surface,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attach failed: $e'),
          backgroundColor: NotesTheme.surface,
        ),
      );
    }
  }

  Future<void> _scanDocument() async {
    try {
      final pictures = await CunningDocumentScanner.getPictures(
        noOfPages: 20,
        isGalleryImportAllowed: true,
      );
      if (!mounted) return;
      if (pictures == null || pictures.isEmpty) return;
      setState(() {
        _pendingImages.addAll(pictures.map((p) => XFile(p)));
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scan failed: $e'),
          backgroundColor: NotesTheme.surface,
        ),
      );
    }
  }

  Future<void> _insertLink() async {
    final labelCtrl = TextEditingController();
    final urlCtrl = TextEditingController(text: 'https://');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NotesTheme.surface,
        title: Text(
          'Add link',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: NotesTheme.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              decoration: InputDecoration(
                labelText: 'Title',
                labelStyle: GoogleFonts.poppins(color: NotesTheme.textPrimary),
              ),
              style: GoogleFonts.poppins(color: NotesTheme.textPrimary),
            ),
            SizedBox(height: 8.h),
            TextField(
              controller: urlCtrl,
              decoration: InputDecoration(
                labelText: 'URL',
                labelStyle: GoogleFonts.poppins(color: NotesTheme.textPrimary),
              ),
              style: GoogleFonts.poppins(color: NotesTheme.textPrimary),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: NotesTheme.textPrimary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Insert',
                style: GoogleFonts.poppins(color: NotesTheme.bronze)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      labelCtrl.dispose();
      urlCtrl.dispose();
      return;
    }
    NotesMarkdownFormat.insertLink(
      _contentController,
      label: labelCtrl.text,
      url: urlCtrl.text,
    );
    labelCtrl.dispose();
    urlCtrl.dispose();
    setState(() {});
    _contentFocusNode.requestFocus();
  }

  Future<void> _attachAudio() async {
    final result = await showModalBottomSheet<NotesAudioRecordingResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NotesTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) => _InlineAudioRecorderSheet(service: _audioService),
    );
    if (result == null || !mounted) return;
    if (!result.isValid || result.file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Recording too short'),
          backgroundColor: NotesTheme.surface,
        ),
      );
      return;
    }

    try {
      // Persist note shell first so Storage path + Whisper can find it.
      if (!_persisted) {
        final ok = await _persistNote(popAfter: false, allowEmpty: true);
        if (!ok) return;
      }

      setState(() => _saving = true);
      final language = (result.language).trim().isEmpty ? 'auto' : result.language;
      final audioUrl = await _audioService.uploadAudio(
        noteId: _noteId,
        audioFile: result.file!,
        language: language,
      );
      if (!mounted) return;
      final recording = RecordingInfo(
        audioUrl: audioUrl,
        durationSeconds: (result.durationMs / 1000).round(),
        language: language,
        status: TranscriptionStatus.pending,
        storagePath: 'chat_media/notes/${FirebaseAuth.instance.currentUser?.uid ?? ''}/$_noteId/audio.m4a',
      );
      _recording = recording;
      setState(() => _saving = false);
      await _persistNote(popAfter: false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Audio attach failed: $e'),
            backgroundColor: NotesTheme.surface,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _runAi(String mode, {String? lang}) async {
    if (!_hasContent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Add content before running AI'),
          backgroundColor: NotesTheme.surface,
        ),
      );
      return;
    }
    setState(() => _aiBusy = true);
    try {
      final ok = await _persistNote(popAfter: false);
      if (!ok || !mounted) return;
      _ensureLiveWatch();

      if (mode == 'summarize' || mode == 'bullets') {
        final aiMode =
            mode == 'bullets' ? NoteAiMode.bullets : NoteAiMode.summarize;
        setState(() {
          _aiMode = aiMode;
          _aiStatus = NoteAiStatus.pending;
        });
        final note = _buildNoteModel().copyWith(
          aiMode: aiMode,
          aiStatus: NoteAiStatus.pending,
        );
        context.read<NotesBloc>().add(UpdateNote(note));
      }

      await _aiService.processNoteAi(
        noteId: _noteId,
        mode: mode,
        targetLanguage: lang,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI $mode started — results appear below'),
          backgroundColor: NotesTheme.surface,
        ),
      );
      // Keep _aiBusy true until live watch sees done/error/result.
    } catch (e) {
      if (!mounted) return;
      setState(() => _aiBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI failed: $e'),
          backgroundColor: NotesTheme.surface,
        ),
      );
    }
  }

  void _removePendingImage(int index) {
    setState(() => _pendingImages.removeAt(index));
  }

  void _removeRemoteImage(String id) {
    setState(() => _images.removeWhere((e) => e.id == id));
  }

  void _removeRecording() {
    setState(() => _recording = null);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = context.systemBottomInset;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final dateLabel = DateFormat('EEEE, MMM dd · hh:mm a').format(
      _isEditing ? widget.existingNote!.updatedAt : DateTime.now(),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: NotesTheme.systemOverlay,
        child: NotesRoyalBronzeBackground(
          // Keep toolbar glued above the keyboard (don't double-inset).
          child: Scaffold(
            backgroundColor: Colors.transparent,
            resizeToAvoidBottomInset: false,
            body: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _contentFocusNode.requestFocus(),
                      behavior: HitTestBehavior.translucent,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dateLabel,
                              style: GoogleFonts.poppins(
                                fontSize: 12.sp,
                                color: NotesTheme.textPrimary
                                    .withValues(alpha: 0.45),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            _buildTitleField(),
                            SizedBox(height: 4.h),
                            _buildContentField(),
                            if (_images.isNotEmpty ||
                                _pendingImages.isNotEmpty) ...[
                              SizedBox(height: 16.h),
                              _buildPhotoStrip(),
                            ],
                              if (_recording != null &&
                                _recording!.audioUrl.isNotEmpty) ...[
                              SizedBox(height: 16.h),
                              _buildAudioChip(),
                              if ((_recording!.transcript?.trim().isNotEmpty ??
                                      false) ||
                                  _recording!.status ==
                                      TranscriptionStatus.pending ||
                                  _recording!.status ==
                                      TranscriptionStatus.processing ||
                                  _recording!.status ==
                                      TranscriptionStatus.error) ...[
                                SizedBox(height: 12.h),
                                _buildComposerTranscript(),
                              ],
                            ],
                            if (_shouldShowComposerAi) ...[
                              SizedBox(height: 16.h),
                              _buildComposerAiResults(),
                            ],
                            if (_translatedText != null &&
                                _translatedText!.trim().isNotEmpty) ...[
                              SizedBox(height: 16.h),
                              _buildComposerTranslation(),
                            ],
                            if (_saving || _aiBusy) ...[
                              SizedBox(height: 16.h),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 16.w,
                                    height: 16.w,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: NotesTheme.bronze,
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  Text(
                                    _aiBusy
                                        ? 'AI working… results appear below'
                                        : 'Saving…',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.sp,
                                      color: NotesTheme.textPrimary
                                          .withValues(alpha: 0.55),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            // Extra space so last lines aren't under toolbar.
                            SizedBox(height: 24.h),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildAccessoryBar(bottomPad, keyboard),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _shouldShowComposerAi {
    if (_aiSummary?.trim().isNotEmpty == true) return true;
    if (_aiBulletPoints?.trim().isNotEmpty == true) return true;
    if (_aiBusy) return true;
    return _aiStatus == NoteAiStatus.pending ||
        _aiStatus == NoteAiStatus.processing ||
        _aiStatus == NoteAiStatus.error ||
        _aiStatus == NoteAiStatus.done;
  }

  Widget _buildComposerTranscript() {
    final recording = _recording!;
    final transcript = recording.transcript?.trim() ?? '';
    final isPending = transcript.isEmpty &&
        (recording.status == TranscriptionStatus.pending ||
            recording.status == TranscriptionStatus.processing);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transcript',
          style: GoogleFonts.poppins(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: NotesTheme.textPrimary.withValues(alpha: 0.65),
          ),
        ),
        SizedBox(height: 8.h),
        NotesGlassCard(
          padding: EdgeInsets.all(14.w),
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
                    height: 1.55,
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
                        isPending
                            ? 'Transcribing audio…'
                            : recording.status == TranscriptionStatus.error
                                ? 'Transcription failed'
                                : 'No transcript yet',
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

  Widget _buildComposerAiResults() {
    final summary = _aiSummary?.trim() ?? '';
    final bullets = _aiBulletPoints?.trim() ?? '';
    final busy = _aiBusy ||
        _aiStatus == NoteAiStatus.pending ||
        _aiStatus == NoteAiStatus.processing;
    final waitingSummary =
        busy && _aiMode == NoteAiMode.summarize && summary.isEmpty;
    final waitingBullets =
        busy && _aiMode == NoteAiMode.bullets && bullets.isEmpty;

    final blocks = <Widget>[];

    if (summary.isNotEmpty) {
      blocks.add(_composerAiTextBlock(title: 'Summary', body: summary));
    } else if (waitingSummary) {
      blocks.add(_composerAiPendingBlock(title: 'Summary', isError: false));
    }

    if (bullets.isNotEmpty || waitingBullets) {
      if (blocks.isNotEmpty) blocks.add(SizedBox(height: 12.h));
      if (bullets.isNotEmpty) {
        blocks.add(_composerAiTextBlock(title: 'Bullet points', body: bullets));
      } else {
        blocks.add(
          _composerAiPendingBlock(title: 'Bullet points', isError: false),
        );
      }
    }

    if (_aiStatus == NoteAiStatus.error &&
        summary.isEmpty &&
        bullets.isEmpty &&
        !busy) {
      blocks.add(
        _composerAiPendingBlock(title: 'AI results', isError: true),
      );
    }

    if (blocks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }

  Widget _composerAiTextBlock({required String title, required String body}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: NotesTheme.textPrimary.withValues(alpha: 0.65),
          ),
        ),
        SizedBox(height: 8.h),
        NotesGlassCard(
          padding: EdgeInsets.all(14.w),
          child: Text(
            body,
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              color: NotesTheme.textPrimary.withValues(alpha: 0.9),
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }

  Widget _composerAiPendingBlock({
    required String title,
    required bool isError,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: NotesTheme.textPrimary.withValues(alpha: 0.65),
          ),
        ),
        SizedBox(height: 8.h),
        NotesGlassCard(
          padding: EdgeInsets.all(14.w),
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
                      ? 'AI failed — try again from the AI menu'
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

  Widget _buildComposerTranslation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Translation (${_translatedLanguage ?? ''})',
          style: GoogleFonts.poppins(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: NotesTheme.textPrimary.withValues(alpha: 0.65),
          ),
        ),
        SizedBox(height: 8.h),
        NotesGlassCard(
          padding: EdgeInsets.all(14.w),
          child: Text(
            _translatedText!,
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              color: NotesTheme.textPrimary.withValues(alpha: 0.9),
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
      child: Row(
        children: [
          IconButton(
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && mounted) Navigator.of(context).pop();
            },
            icon: Icon(
              Icons.arrow_back_rounded,
              color: NotesTheme.textPrimary,
              size: 24.sp,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: _saving ? null : _onDone,
            child: Text(
              'Done',
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: NotesTheme.bronze,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField() {
    return TextField(
      controller: _titleController,
      focusNode: _titleFocusNode,
      style: GoogleFonts.poppins(
        fontSize: 26.sp,
        fontWeight: FontWeight.w700,
        color: NotesTheme.textPrimary,
        height: 1.2,
      ),
      decoration: InputDecoration(
        border: InputBorder.none,
        isDense: true,
        hintText: 'Title',
        hintStyle: GoogleFonts.poppins(
          fontSize: 26.sp,
          fontWeight: FontWeight.w700,
          color: NotesTheme.textPrimary.withValues(alpha: 0.28),
        ),
      ),
      textInputAction: TextInputAction.next,
      onSubmitted: (_) => _contentFocusNode.requestFocus(),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildContentField() {
    return TextField(
      controller: _contentController,
      focusNode: _contentFocusNode,
      maxLines: null,
      minLines: 6,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      textAlign: _contentAlign,
      textDirection: _contentDirection,
      style: GoogleFonts.poppins(
        fontSize: 16.sp,
        color: NotesTheme.textPrimary,
        height: 1.55,
      ),
      decoration: InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
        hintText: 'Start writing…',
        hintStyle: GoogleFonts.poppins(
          fontSize: 16.sp,
          color: NotesTheme.textPrimary.withValues(alpha: 0.28),
          height: 1.55,
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildPhotoStrip() {
    final total = _images.length + _pendingImages.length;
    return SizedBox(
      height: 96.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: total,
        separatorBuilder: (_, __) => SizedBox(width: 10.w),
        itemBuilder: (context, i) {
          if (i < _images.length) {
            final img = _images[i];
            return _thumb(
              networkUrl: img.imageUrl,
              onRemove: () => _removeRemoteImage(img.id),
            );
          }
          final pending = _pendingImages[i - _images.length];
          return _thumb(
            filePath: pending.path,
            onRemove: () => _removePendingImage(i - _images.length),
          );
        },
      ),
    );
  }

  Widget _thumb({
    String? networkUrl,
    String? filePath,
    required VoidCallback onRemove,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12.r),
          child: filePath != null
              ? Image.file(
                  File(filePath),
                  width: 96.w,
                  height: 96.w,
                  fit: BoxFit.cover,
                )
              : Image.network(
                  networkUrl!,
                  width: 96.w,
                  height: 96.w,
                  fit: BoxFit.cover,
                ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: NotesTheme.charcoal,
                shape: BoxShape.circle,
                border: Border.all(color: NotesTheme.bronze.withValues(alpha: 0.4)),
              ),
              child: Icon(Icons.close, size: 14.sp, color: NotesTheme.textPrimary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioChip() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Audio',
              style: GoogleFonts.poppins(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: NotesTheme.textPrimary.withValues(alpha: 0.6),
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: _removeRecording,
              child: Text(
                'Remove',
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  color: Colors.redAccent,
                ),
              ),
            ),
          ],
        ),
        NotesAudioPlayerWidget(
          audioUrl: _recording!.audioUrl,
          durationSeconds: _recording!.durationSeconds,
        ),
      ],
    );
  }

  Widget _buildAccessoryBar(double bottomPad, double keyboard) {
    final padBottom = (keyboard > 0 ? keyboard : bottomPad) + 8.h;
    final bulletsOn = NotesMarkdownFormat.isBulletLine(_contentController);
    final markerOn = NotesMarkdownFormat.isHighlightActive(_contentController);
    final boldOn = NotesMarkdownFormat.isBoldActive(_contentController);
    final italicOn = NotesMarkdownFormat.isItalicActive(_contentController);
    final underlineOn = NotesMarkdownFormat.isUnderlineActive(_contentController);
    final busy = _saving || _aiBusy;

    return NotesComposerToolbar(
      bottomPadding: padBottom,
      boldSelected: boldOn,
      italicSelected: italicOn,
      underlineSelected: underlineOn,
      bulletSelected: bulletsOn,
      markerSelected: markerOn,
      enabled: !_saving,
      onFormat: () => showNotesFormatSheet(
        context,
        contentController: _contentController,
        textAlign: _contentAlign,
        textDirection: _contentDirection,
        onTextAlignChanged: (align) => setState(() => _contentAlign = align),
        onTextDirectionChanged: (dir) =>
            setState(() => _contentDirection = dir),
      ),
      onBold: () {
        NotesMarkdownFormat.bold(_contentController);
        setState(() {});
      },
      onItalic: () {
        NotesMarkdownFormat.italic(_contentController);
        setState(() {});
      },
      onUnderline: () {
        NotesMarkdownFormat.underline(_contentController);
        setState(() {});
      },
      onToggleBullet: () {
        NotesMarkdownFormat.toggleBullet(_contentController);
        setState(() {});
      },
      onMarker: () {
        NotesMarkdownFormat.highlight(_contentController);
        setState(() {});
      },
      onLink: _insertLink,
      onAttachFile: busy ? null : _attachFile,
      onScan: busy ? null : _scanDocument,
      onPhotoLibrary: busy ? null : _attachPhotoLibrary,
      onTakePhoto: busy ? null : _attachTakePhoto,
      onVideo: busy ? null : _attachVideo,
      onAudio: busy ? null : _attachAudio,
      onAi: busy
          ? null
          : () => showNotesComposerAiSheet(
                context,
                onRun: _runAi,
              ),
    );
  }
}

/// Compact in-sheet recorder for attaching audio to a text note.
class _InlineAudioRecorderSheet extends StatefulWidget {
  const _InlineAudioRecorderSheet({required this.service});

  final NotesAudioRecordingService service;

  @override
  State<_InlineAudioRecorderSheet> createState() =>
      _InlineAudioRecorderSheetState();
}

class _InlineAudioRecorderSheetState extends State<_InlineAudioRecorderSheet> {
  bool _recording = false;
  bool _busy = false;
  Timer? _tick;
  Duration _elapsed = Duration.zero;
  String _language = 'auto';

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_busy) return;
    if (!_recording) {
      setState(() => _busy = true);
      final ok = await widget.service.startRecording();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _recording = ok;
        _elapsed = Duration.zero;
      });
      if (ok) {
        _tick = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted) return;
          setState(() => _elapsed = widget.service.elapsed);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Microphone permission required'),
            backgroundColor: NotesTheme.surface,
          ),
        );
      }
      return;
    }

    setState(() => _busy = true);
    _tick?.cancel();
    final result = await widget.service.stopRecording();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _recording = false;
    });
    if (result != null) {
      Navigator.pop(context, result.copyWith(language: _language));
    }
  }

  Future<void> _cancel() async {
    _tick?.cancel();
    if (_recording) await widget.service.cancelRecording();
    if (mounted) Navigator.pop(context);
  }

  String get _timeLabel {
    final m = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _langChip(String label, String value) {
    final selected = _language == value;
    return GestureDetector(
      onTap: _recording || _busy
          ? null
          : () => setState(() => _language = value),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Attach audio',
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: NotesTheme.textPrimary,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _langChip('EN', 'en'),
              SizedBox(width: 8.w),
              _langChip('Arabic (forced)', 'ar'),
              SizedBox(width: 8.w),
              _langChip('Auto', 'auto'),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            _recording
                ? _timeLabel
                : 'Tap to record — transcript starts after upload',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: _recording ? 28.sp : 13.sp,
              fontWeight: FontWeight.w600,
              color: NotesTheme.bronze,
            ),
          ),
          SizedBox(height: 20.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: _cancel,
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(color: NotesTheme.textPrimary),
                ),
              ),
              SizedBox(width: 24.w),
              GestureDetector(
                onTap: _toggle,
                child: Container(
                  width: 72.w,
                  height: 72.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _recording
                        ? Colors.redAccent
                        : NotesTheme.bronze,
                  ),
                  child: _busy
                      ? const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        )
                      : Icon(
                          _recording ? Icons.stop_rounded : Icons.mic_rounded,
                          color: NotesTheme.pureBlack,
                          size: 32.sp,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
