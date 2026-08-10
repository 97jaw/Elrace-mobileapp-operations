import 'package:el_race/core/ui/adaptive_glass.dart';
import 'package:el_race/ui/presentation/my_notes/theme/notes_theme.dart';
import 'package:el_race/ui/presentation/my_notes/theme/notes_theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

enum NotesBottomNavTab {
  home,
  list,
  shared,
}

/// Floating pill bottom bar: Home · List · FAB create · Shared · Theme.
class NotesBottomNavBar extends StatelessWidget {
  const NotesBottomNavBar({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.onCreateTap,
  });

  final NotesBottomNavTab selected;
  final ValueChanged<NotesBottomNavTab> onSelected;
  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    // Rebuild the whole bar (not only the icon) when Dark/Light flips.
    return ListenableBuilder(
      listenable: NotesThemeController.instance,
      builder: (context, _) {
        final radius = BorderRadius.circular(999);

        return AdaptiveGlassLayer(
          borderRadius: radius,
          sigma: 18,
          fallbackColor: NotesTheme.isLight
              ? NotesTheme.surface.withValues(alpha: 0.95)
              : NotesTheme.charcoal.withValues(alpha: 0.92),
          fallbackBorder: Border.all(
            color: NotesTheme.bronze.withValues(alpha: 0.28),
          ),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: NotesTheme.bronze.withValues(alpha: 0.28),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: NotesTheme.isLight
                    ? [
                        NotesTheme.surface.withValues(alpha: 0.95),
                        NotesTheme.charcoal.withValues(alpha: 0.55),
                        NotesTheme.bronze.withValues(alpha: 0.12),
                      ]
                    : [
                        NotesTheme.charcoal.withValues(alpha: 0.72),
                        NotesTheme.pureBlack.withValues(alpha: 0.78),
                        NotesTheme.bronze.withValues(alpha: 0.18),
                      ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withValues(alpha: NotesTheme.isLight ? 0.12 : 0.45),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _NavItem(
                    icon: Icons.home_rounded,
                    selected: selected == NotesBottomNavTab.home,
                    onTap: () => onSelected(NotesBottomNavTab.home),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.notes_rounded,
                    selected: selected == NotesBottomNavTab.list,
                    onTap: () => onSelected(NotesBottomNavTab.list),
                  ),
                ),
                Expanded(child: _CreateFab(onTap: onCreateTap)),
                Expanded(
                  child: _NavItem(
                    icon: Icons.person_outline_rounded,
                    selected: selected == NotesBottomNavTab.shared,
                    onTap: () => onSelected(NotesBottomNavTab.shared),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: NotesTheme.isLight
                        ? Icons.dark_mode_outlined
                        : Icons.light_mode_outlined,
                    selected: false,
                    onTap: () => NotesThemeController.instance.toggle(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CreateFab extends StatelessWidget {
  const _CreateFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 54.w,
            height: 54.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  NotesTheme.bronze,
                  NotesTheme.bronze.withValues(alpha: 0.75),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: NotesTheme.bronze.withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Icon(
              Icons.add_rounded,
              size: 28.sp,
              color: NotesTheme.isLight
                  ? const Color(0xFF2C3E50)
                  : NotesTheme.pureBlack,
            ),
          ),
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
          width: 44.w,
          height: 44.w,
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
                ? (NotesTheme.isLight
                    ? const Color(0xFF2C3E50)
                    : NotesTheme.pureBlack)
                : NotesTheme.textPrimary.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}
