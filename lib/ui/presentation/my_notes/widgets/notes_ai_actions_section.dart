import 'package:el_race/ui/presentation/my_notes/bloc/notes_bloc.dart';
import 'package:el_race/ui/presentation/my_notes/data/note_model.dart';
import 'package:el_race/ui/presentation/my_notes/services/notes_ai_service.dart';
import 'package:el_race/ui/presentation/my_notes/theme/notes_theme.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_glass_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Real AI actions for note detail (replaces coming-soon banner).
class NotesAiActionsSection extends StatefulWidget {
  final NoteModel note;
  final ValueChanged<NoteModel> onUpdated;

  const NotesAiActionsSection({
    super.key,
    required this.note,
    required this.onUpdated,
  });

  @override
  State<NotesAiActionsSection> createState() => _NotesAiActionsSectionState();
}

class _NotesAiActionsSectionState extends State<NotesAiActionsSection> {
  final NotesAiService _ai = NotesAiService();
  bool _busy = false;
  String? _busyLabel;

  Future<void> _run(String mode, {String? lang}) async {
    setState(() {
      _busy = true;
      _busyLabel = mode;
    });
    try {
      await _ai.processNoteAi(
        noteId: widget.note.id,
        mode: mode,
        targetLanguage: lang,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI $mode started — refresh in a moment'),
          backgroundColor: NotesTheme.surface,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI failed: $e'),
          backgroundColor: NotesTheme.surface,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyLabel = null;
        });
      }
    }
  }

  Future<void> _summarizeOrBullets(NoteAiMode mode) async {
    final next = widget.note.copyWith(
      aiMode: mode,
      aiStatus: NoteAiStatus.pending,
    );
    widget.onUpdated(next);
    context.read<NotesBloc>().add(UpdateNote(next));
    await _run(mode.name);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI tools',
          style: GoogleFonts.poppins(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: NotesTheme.textPrimary.withValues(alpha: 0.7),
          ),
        ),
        SizedBox(height: 10.h),
        NotesGlassCard(
          padding: EdgeInsets.all(12.w),
          child: Column(
            children: [
              if (_busy)
                Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: Row(
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
                        'Running ${_busyLabel ?? 'AI'}…',
                        style: GoogleFonts.poppins(
                          fontSize: 12.sp,
                          color: NotesTheme.textPrimary.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: [
                  _chip('Transcribe', Icons.mic_none_rounded,
                      () => _run('transcribe')),
                  _chip('Summarize', Icons.summarize_outlined,
                      () => _summarizeOrBullets(NoteAiMode.summarize)),
                  _chip('Bullets', Icons.format_list_bulleted,
                      () => _summarizeOrBullets(NoteAiMode.bullets)),
                  _chip('Actions', Icons.checklist_rounded,
                      () => _run('actions')),
                  _chip('Smart tags', Icons.label_outline,
                      () => _run('tags')),
                  _chip('To EN', Icons.translate,
                      () => _run('translate', lang: 'en')),
                  _chip('To AR', Icons.translate,
                      () => _run('translate', lang: 'ar')),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: _busy ? null : onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: NotesTheme.bronze.withValues(alpha: 0.15),
          border: Border.all(color: NotesTheme.bronze.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14.sp, color: NotesTheme.bronze),
            SizedBox(width: 6.w),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: NotesTheme.bronze,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
