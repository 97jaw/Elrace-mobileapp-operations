import 'dart:async';

import 'package:el_race/ui/presentation/my_notes/bloc/notes_bloc.dart';
import 'package:el_race/ui/presentation/my_notes/data/note_model.dart';
import 'package:el_race/ui/presentation/my_notes/services/notes_cache_service.dart';
import 'package:el_race/ui/presentation/my_notes/theme/notes_theme.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_glass_card.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_royal_bronze_background.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

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

  bool _isImportant = false;
  bool _isTodo = false;
  List<String> _tags = [];
  final TextEditingController _tagController = TextEditingController();

  Timer? _autoSaveTimer;
  bool _draftRestored = false;

  bool get _isEditing => widget.existingNote != null;
  bool get _hasContent =>
      _titleController.text.trim().isNotEmpty ||
      _contentController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _titleController.text = widget.existingNote!.title;
      _contentController.text = widget.existingNote!.content;
      _isImportant = widget.existingNote!.isImportant;
      _isTodo = widget.existingNote!.isTodo;
      _tags = List.from(widget.existingNote!.tags);
    } else {
      _restoreDraft();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isEditing) {
        _titleFocusNode.requestFocus();
      }
    });
    _startAutoSave();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _startAutoSave() {
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_hasContent && !_isEditing) {
        _saveDraft();
      }
    });
  }

  Future<void> _saveDraft() async {
    await NotesCacheService.instance.saveCurrentDraft(
      title: _titleController.text,
      content: _contentController.text,
      isImportant: _isImportant,
      isTodo: _isTodo,
      tags: _tags,
    );
  }

  Future<void> _restoreDraft() async {
    if (_draftRestored) return;
    _draftRestored = true;

    final draft = await NotesCacheService.instance.getCurrentDraft();
    if (draft != null && mounted) {
      final title = draft['title'] as String? ?? '';
      final content = draft['content'] as String? ?? '';

      if (title.isNotEmpty || content.isNotEmpty) {
        final shouldRestore = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: NotesTheme.charcoal,
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
                style: TextButton.styleFrom(
                  backgroundColor: NotesTheme.bronze.withValues(alpha: 0.2),
                ),
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
            _isImportant = draft['isImportant'] as bool? ?? false;
            _isTodo = draft['isTodo'] as bool? ?? false;
            _tags = List<String>.from(draft['tags'] as List? ?? []);
          });
        }
      }
    }
  }

  Future<void> _clearDraftOnSave() async {
    await NotesCacheService.instance.clearCurrentDraft();
  }

  Future<void> _saveNote() async {
    debugPrint('📝 AddNoteScreen: _saveNote tapped');
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a title or content'),
          backgroundColor: NotesTheme.charcoal,
        ),
      );
      return;
    }

    final now = DateTime.now();
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    final note = NoteModel(
      id: _isEditing ? widget.existingNote!.id : const Uuid().v4(),
      ownerId: userId,
      title: title.isEmpty ? 'Untitled' : title,
      content: content,
      noteType: NoteType.text,
      tags: _tags,
      isImportant: _isImportant,
      isTodo: _isTodo,
      createdAt: _isEditing ? widget.existingNote!.createdAt : now,
      updatedAt: now,
    );

    final bloc = context.read<NotesBloc>();
    debugPrint(
      '📝 AddNoteScreen: dispatching ${_isEditing ? 'UpdateNote' : 'AddNote'} '
      'to bloc=${bloc.hashCode}',
    );
    if (_isEditing) {
      bloc.add(UpdateNote(note));
    } else {
      bloc.add(AddNote(note));
      await _clearDraftOnSave();
    }

    // Wait until save finishes so the list is updated before we pop.
    try {
      final next = await bloc.stream
          .firstWhere(
            (s) => s is NotesLoaded || s is NoteActionError || s is NotesError,
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (next is NoteActionError || next is NotesError) {
        final message = next is NoteActionError
            ? next.message
            : (next as NotesError).message;
        debugPrint('❌ AddNoteScreen: save failed: $message');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: NotesTheme.charcoal,
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }
      debugPrint(
        '✅ AddNoteScreen: save OK, notes=${(next as NotesLoaded).notes.length}',
      );
    } catch (e) {
      debugPrint('⚠️ AddNoteScreen: wait for save timed out/error: $e');
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<bool> _onWillPop() async {
    if (_hasContent && !_isEditing) {
      final shouldDiscard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: NotesTheme.charcoal,
          title: Text(
            'Discard note?',
            style: GoogleFonts.poppins(
              color: NotesTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'You have unsaved changes. Are you sure you want to discard them?',
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
              style: TextButton.styleFrom(
                backgroundColor: NotesTheme.bronze.withValues(alpha: 0.2),
              ),
              child: Text(
                'Discard',
                style: GoogleFonts.poppins(color: NotesTheme.bronze),
              ),
            ),
          ],
        ),
      );
      return shouldDiscard ?? false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = context.systemBottomInset;
    final currentDateTime = DateFormat('EEEE, MMM dd • hh:mm a').format(DateTime.now());

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
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: NotesTheme.pureBlack,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
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
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, bottomPad + 100.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 8.h),
                          Text(
                            currentDateTime,
                            style: GoogleFonts.poppins(
                              fontSize: 12.sp,
                              color: NotesTheme.textPrimary.withValues(alpha: 0.5),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 16.h),
                          _buildTitleField(),
                          SizedBox(height: 12.h),
                          _buildContentField(),
                          SizedBox(height: 20.h),
                          _buildOptionsSection(),
                          SizedBox(height: 16.h),
                          _buildTagsSection(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            floatingActionButton: _buildSaveButton(),
            floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && mounted) {
                Navigator.of(context).pop();
              }
            },
            icon: Icon(
              Icons.arrow_back_rounded,
              color: NotesTheme.textPrimary,
              size: 24.sp,
            ),
          ),
          Expanded(
            child: Text(
              _isEditing ? 'Edit Note' : 'New Note',
              style: GoogleFonts.poppins(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: NotesTheme.textPrimary,
              ),
            ),
          ),
          if (_isEditing)
            IconButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: NotesTheme.charcoal,
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
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(color: NotesTheme.textPrimary),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.read<NotesBloc>().add(
                                DeleteNote(widget.existingNote!.id),
                              );
                          Navigator.of(this.context).pop();
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
              },
              icon: Icon(
                Icons.delete_outline_rounded,
                color: NotesTheme.textPrimary.withValues(alpha: 0.7),
                size: 24.sp,
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
        fontSize: 24.sp,
        fontWeight: FontWeight.w700,
        color: NotesTheme.textPrimary,
        height: 1.2,
      ),
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: 'Title',
        hintStyle: GoogleFonts.poppins(
          fontSize: 24.sp,
          fontWeight: FontWeight.w700,
          color: NotesTheme.textPrimary.withValues(alpha: 0.3),
          height: 1.2,
        ),
      ),
      textInputAction: TextInputAction.next,
      onSubmitted: (_) => _contentFocusNode.requestFocus(),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildContentField() {
    return NotesGlassCard(
      padding: EdgeInsets.all(16.w),
      child: TextField(
        controller: _contentController,
        focusNode: _contentFocusNode,
        maxLines: null,
        minLines: 8,
        style: GoogleFonts.poppins(
          fontSize: 15.sp,
          color: NotesTheme.textPrimary,
          height: 1.6,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Start writing your note...',
          hintStyle: GoogleFonts.poppins(
            fontSize: 15.sp,
            color: NotesTheme.textPrimary.withValues(alpha: 0.3),
            height: 1.6,
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildOptionsSection() {
    return Row(
      children: [
        Expanded(
          child: _buildOptionChip(
            icon: Icons.star_rounded,
            label: 'Important',
            isSelected: _isImportant,
            selectedColor: NotesTheme.bronze,
            onTap: () => setState(() => _isImportant = !_isImportant),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _buildOptionChip(
            icon: Icons.check_circle_outline,
            label: 'To-do',
            isSelected: _isTodo,
            selectedColor: const Color(0xFF4CAF50),
            onTap: () => setState(() => _isTodo = !_isTodo),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionChip({
    required IconData icon,
    required String label,
    required bool isSelected,
    required Color selectedColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor.withValues(alpha: 0.15)
              : NotesTheme.glassFill,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected
                ? selectedColor.withValues(alpha: 0.5)
                : NotesTheme.glassBorder,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20.sp,
              color: isSelected
                  ? selectedColor
                  : NotesTheme.textPrimary.withValues(alpha: 0.5),
            ),
            SizedBox(width: 8.w),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? selectedColor
                    : NotesTheme.textPrimary.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags',
          style: GoogleFonts.poppins(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: NotesTheme.textPrimary.withValues(alpha: 0.7),
          ),
        ),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            ..._tags.map((tag) => _buildTagChip(tag)),
            _buildAddTagChip(),
          ],
        ),
      ],
    );
  }

  Widget _buildTagChip(String tag) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: NotesTheme.bronze.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: NotesTheme.bronze.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tag,
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: NotesTheme.bronze,
            ),
          ),
          SizedBox(width: 4.w),
          GestureDetector(
            onTap: () => _removeTag(tag),
            child: Icon(
              Icons.close,
              size: 14.sp,
              color: NotesTheme.bronze,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddTagChip() {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: NotesTheme.charcoal,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          builder: (context) => Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _tagController,
                  autofocus: true,
                  style: GoogleFonts.poppins(
                    color: NotesTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter tag name',
                    hintStyle: GoogleFonts.poppins(
                      color: NotesTheme.textPrimary.withValues(alpha: 0.5),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(color: NotesTheme.glassBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide(color: NotesTheme.glassBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: const BorderSide(color: NotesTheme.bronze),
                    ),
                  ),
                  onSubmitted: (_) {
                    _addTag();
                    Navigator.of(context).pop();
                  },
                ),
                SizedBox(height: 16.h),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      _addTag();
                      Navigator.of(context).pop();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: NotesTheme.bronze,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Text(
                      'Add Tag',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: NotesTheme.pureBlack,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: NotesTheme.glassFill,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: NotesTheme.glassBorder,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add,
              size: 14.sp,
              color: NotesTheme.textPrimary.withValues(alpha: 0.5),
            ),
            SizedBox(width: 4.w),
            Text(
              'Add tag',
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: NotesTheme.textPrimary.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    final hasContent = _hasContent;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: hasContent ? _saveNote : null,
          style: FilledButton.styleFrom(
            backgroundColor:
                hasContent ? NotesTheme.bronze : NotesTheme.charcoal,
            disabledBackgroundColor: NotesTheme.charcoal,
            padding: EdgeInsets.symmetric(vertical: 16.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
          ),
          child: Text(
            _isEditing ? 'Update Note' : 'Save Note',
            style: GoogleFonts.poppins(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: hasContent
                  ? NotesTheme.pureBlack
                  : NotesTheme.textPrimary.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }
}
