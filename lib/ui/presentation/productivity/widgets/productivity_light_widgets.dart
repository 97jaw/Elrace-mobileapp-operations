import 'package:el_race/ui/presentation/productivity/theme/productivity_light_theme.dart';
import 'package:el_race/ui/presentation/tasks_dashboard/models/task_filter.dart';
import 'package:flutter/material.dart';

class ProductivityStatItem {
  const ProductivityStatItem({
    required this.label,
    required this.value,
    required this.icon,
    this.accent = ProductivityLightTheme.accentTotal,
    this.sparkHighlightStart = 3,
    this.sparkHighlightEnd = 5,
    this.onTap,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color accent;
  final int sparkHighlightStart;
  final int sparkHighlightEnd;
  final VoidCallback? onTap;
}

/// Hero eyebrow + title used above the stats grid.
class ProductivityLightHero extends StatelessWidget {
  const ProductivityLightHero({
    super.key,
    required this.eyebrow,
    required this.title,
  });

  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow, style: ProductivityLightTheme.heroEyebrow),
          const SizedBox(height: 4),
          Text(title, style: ProductivityLightTheme.heroTitle),
        ],
      ),
    );
  }
}

/// 2x2 white stats cards — taller, radius 14, colored icon chips.
class ProductivityStatsGrid extends StatelessWidget {
  const ProductivityStatsGrid({
    super.key,
    required this.items,
  });

  final List<ProductivityStatItem> items;

  @override
  Widget build(BuildContext context) {
    assert(items.length == 4, 'Stats grid expects exactly 4 items');
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _StatCard(item: items[0])),
              const SizedBox(width: 14),
              Expanded(child: _StatCard(item: items[1])),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _StatCard(item: items[2])),
              const SizedBox(width: 14),
              Expanded(child: _StatCard(item: items[3])),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.item});

  final ProductivityStatItem item;

  @override
  Widget build(BuildContext context) {
    const radius = ProductivityLightTheme.boxRadius;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Ink(
          decoration: BoxDecoration(
            color: ProductivityLightTheme.card,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.045),
                blurRadius: 16,
                offset: const Offset(0, 6),
                spreadRadius: -2,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 14, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6, right: 8),
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ProductivityLightTheme.statLabel,
                        ),
                      ),
                    ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: item.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        item.icon,
                        size: 18,
                        color: item.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 36),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        '${item.value}',
                        style: ProductivityLightTheme.statValue,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: _MiniSparkline(
                        accent: item.accent,
                        highlightStart: item.sparkHighlightStart,
                        highlightEnd: item.sparkHighlightEnd,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniSparkline extends StatelessWidget {
  const _MiniSparkline({
    required this.accent,
    required this.highlightStart,
    required this.highlightEnd,
  });

  final Color accent;
  final int highlightStart;
  final int highlightEnd;

  static const _heights = [
    0.32,
    0.48,
    0.40,
    0.62,
    0.88,
    1.0,
    0.72,
    0.55,
    0.42,
    0.34,
  ];

  @override
  Widget build(BuildContext context) {
    const height = 30.0;
    return SizedBox(
      width: 52,
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < _heights.length; i++) ...[
            if (i > 0) const SizedBox(width: 2.2),
            Expanded(
              child: Container(
                height: height * _heights[i],
                decoration: BoxDecoration(
                  color: (i >= highlightStart && i <= highlightEnd)
                      ? accent
                      : ProductivityLightTheme.sparklineTrack,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Soft status badge — radius 8, black regular text.
class ProductivityStatusPill extends StatelessWidget {
  const ProductivityStatusPill({
    super.key,
    required this.label,
    required this.background,
    this.foreground = ProductivityLightTheme.ink,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: ProductivityLightTheme.statusPill.copyWith(color: foreground),
      ),
    );
  }
}

/// Horizontal All / Pending / Active / Ended chips + optional search toggle.
class ProductivityLightFilterBar extends StatelessWidget {
  const ProductivityLightFilterBar({
    super.key,
    required this.selected,
    required this.onChanged,
    this.onSearchTap,
    this.searchActive = false,
  });

  final TaskFilter selected;
  final ValueChanged<TaskFilter> onChanged;
  final VoidCallback? onSearchTap;
  final bool searchActive;

  static const _chips = <(TaskFilter, String)>[
    (TaskFilter.all, 'All'),
    (TaskFilter.pending, 'Pending'),
    (TaskFilter.inProgress, 'Active'),
    (TaskFilter.completed, 'Ended'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < _chips.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    _FilterChip(
                      label: _chips[i].$2,
                      selected: selected == _chips[i].$1,
                      onTap: () => onChanged(_chips[i].$1),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (onSearchTap != null)
            IconButton(
              tooltip: searchActive ? 'Hide search' : 'Search',
              onPressed: onSearchTap,
              icon: Icon(
                searchActive ? Icons.close_rounded : Icons.search_rounded,
                color: searchActive
                    ? ProductivityLightTheme.ink
                    : ProductivityLightTheme.inkSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? ProductivityLightTheme.ink
                : ProductivityLightTheme.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? ProductivityLightTheme.ink
                  : ProductivityLightTheme.border,
            ),
            boxShadow: selected
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Text(
            label,
            style: ProductivityLightTheme.cardSubtitle.copyWith(
              color: selected ? Colors.white : ProductivityLightTheme.ink,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// Search field shown under the filter bar when search is toggled on.
class ProductivityLightSearchField extends StatelessWidget {
  const ProductivityLightSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Search tasks…',
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        autofocus: true,
        style: ProductivityLightTheme.cardSubtitle.copyWith(
          color: ProductivityLightTheme.ink,
        ),
        cursorColor: ProductivityLightTheme.ink,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: ProductivityLightTheme.cardSubtitle,
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: ProductivityLightTheme.inkMuted,
            size: 20,
          ),
          filled: true,
          fillColor: ProductivityLightTheme.card,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: ProductivityLightTheme.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: ProductivityLightTheme.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: ProductivityLightTheme.ink),
          ),
        ),
      ),
    );
  }
}
