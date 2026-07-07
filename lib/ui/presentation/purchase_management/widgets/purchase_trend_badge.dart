import 'package:el_race/ui/presentation/purchase_management/theme/purchase_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Pill trend badge (+4.5% ↑ from last month style).
class PurchaseTrendBadge extends StatelessWidget {
  const PurchaseTrendBadge({
    super.key,
    required this.label,
    this.positive = true,
    this.compact = false,
  });

  final String label;
  final bool positive;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = positive ? const Color(0xFF16A34A) : const Color(0xFFDC6B4A);
    final bg = positive
        ? const Color(0xFFD1FAE5).withValues(alpha: 0.85)
        : const Color(0xFFFEE2E2).withValues(alpha: 0.85);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6.w : 8.w,
        vertical: compact ? 2.h : 3.h,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: compact ? 7.sp : 9.sp,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          if (!compact) ...[
            SizedBox(width: 4.w),
            Icon(
              positive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 10.sp,
              color: color,
            ),
          ],
        ],
      ),
    );
  }
}

/// Small status pill (PENDING, OPEN, etc.).
class PurchaseStatusPill extends StatelessWidget {
  const PurchaseStatusPill({
    super.key,
    required this.label,
    this.color,
    this.background,
  });

  final String label;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? PurchaseTheme.pendingBadge;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: background ?? fg.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: fg.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 8.sp,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
