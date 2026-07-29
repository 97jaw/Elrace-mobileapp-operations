import 'package:el_race/ui/presentation/my_notes/theme/notes_theme.dart';
import 'package:el_race/ui/presentation/my_notes/widgets/notes_glass_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class NotesListItemData {
  const NotesListItemData({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}

/// "All Notes" header + list of created-note rows (placeholder data for now).
class NotesListSection extends StatelessWidget {
  const NotesListSection({
    super.key,
    this.items = const [
      NotesListItemData(
        title: 'Site review',
        subtitle: 'Updated 2h ago',
        icon: Icons.sticky_note_2_outlined,
      ),
      NotesListItemData(
        title: 'Meeting notes',
        subtitle: 'Yesterday · Audio',
        icon: Icons.mic_none_rounded,
      ),
      NotesListItemData(
        title: 'Inspection photos',
        subtitle: '3 days ago · Images',
        icon: Icons.image_outlined,
      ),
    ],
    this.onViewAll,
    this.onNoteTap,
  });

  final List<NotesListItemData> items;
  final VoidCallback? onViewAll;
  final ValueChanged<NotesListItemData>? onNoteTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'All Notes',
                  style: GoogleFonts.poppins(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: NotesTheme.textPrimary,
                    height: 1.2,
                  ),
                ),
              ),
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
          ...List.generate(items.length, (index) {
            final item = items[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == items.length - 1 ? 0 : 10.h,
              ),
              child: _NotesListRow(
                item: item,
                onTap: onNoteTap == null ? null : () => onNoteTap!(item),
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
    required this.item,
    this.onTap,
  });

  final NotesListItemData item;
  final VoidCallback? onTap;

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
              color: NotesTheme.textPrimary.withValues(alpha: 0.12),
              border: Border.all(
                color: NotesTheme.textPrimary.withValues(alpha: 0.14),
              ),
            ),
            child: Icon(
              item.icon,
              size: 22.sp,
              color: NotesTheme.textPrimary.withValues(alpha: 0.92),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: NotesTheme.textPrimary,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: NotesTheme.textPrimary.withValues(alpha: 0.45),
                    height: 1.2,
                  ),
                ),
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
