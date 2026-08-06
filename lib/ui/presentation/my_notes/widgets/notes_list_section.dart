import 'package:el_race/ui/presentation/my_notes/data/note_model.dart';
import 'package:el_race/ui/presentation/my_notes/theme/notes_theme.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_glass_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class NotesListSection extends StatelessWidget {
  const NotesListSection({
    super.key,
    this.notes = const [],
    this.onViewAll,
    this.onNoteTap,
    this.maxItems = 5,
    this.title = 'All Notes',
  });

  final List<NoteModel> notes;
  final VoidCallback? onViewAll;
  final ValueChanged<NoteModel>? onNoteTap;
  final int maxItems;
  final String title;

  @override
  Widget build(BuildContext context) {
    final displayNotes = notes.take(maxItems).toList();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: NotesTheme.textPrimary,
                    height: 1.2,
                  ),
                ),
              ),
              if (notes.length > maxItems)
                GestureDetector(
                  onTap: onViewAll,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 2.w),
                    child: Text(
                      'View all',
                      style: GoogleFonts.poppins(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        color: NotesTheme.textPrimary.withValues(alpha: 0.45),
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 14.h),
          ...List.generate(displayNotes.length, (index) {
            final note = displayNotes[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == displayNotes.length - 1 ? 0 : 10.h,
              ),
              child: _NotesListRow(
                note: note,
                onTap: onNoteTap == null ? null : () => onNoteTap!(note),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _NotesListRow extends StatelessWidget {
  const _NotesListRow({
    required this.note,
    this.onTap,
  });

  final NoteModel note;
  final VoidCallback? onTap;

  IconData get _noteIcon {
    switch (note.noteType) {
      case NoteType.audio:
        return Icons.mic_none_rounded;
      case NoteType.image:
        return Icons.image_outlined;
      case NoteType.text:
      default:
        return Icons.sticky_note_2_outlined;
    }
  }

  Color get _iconAccentColor {
    switch (note.noteType) {
      case NoteType.audio:
        return NotesTheme.bronze;
      case NoteType.image:
        return const Color(0xFF7CB9E8);
      case NoteType.text:
      default:
        return NotesTheme.textPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotesGlassCard(
      onTap: onTap,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      borderRadius: BorderRadius.circular(18.r),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _iconAccentColor.withValues(alpha: 0.12),
              border: Border.all(
                color: _iconAccentColor.withValues(alpha: 0.20),
              ),
            ),
            child: Icon(
              _noteIcon,
              size: 22.sp,
              color: _iconAccentColor.withValues(alpha: 0.92),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        note.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: NotesTheme.textPrimary,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (note.isImportant)
                      Padding(
                        padding: EdgeInsets.only(left: 6.w),
                        child: Icon(
                          Icons.star_rounded,
                          size: 16.sp,
                          color: NotesTheme.bronze,
                        ),
                      ),
                    if (note.isTodo)
                      Padding(
                        padding: EdgeInsets.only(left: 4.w),
                        child: Icon(
                          Icons.check_circle_outline,
                          size: 16.sp,
                          color: const Color(0xFF4CAF50),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  note.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: NotesTheme.textPrimary.withValues(alpha: 0.45),
                    height: 1.2,
                  ),
                ),
                if (note.tags.isNotEmpty) ...[
                  SizedBox(height: 6.h),
                  Wrap(
                    spacing: 4.w,
                    runSpacing: 4.h,
                    children: note.tags.take(3).map((tag) {
                      return Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: NotesTheme.bronze.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          tag,
                          style: GoogleFonts.poppins(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w500,
                            color: NotesTheme.bronze,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Container(
            width: 34.w,
            height: 34.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: NotesTheme.textPrimary.withValues(alpha: 0.10),
              border: Border.all(
                color: NotesTheme.textPrimary.withValues(alpha: 0.12),
              ),
            ),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 18.sp,
              color: NotesTheme.textPrimary.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
