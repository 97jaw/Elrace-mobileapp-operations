import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/Email%20Approval/theme/approvals_overview_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Data for one stat counter card.
class StatCounterCardData {
  const StatCounterCardData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.backgroundColor,
    required this.route,
    this.value,
    this.isLoading = false,
    this.hasError = false,
    this.onTap,
    this.onRetry,
  });

  final String id;
  final String title;
  final String subtitle;
  final Color backgroundColor;
  final String route;
  final int? value;
  final bool isLoading;
  final bool hasError;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;
}

/// Single stat counter card — glassmorphism + presentational only.
class StatCounterCard extends StatelessWidget {
  const StatCounterCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.backgroundColor,
    this.categoryId,
    this.value,
    this.isLoading = false,
    this.hasError = false,
    this.onTap,
    this.onRetry,
    this.expand = false,
    this.tileHeight = StatCounterCard.defaultTileHeight,
  });

  final String title;
  final String subtitle;
  final Color backgroundColor;
  final String? categoryId;
  final int? value;
  final bool isLoading;
  final bool hasError;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;
  final bool expand;
  final double tileHeight;

  static const Color _buttonColor = Color(0xFF1A1A1A);
  static const double defaultTileHeight = 172;

  @override
  Widget build(BuildContext context) {
    final gradient = ApprovalsOverviewTheme.statCardGradient(backgroundColor);
    final accentText =
        ApprovalsOverviewTheme.statCardAccentText(backgroundColor);
    final illustrationAsset = categoryId != null
        ? ApprovalsOverviewTheme.statCardBackgroundImage(categoryId!)
        : null;
    final illustrationTint = categoryId != null
        ? ApprovalsOverviewTheme.statCardIllustrationTint(categoryId!)
        : accentText;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22.tr),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: hasError ? onRetry : onTap,
          child: Ink(
            width: expand ? double.infinity : 170.tw,
            height: tileHeight.th,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(22.tr),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.72),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: backgroundColor.withValues(alpha: 0.22),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (illustrationAsset != null)
                  Positioned(
                    right: 4.tw,
                    bottom: 8.th,
                    child: _StatCardBackgroundIllustration(
                      assetPath: illustrationAsset,
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.all(14.tw),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 13.tsp,
                          fontWeight: FontWeight.w700,
                          color: ApprovalsOverviewTheme.textDark,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 4.th),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 7.tw,
                          vertical: 2.th,
                        ),
                        decoration: BoxDecoration(
                          color: illustrationTint.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6.tr),
                          border: Border.all(
                            color: illustrationTint.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 10.tsp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: illustrationTint,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(child: _buildValueArea(accentText)),
                          _StatCounterArrowButton(
                            onTap: hasError ? onRetry : onTap,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildValueArea(Color accentText) {
    if (isLoading) {
      return Container(
        width: 44.tw,
        height: 24.th,
        decoration: BoxDecoration(
          color: ApprovalsOverviewTheme.textDark.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8.tr),
        ),
      );
    }

    if (hasError) {
      return GestureDetector(
        onTap: onRetry,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '--',
              style: GoogleFonts.poppins(
                fontSize: 30.tsp,
                fontWeight: FontWeight.w700,
                color: ApprovalsOverviewTheme.textSoft,
                height: 1,
              ),
            ),
            SizedBox(width: 4.tw),
            Icon(
              Icons.refresh_rounded,
              size: 16.tsp,
              color: ApprovalsOverviewTheme.textMuted,
            ),
          ],
        ),
      );
    }

    return Text(
      '${value ?? 0}',
      style: GoogleFonts.poppins(
        fontSize: 32.tsp,
        fontWeight: FontWeight.w800,
        color: ApprovalsOverviewTheme.textDark,
        height: 1,
        letterSpacing: -0.5,
      ),
    );
  }
}

class _StatCardBackgroundIllustration extends StatelessWidget {
  const _StatCardBackgroundIllustration({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.12,
        child: Image.asset(
          assetPath,
          width: 68.tw,
          height: 68.tw,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          isAntiAlias: true,
        ),
      ),
    );
  }
}

class _StatCounterArrowButton extends StatelessWidget {
  const _StatCounterArrowButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 34.tw,
        height: 34.tw,
        decoration: const BoxDecoration(
          color: StatCounterCard._buttonColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.north_east_rounded,
          size: 15.tsp,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// 2×2 grid of stat counter cards.
class StatCounterGrid extends StatelessWidget {
  const StatCounterGrid({
    super.key,
    required this.cards,
    this.horizontalPadding = 0,
    this.gap = kTileGap,
    this.tileHeight = kTileHeight,
  });

  static const double kTileHeight = StatCounterCard.defaultTileHeight;
  static const double kTileGap = 8;

  static double gridHeight({double? tileHeight, double? gap}) =>
      (tileHeight ?? kTileHeight).th * 2 + (gap ?? kTileGap).th;

  final List<StatCounterCardData> cards;
  final double horizontalPadding;
  final double gap;
  final double tileHeight;

  Widget _buildCard(StatCounterCardData card) {
    return StatCounterCard(
      expand: true,
      tileHeight: tileHeight,
      title: card.title,
      subtitle: card.subtitle,
      backgroundColor: card.backgroundColor,
      categoryId: card.id,
      value: card.value,
      isLoading: card.isLoading,
      hasError: card.hasError,
      onTap: card.onTap,
      onRetry: card.onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(cards.length == 4, 'StatCounterGrid expects exactly 4 cards');

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding.tw),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildCard(cards[0])),
              SizedBox(width: gap.tw),
              Expanded(child: _buildCard(cards[1])),
            ],
          ),
          SizedBox(height: gap.th),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildCard(cards[2])),
              SizedBox(width: gap.tw),
              Expanded(child: _buildCard(cards[3])),
            ],
          ),
        ],
      ),
    );
  }
}

/// Segmented Waiting / ROR tab bar.
class OverviewSegmentedTabs extends StatelessWidget {
  const OverviewSegmentedTabs({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42.th,
      padding: EdgeInsets.all(4.tw),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          _TabChip(
            label: 'Waiting',
            selected: selectedIndex == 0,
            onTap: () => onChanged(0),
          ),
          _TabChip(
            label: 'ROR',
            selected: selectedIndex == 1,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? ApprovalsOverviewTheme.screenDeep.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13.tsp,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? ApprovalsOverviewTheme.screenDeep
                  : ApprovalsOverviewTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
