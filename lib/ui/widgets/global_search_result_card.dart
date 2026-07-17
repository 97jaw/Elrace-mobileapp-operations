import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_theme.dart';
import 'package:el_race/ui/widgets/global_search_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Detail field with small icon + label/value layout.
class GlobalSearchDetailLine {
  const GlobalSearchDetailLine({
    required this.icon,
    required this.text,
    this.label,
    this.iconColor,
  });

  final IconData icon;
  final String text;
  final String? label;
  final Color? iconColor;
}

/// Faded glass card with large watermark icon (no photos).
class GlobalSearchGlassCard extends StatelessWidget {
  const GlobalSearchGlassCard({
    super.key,
    required this.category,
    required this.onTap,
    required this.title,
    this.subtitle,
    this.detailLines = const [],
    this.trailing,
    this.footer,
    this.accentColor,
    this.compact = false,
  });

  final String category;
  final VoidCallback onTap;
  final Widget title;
  final String? subtitle;
  final List<GlobalSearchDetailLine> detailLines;
  final Widget? trailing;
  final Widget? footer;
  final Color? accentColor;

  /// Horizontal carousel preview — title + optional subtitle only.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? GlobalSearchTheme.accentFor(category);
    final bgIcon = GlobalSearchTheme.iconFor(category);

    final watermarkSize = compact ? 72.tsp : 120.tsp;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6.tw : 14.tw,
        vertical: 5.th,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.tr),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.tr),
            child: BackdropFilter(
              filter: HomeGlassTheme.glassBlur,
              child: Container(
                width: double.infinity,
                height: compact ? double.infinity : null,
                decoration: BoxDecoration(
                  color: GlobalSearchTheme.cardFillFor(category),
                  borderRadius: BorderRadius.circular(16.tr),
                  border: Border.all(
                    color: GlobalSearchTheme.cardBorderFor(category),
                    width: 1,
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned(
                      right: -8.tw,
                      bottom: compact ? -20.th : -12.th,
                      child: IgnorePointer(
                        child: Icon(
                          bgIcon,
                          size: watermarkSize,
                          color: GlobalSearchTheme.watermarkIconFor(category),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 10.tw : 14.tw,
                        compact ? 10.th : 12.th,
                        compact ? 8.tw : 12.tw,
                        compact ? 10.th : 12.th,
                      ),
                      child: compact
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _headerRow(accent, showChevron: false),
                                if (subtitle != null &&
                                    subtitle!.isNotEmpty) ...[
                                  SizedBox(height: 6.th),
                                  Text(
                                    subtitle!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 10.5.tsp,
                                      fontWeight: FontWeight.w500,
                                      color: GlobalSearchTheme.cardSubtitle,
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _headerRow(accent),
                                if (subtitle != null &&
                                    subtitle!.isNotEmpty) ...[
                                  SizedBox(height: 6.th),
                                  _subtitleChip(subtitle!, accent),
                                ],
                                if (detailLines.isNotEmpty) ...[
                                  SizedBox(height: 10.th),
                                  Container(
                                    height: 1,
                                    color: GlobalSearchTheme.white
                                        .withValues(alpha: 0.12),
                                  ),
                                  SizedBox(height: 10.th),
                                  _detailsGrid(),
                                ],
                                if (footer != null) ...[
                                  SizedBox(height: 8.th),
                                  footer!,
                                ],
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerRow(Color accent, {bool showChevron = true}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _categoryIconTile(accent, compact: compact),
        SizedBox(width: compact ? 8.tw : 10.tw),
        Expanded(
          child: DefaultTextStyle(
            style: GoogleFonts.poppins(
              fontSize: compact ? 13.tsp : 15.tsp,
              fontWeight: FontWeight.w700,
              color: GlobalSearchTheme.cardTitle,
              height: 1.2,
            ),
            maxLines: compact ? 2 : 2,
            overflow: TextOverflow.ellipsis,
            child: title,
          ),
        ),
        if (trailing != null) ...[
          SizedBox(width: 8.tw),
          trailing!,
        ],
        if (showChevron)
          GlobalSearchTrailingChevron(color: GlobalSearchTheme.white),
      ],
    );
  }

  Widget _categoryIconTile(Color accent, {bool compact = false}) {
    final size = compact ? 32.tw : 40.tw;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10.tr),
        border: Border.all(
          color: GlobalSearchTheme.white.withValues(alpha: 0.35),
        ),
      ),
      child: Icon(
        GlobalSearchTheme.iconFor(category),
        color: GlobalSearchTheme.white,
        size: compact ? 18.tsp : 22.tsp,
      ),
    );
  }

  Widget _subtitleChip(String text, Color accent) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.tw, vertical: 4.th),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8.tr),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: 11.tsp,
            fontWeight: FontWeight.w600,
            color: GlobalSearchTheme.cardSubtitle,
          ),
        ),
      ),
    );
  }

  Widget _detailsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCol = constraints.maxWidth > 280.tw;
        if (!twoCol || detailLines.length == 1) {
          return Column(
            children: detailLines
                .asMap()
                .entries
                .map((e) => _detailCell(e.value, e.key))
                .toList(),
          );
        }
        final rows = <Widget>[];
        for (var i = 0; i < detailLines.length; i += 2) {
          final left = detailLines[i];
          final right =
              i + 1 < detailLines.length ? detailLines[i + 1] : null;
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _detailCell(left, i)),
                if (right != null) ...[
                  SizedBox(width: 10.tw),
                  Expanded(child: _detailCell(right, i + 1)),
                ],
              ],
            ),
          );
          if (i + 2 < detailLines.length) {
            rows.add(SizedBox(height: 8.th));
          }
        }
        return Column(children: rows);
      },
    );
  }

  Color _detailLabelColor(Color iconColor) {
    // Keep grey categories readable on glass.
    if (iconColor == GlobalSearchTheme.grey ||
        iconColor == GlobalSearchTheme.greyLight) {
      return const Color(0xFFCBD5E1);
    }
    return iconColor;
  }

  Widget _detailCell(GlobalSearchDetailLine line, int index) {
    final iconColor =
        line.iconColor ?? GlobalSearchTheme.detailIconColor(category, index: index);
    final labelColor = _detailLabelColor(iconColor);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(line.icon, size: 15.tsp, color: iconColor),
        SizedBox(width: 6.tw),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (line.label != null && line.label!.isNotEmpty)
                Text(
                  line.label!,
                  style: GoogleFonts.poppins(
                    fontSize: 10.tsp,
                    fontWeight: FontWeight.w700,
                    color: labelColor,
                    height: 1.2,
                  ),
                ),
              Text(
                line.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 11.5.tsp,
                  fontWeight: FontWeight.w500,
                  color: GlobalSearchTheme.cardDetailValue,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class GlobalSearchAmountLabel extends StatelessWidget {
  const GlobalSearchAmountLabel({
    super.key,
    required this.amount,
    this.color,
    this.suffix = 'AED',
  });

  final String amount;
  final Color? color;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    if (amount.isEmpty) return const SizedBox.shrink();
    final c = color ?? GlobalSearchTheme.greenBright;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          amount,
          style: GoogleFonts.poppins(
            fontSize: 15.tsp,
            fontWeight: FontWeight.w800,
            color: c,
            height: 1,
          ),
        ),
        Text(
          suffix,
          style: GoogleFonts.poppins(
            fontSize: 9.tsp,
            fontWeight: FontWeight.w600,
            color: GlobalSearchTheme.cardMeta,
          ),
        ),
      ],
    );
  }
}

class GlobalSearchStatusPill extends StatelessWidget {
  const GlobalSearchStatusPill({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: 88.tw),
      padding: EdgeInsets.symmetric(horizontal: 8.tw, vertical: 4.th),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8.tr),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
        style: GoogleFonts.poppins(
          fontSize: 9.tsp,
          fontWeight: FontWeight.w700,
          color: GlobalSearchTheme.white,
        ),
      ),
    );
  }
}

class GlobalSearchTrailingChevron extends StatelessWidget {
  const GlobalSearchTrailingChevron({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.chevron_right_rounded,
      color: color.withValues(alpha: 0.7),
      size: 22.tsp,
    );
  }
}
