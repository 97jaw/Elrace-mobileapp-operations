import 'package:el_race/core/ui/adaptive_glass.dart';
import 'package:el_race/ui/presentation/my_notes/theme/notes_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

enum NotesBottomNavTab {
  home,
  documents,
  chat,
  profile,
}

/// Floating pill bottom bar for My Notes (UI shell; taps stubbed for now).
class NotesBottomNavBar extends StatelessWidget {
  const NotesBottomNavBar({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final NotesBottomNavTab selected;
  final ValueChanged<NotesBottomNavTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);

    return AdaptiveGlassLayer(
      borderRadius: radius,
      sigma: 18,
      fallbackColor: NotesTheme.charcoal.withValues(alpha: 0.92),
      fallbackBorder: Border.all(
        color: NotesTheme.bronze.withValues(alpha: 0.28),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: NotesTheme.bronze.withValues(alpha: 0.28),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              NotesTheme.charcoal.withValues(alpha: 0.72),
              NotesTheme.pureBlack.withValues(alpha: 0.78),
              NotesTheme.bronze.withValues(alpha: 0.18),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              selected: selected == NotesBottomNavTab.home,
              onTap: () => onSelected(NotesBottomNavTab.home),
            ),
            _NavItem(
              icon: Icons.description_outlined,
              selected: selected == NotesBottomNavTab.documents,
              onTap: () => onSelected(NotesBottomNavTab.documents),
            ),
            _NavItem(
              icon: Icons.chat_bubble_outline_rounded,
              selected: selected == NotesBottomNavTab.chat,
              onTap: () => onSelected(NotesBottomNavTab.chat),
            ),
            _NavItem(
              icon: Icons.person_outline_rounded,
              selected: selected == NotesBottomNavTab.profile,
              onTap: () => onSelected(NotesBottomNavTab.profile),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: 48.w,
          height: 48.w,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      NotesTheme.bronze,
                      NotesTheme.bronze.withValues(alpha: 0.72),
                      NotesTheme.charcoal,
                    ],
                  )
                : null,
            color: selected
                ? null
                : NotesTheme.textPrimary.withValues(alpha: 0.08),
            border: Border.all(
              color: selected
                  ? NotesTheme.bronze.withValues(alpha: 0.55)
                  : NotesTheme.textPrimary.withValues(alpha: 0.12),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: NotesTheme.bronze.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 22.sp,
            color: selected
                ? NotesTheme.pureBlack
                : NotesTheme.textPrimary.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}
