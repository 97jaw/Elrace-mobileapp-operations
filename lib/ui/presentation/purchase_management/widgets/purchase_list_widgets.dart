import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/purchase_management/theme/purchase_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared search bar for Purchase Management list screens.
class PurchaseSearchBar extends StatelessWidget {
  const PurchaseSearchBar({
    super.key,
    required this.controller,
    this.hint = 'Search…',
    this.embedded = false,
  });

  final TextEditingController controller;
  final String hint;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final field = Container(
      height: 40.th,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(20.tr),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.95),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: PurchaseTheme.accentBlue.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.poppins(
          color: PurchaseTheme.textPrimary,
          fontSize: 13.tsp,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            color: PurchaseTheme.textMuted,
            fontSize: 13.tsp,
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 18.tsp,
            color: PurchaseTheme.accentBlue,
          ),
          border: InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(vertical: 10.th, horizontal: 12.tw),
        ),
      ),
    );

    if (embedded) return field;

    return Padding(
      padding: EdgeInsets.fromLTRB(14.tw, 10.th, 14.tw, 4.th),
      child: field,
    );
  }
}

/// Horizontal filter chip row for Purchase Management list screens.
class PurchaseFilterChips extends StatelessWidget {
  const PurchaseFilterChips({
    super.key,
    required this.filters,
    required this.labels,
    required this.selected,
    required this.onSelect,
    this.dense = false,
  });

  final List<String> filters;
  final List<String> labels;
  final String selected;
  final ValueChanged<String> onSelect;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: dense
          ? EdgeInsets.fromLTRB(14.tw, 0, 14.tw, 2.th)
          : EdgeInsets.fromLTRB(14.tw, 6.th, 14.tw, 4.th),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (var i = 0; i < filters.length; i++) ...[
              if (i > 0) SizedBox(width: 8.tw),
              _PurchaseFilterChip(
                label: labels[i],
                isSelected: filters[i] == selected,
                onTap: () => onSelect(filters[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PurchaseFilterChip extends StatelessWidget {
  const _PurchaseFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 16.tw, vertical: 8.th),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF1E4DB7), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? PurchaseTheme.accentBlue
                : PurchaseTheme.accentBlue.withValues(alpha: 0.22),
            width: isSelected ? 0 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: PurchaseTheme.accentBlue.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12.tsp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : PurchaseTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
