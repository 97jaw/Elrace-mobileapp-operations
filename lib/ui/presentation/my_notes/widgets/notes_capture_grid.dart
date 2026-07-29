import 'package:el_race/ui/presentation/my_notes/theme/notes_theme.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_glass_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// 2-column capture grid: tall audio (left) + text note / image notes (right).
class NotesCaptureGrid extends StatelessWidget {
  const NotesCaptureGrid({
    super.key,
    this.onStartRecording,
    this.onNewTextNote,
    this.onImageNotes,
  });

  final VoidCallback? onStartRecording;
  final VoidCallback? onNewTextNote;
  final VoidCallback? onImageNotes;

  @override
  Widget build(BuildContext context) {
    final gap = 12.w;
    final gridHeight = 280.h;

    return SizedBox(
      height: gridHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _AudioCaptureCard(onStartRecording: onStartRecording),
          ),
          SizedBox(width: gap),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _ActionTileCard(
                    icon: Icons.edit_note_rounded,
                    titleLine1: 'New text',
                    titleLine2: 'note',
                    showNewBadge: true,
                    onTap: onNewTextNote,
                  ),
                ),
                SizedBox(height: gap),
                Expanded(
                  child: _ActionTileCard(
                    icon: Icons.image_outlined,
                    titleLine1: 'Image',
                    titleLine2: 'notes',
                    onTap: onImageNotes,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesCornerIcon extends StatelessWidget {
  const _NotesCornerIcon({
    required this.icon,
    this.size = 52,
    this.iconSize = 28,
  });

  final IconData icon;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.w,
      height: size.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: NotesTheme.bronze.withValues(alpha: 0.14),
        border: Border.all(
          color: NotesTheme.bronze.withValues(alpha: 0.28),
        ),
      ),
      child: Icon(
        icon,
        size: iconSize.sp,
        color: NotesTheme.bronze,
      ),
    );
  }
}

/// First line larger; following line keeps the secondary title size.
class _NotesStackedTitle extends StatelessWidget {
  const _NotesStackedTitle({
    required this.line1,
    required this.line2,
    this.line1Size = 20,
    this.line2Size = 14,
  });

  final String line1;
  final String line2;
  final double line1Size;
  final double line2Size;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          line1,
          style: GoogleFonts.poppins(
            fontSize: line1Size.sp,
            fontWeight: FontWeight.w700,
            color: NotesTheme.textPrimary,
            height: 1.15,
          ),
        ),
        Text(
          line2,
          style: GoogleFonts.poppins(
            fontSize: line2Size.sp,
            fontWeight: FontWeight.w600,
            color: NotesTheme.textPrimary.withValues(alpha: 0.88),
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _AudioCaptureCard extends StatelessWidget {
  const _AudioCaptureCard({this.onStartRecording});

  final VoidCallback? onStartRecording;

  @override
  Widget build(BuildContext context) {
    return NotesGlassCard(
      onTap: onStartRecording,
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _NotesCornerIcon(
            icon: Icons.mic_none_rounded,
            size: 54,
            iconSize: 28,
          ),
          const Spacer(),
          const _NotesStackedTitle(
            line1: 'Capture Your',
            line2: 'Audio Note Here',
            line1Size: 20,
            line2Size: 14,
          ),
          SizedBox(height: 6.h),
          Text(
            'Begin Audio Note',
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: NotesTheme.textPrimary.withValues(alpha: 0.45),
              height: 1.2,
            ),
          ),
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onStartRecording,
              style: FilledButton.styleFrom(
                backgroundColor: NotesTheme.bronze.withValues(alpha: 0.92),
                foregroundColor: NotesTheme.pureBlack,
                elevation: 0,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
              child: Text(
                'Start recording',
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTileCard extends StatelessWidget {
  const _ActionTileCard({
    required this.icon,
    required this.titleLine1,
    required this.titleLine2,
    this.onTap,
    this.showNewBadge = false,
  });

  final IconData icon;
  final String titleLine1;
  final String titleLine2;
  final VoidCallback? onTap;
  final bool showNewBadge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: NotesGlassCard(
            onTap: onTap,
            padding: EdgeInsets.fromLTRB(14.w, 12.h, 12.w, 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NotesCornerIcon(
                      icon: icon,
                      size: 44,
                      iconSize: 24,
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 22.sp,
                      color: NotesTheme.textPrimary.withValues(alpha: 0.45),
                    ),
                  ],
                ),
                const Spacer(),
                _NotesStackedTitle(
                  line1: titleLine1,
                  line2: titleLine2,
                  line1Size: 16,
                  line2Size: 12,
                ),
              ],
            ),
          ),
        ),
        if (showNewBadge)
          Positioned(
            top: -4.h,
            right: 8.w,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: NotesTheme.bronze,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: NotesTheme.bronze.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'New',
                style: GoogleFonts.poppins(
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w700,
                  color: NotesTheme.pureBlack,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
