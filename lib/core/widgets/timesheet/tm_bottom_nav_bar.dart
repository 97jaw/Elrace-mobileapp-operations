import 'package:el_race/core/theme/timesheet_module_theme.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class TmBottomNavItem {
  const TmBottomNavItem({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;
}

class TmBottomNavBar extends StatelessWidget {
  const TmBottomNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onItemTap,
    required this.onFabTap,
    this.dark = true,
    this.fabIcon,
  }) : assert(
          items.length == 2 || items.length == 4,
          'Use 2 items (Home/Tasks + center action) or 4 for detail screens.',
        );

  final List<TmBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onItemTap;
  final VoidCallback onFabTap;
  final bool dark;
  final IconData? fabIcon;

  bool get _compact => items.length == 2;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: TimesheetModuleLayout.bottomNavHeight + 18,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            height: TimesheetModuleLayout.bottomNavHeight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: dark ? null : TimesheetModuleColors.surface,
              gradient: dark
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF284D7D),
                        Color(0xFFA9364B),
                        Color(0xFF5D1522),
                      ],
                    )
                  : null,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              boxShadow: TimesheetModuleShadows.cardShadow,
            ),
            child: _compact ? _compactRow() : _expandedRow(),
          ),
          Positioned(
            top: 0,
            child: GestureDetector(
              onTap: onFabTap,
              child: Container(
                width: TimesheetModuleLayout.bottomNavFabSize,
                height: TimesheetModuleLayout.bottomNavFabSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dark ? TimesheetModuleColors.surface : null,
                  gradient: dark ? null : TimesheetModuleColors.primaryGradient,
                  border: dark
                      ? Border.all(
                          color: TimesheetModuleColors.primary,
                          width: 2,
                        )
                      : null,
                  boxShadow: TimesheetModuleShadows.fabShadow,
                ),
                child: Icon(
                  fabIcon ?? PhosphorIcons.fileText(),
                  color: dark
                      ? TimesheetModuleColors.primary
                      : TimesheetModuleColors.surface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactRow() {
    return Row(
      children: [
        Expanded(child: _NavItem(index: 0, bar: this)),
        const SizedBox(width: TimesheetModuleLayout.bottomNavFabSize),
        Expanded(child: _NavItem(index: 1, bar: this)),
      ],
    );
  }

  Widget _expandedRow() {
    return Row(
      children: [
        Expanded(child: _NavItem(index: 0, bar: this)),
        Expanded(child: _NavItem(index: 1, bar: this)),
        const SizedBox(width: TimesheetModuleLayout.bottomNavFabSize),
        Expanded(child: _NavItem(index: 2, bar: this)),
        Expanded(child: _NavItem(index: 3, bar: this)),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.bar,
  });

  final int index;
  final TmBottomNavBar bar;

  @override
  Widget build(BuildContext context) {
    final item = bar.items[index];
    final active = bar.currentIndex == index;
    final color = bar.dark
        ? (active
            ? TimesheetModuleColors.surface
            : TimesheetModuleColors.surface.withValues(alpha: 0.62))
        : (active
            ? TimesheetModuleColors.primary
            : TimesheetModuleColors.mutedText);

    return InkWell(
      onTap: () => bar.onItemTap(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: TimesheetModuleTypography.caption().copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
