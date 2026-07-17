import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared section header row that never overflows narrow tablet columns.
class HomeCategorySectionHeader extends StatelessWidget {
  const HomeCategorySectionHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    this.compact = false,
    this.iconGradient,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final bool compact;
  final Gradient? iconGradient;

  @override
  Widget build(BuildContext context) {
    // Tablet pane columns are narrow — ScreenUtil `.w`/`.sp` (scaled by the
    // full tablet screen width) would blow icon/text sizes far past the
    // pane, truncating the title to a couple of letters. Use fixed raw
    // pixel sizes there instead; phone keeps its normal ScreenUtil sizing.
    final isTablet = ResponsiveBreakpoints.useTabletLayout(context);

    final iconSize = isTablet ? 22.0 : (compact ? 24.w : 32.w);
    final iconGlyph = isTablet ? 12.0 : (compact ? 14.sp : 18.sp);
    final radius = isTablet ? 7.0 : (compact ? 8.r : 10.r);
    final gap = isTablet ? 6.0 : (compact ? 8.w : 10.w);
    final fontSize = isTablet ? 12.0 : (compact ? 12.sp : 16.sp);

    return Padding(
      padding: isTablet
          ? const EdgeInsets.only(left: 2, bottom: 4)
          : EdgeInsets.zero,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: iconGradient == null ? iconColor : null,
              gradient: iconGradient,
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.25),
                  blurRadius: compact ? 4 : 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: iconGlyph, color: Colors.white),
          ),
          SizedBox(width: gap),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A2A4F),
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
