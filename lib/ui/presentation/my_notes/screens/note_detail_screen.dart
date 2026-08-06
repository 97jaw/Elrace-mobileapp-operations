import 'package:el_race/ui/presentation/my_notes/bloc/notes_bloc.dart';
import 'package:el_race/ui/presentation/my_notes/data/note_model.dart';
import 'package:el_race/ui/presentation/my_notes/screens/add_note_screen.dart';
import 'package:el_race/ui/presentation/my_notes/theme/notes_theme.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_glass_card.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_royal_bronze_background.dart';
import 'package:el_race/utils/safe_insets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class NoteDetailScreen extends StatelessWidget {
  final NoteModel note;

  const NoteDetailScreen({
    super.key,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return _NoteDetailView(note: note);
  }
}

class _NoteDetailView extends StatefulWidget {
  final NoteModel note;

  const _NoteDetailView({required this.note});

  @override
  State<_NoteDetailView> createState() => _NoteDetailViewState();
}

class _NoteDetailViewState extends State<_NoteDetailView> {
  late NoteModel _note;

  @override
  void initState() {
    super.initState();
    _note = widget.note;
  }

  void _editNote() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: context.read<NotesBloc>(),
          child: AddNoteScreen(existingNote: _note),
        ),
      ),
    );
  }

  void _toggleImportant() {
    context.read<NotesBloc>().add(
          ToggleNoteImportant(_note.id, !_note.isImportant),
        );
    setState(() {
      _note = _note.copyWith(isImportant: !_note.isImportant);
    });
  }

  void _toggleTodo() {
    context.read<NotesBloc>().add(
          ToggleNoteTodo(_note.id, !_note.isTodo),
        );
    setState(() {
      _note = _note.copyWith(isTodo: !_note.isTodo);
    });
  }

  void _deleteNote() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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

  void _shareNote() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share to chat coming soon'),
        backgroundColor: NotesTheme.charcoal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = context.systemBottomInset;
    final formattedDate = DateFormat('EEEE, MMM dd, yyyy • hh:mm a')
        .format(_note.updatedAt);

    return AnnotatedRegion<SystemUiOverlayStyle>(
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
                    padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, bottomPad + 20.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 8.h),
                        _buildMetadata(formattedDate),
                        SizedBox(height: 20.h),
                        _buildTitle(),
                        SizedBox(height: 16.h),
                        _buildContent(),
                        if (_note.tags.isNotEmpty) ...[
                          SizedBox(height: 20.h),
                          _buildTags(),
                        ],
                        SizedBox(height: 24.h),
                        _buildQuickActions(),
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
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.arrow_back_rounded,
              color: NotesTheme.textPrimary,
              size: 24.sp,
            ),
          ),
          const Spacer(),
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
                    const Icon(Icons.delete_outline, color: Colors.red, size: 20),
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
      default:
        return Icons.sticky_note_2_outlined;
    }
  }

  String _getNoteTypeLabel() {
    switch (_note.noteType) {
      case NoteType.audio:
        return 'Audio Note';
      case NoteType.image:
        return 'Image Note';
      case NoteType.text:
      default:
        return 'Text Note';
    }
  }

  Widget _buildTitle() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            _note.title,
            style: GoogleFonts.poppins(
              fontSize: 26.sp,
              fontWeight: FontWeight.w700,
              color: NotesTheme.textPrimary,
              height: 1.2,
            ),
          ),
        ),
        if (_note.isImportant)
          Padding(
            padding: EdgeInsets.only(left: 8.w, top: 4.h),
            child: Icon(
              Icons.star_rounded,
              size: 24.sp,
              color: NotesTheme.bronze,
            ),
          ),
        if (_note.isTodo)
          Padding(
            padding: EdgeInsets.only(left: 4.w, top: 4.h),
            child: Icon(
              Icons.check_circle_outline,
              size: 24.sp,
              color: const Color(0xFF4CAF50),
            ),
          ),
      ],
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
      child: Text(
        _note.content,
        style: GoogleFonts.poppins(
          fontSize: 15.sp,
          color: NotesTheme.textPrimary.withValues(alpha: 0.9),
          height: 1.7,
        ),
      ),
    );
  }

  Widget _buildTags() {
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
          children: _note.tags.map((tag) {
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: NotesTheme.bronze.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: NotesTheme.bronze.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                tag,
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: NotesTheme.bronze,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.poppins(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: NotesTheme.textPrimary.withValues(alpha: 0.7),
          ),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.star_rounded,
                label: _note.isImportant ? 'Unstar' : 'Star',
                isActive: _note.isImportant,
                activeColor: NotesTheme.bronze,
                onTap: _toggleImportant,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildActionButton(
                icon: Icons.check_circle_outline,
                label: _note.isTodo ? 'Remove To-do' : 'Add To-do',
                isActive: _note.isTodo,
                activeColor: const Color(0xFF4CAF50),
                onTap: _toggleTodo,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: NotesGlassCard(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        borderRadius: BorderRadius.circular(14.r),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20.sp,
              color: isActive
                  ? activeColor
                  : NotesTheme.textPrimary.withValues(alpha: 0.5),
            ),
            SizedBox(width: 8.w),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: isActive
                      ? activeColor
                      : NotesTheme.textPrimary.withValues(alpha: 0.5),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
