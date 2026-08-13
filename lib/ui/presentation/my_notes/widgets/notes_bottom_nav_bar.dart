import 'package:el_race/core/ui/adaptive_glass.dart';
import 'package:el_race/ui/presentation/my_notes/theme/notes_theme.dart';
import 'package:el_race/ui/presentation/my_notes/theme/notes_theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Floating pill: search field + theme toggle (replaces the old bottom nav).
class NotesFloatingSearchBar extends StatefulWidget {
  const NotesFloatingSearchBar({
    super.key,
    required this.onQueryChanged,
  });

  final ValueChanged<String> onQueryChanged;

  @override
  State<NotesFloatingSearchBar> createState() => _NotesFloatingSearchBarState();
}

class _NotesFloatingSearchBarState extends State<NotesFloatingSearchBar> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    widget.onQueryChanged(value);
    setState(() {});
  }

  void _clear() {
    _controller.clear();
    widget.onQueryChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
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
            padding: EdgeInsets.fromLTRB(14.w, 8.h, 8.w, 8.h),
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
                Icon(
                  Icons.search_rounded,
                  size: 22.sp,
                  color: NotesTheme.textPrimary.withValues(alpha: 0.5),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    onChanged: _onChanged,
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: NotesTheme.textPrimary,
                    ),
                    cursorColor: NotesTheme.bronze,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Search notes',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: NotesTheme.textPrimary.withValues(alpha: 0.4),
                      ),
                      contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                    ),
                  ),
                ),
                if (_controller.text.isNotEmpty)
                  IconButton(
                    onPressed: _clear,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints.tightFor(
                      width: 36.w,
                      height: 36.w,
                    ),
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18.sp,
                      color: NotesTheme.textPrimary.withValues(alpha: 0.45),
                    ),
                  ),
                SizedBox(width: 4.w),
                _ThemeToggleButton(
                  onTap: () => NotesThemeController.instance.toggle(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44.w,
          height: 44.w,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: NotesTheme.textPrimary.withValues(alpha: 0.08),
            border: Border.all(
              color: NotesTheme.textPrimary.withValues(alpha: 0.12),
            ),
          ),
          child: Icon(
            NotesTheme.isLight
                ? Icons.dark_mode_outlined
                : Icons.light_mode_outlined,
            size: 22.sp,
            color: NotesTheme.textPrimary.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
