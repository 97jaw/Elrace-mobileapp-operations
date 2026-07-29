import 'package:el_race/ui/presentation/my_notes/theme/notes_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class NotesFilterOption {
  const NotesFilterOption({
    required this.label,
    this.count,
  });

  final String label;
  final int? count;
}

/// Horizontal filter pills (All / Important / To-do). Selection is visual only for now.
class NotesFilterChips extends StatelessWidget {
  const NotesFilterChips({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.options = const [
      NotesFilterOption(label: 'All', count: 23),
      NotesFilterOption(label: 'Important'),
      NotesFilterOption(label: 'To-do'),
    ],
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<NotesFilterOption> options;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        itemCount: options.length,
        separatorBuilder: (_, __) => SizedBox(width: 10.w),
        itemBuilder: (context, index) {
          final option = options[index];
          final selected = index == selectedIndex;
          return _NotesFilterChip(
            label: option.label,
            count: option.count,
            selected: selected,
            onTap: () => onSelected(index),
          );
        },
      ),
    );
  }
}

class _NotesFilterChip extends StatelessWidget {
  const _NotesFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? NotesTheme.chipSelectedBorder
        : NotesTheme.chipUnselectedBorder;
    final textColor = selected
        ? NotesTheme.chipSelectedText
        : NotesTheme.chipUnselectedText;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NotesTheme.chipRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(NotesTheme.chipRadius),
            border: Border.all(color: borderColor, width: 1.2),
            color: selected
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.transparent,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13.sp,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: textColor,
                  height: 1.1,
                ),
              ),
              if (count != null) ...[
                SizedBox(width: 8.w),
                Container(
                  constraints: BoxConstraints(minWidth: 22.w, minHeight: 22.w),
                  padding: EdgeInsets.symmetric(horizontal: 6.w),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? NotesTheme.chipBadgeFill
                        : NotesTheme.charcoal.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? NotesTheme.bronze.withValues(alpha: 0.35)
                          : Colors.white.withValues(alpha: 0.12),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    '$count',
                    style: GoogleFonts.poppins(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? NotesTheme.textPrimary
                          : NotesTheme.chipUnselectedText,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
