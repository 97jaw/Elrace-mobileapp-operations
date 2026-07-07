import 'package:el_race/ui/presentation/productivity/theme/productivity_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class MyDocumentsTabItem {
  const MyDocumentsTabItem({
    required this.label,
    required this.icon,
    this.iconSelected,
  });

  final String label;
  final IconData icon;
  final IconData? iconSelected;
}

/// Glass segmented tabs for My Documents module.
class MyDocumentsTabBar extends StatelessWidget {
  const MyDocumentsTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<MyDocumentsTabItem> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      child: Container(
        height: 44.h,
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.92)),
          boxShadow: [
            BoxShadow(
              color: ProductivityTheme.accentBlue.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++) ...[
              if (i > 0) SizedBox(width: 4.w),
              Expanded(
                child: _TabChip(
                  label: tabs[i].label,
                  icon: tabs[i].icon,
                  iconSelected: tabs[i].iconSelected ?? tabs[i].icon,
                  selected: selectedIndex == i,
                  onTap: () => onChanged(i),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.icon,
    required this.iconSelected,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData iconSelected;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ProductivityTheme.accentBlue,
                    ProductivityTheme.accentDeep,
                  ],
                )
              : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? iconSelected : icon,
              size: 15.sp,
              color: selected ? Colors.white : ProductivityTheme.textSecondary,
            ),
            SizedBox(width: 5.w),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 10.sp,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : ProductivityTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
