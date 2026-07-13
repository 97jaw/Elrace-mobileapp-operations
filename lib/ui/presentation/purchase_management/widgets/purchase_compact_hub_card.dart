import 'package:el_race/ui/presentation/purchase_management/utils/purchase_number_format.dart';
import 'package:el_race/ui/presentation/purchase_management/theme/purchase_theme.dart';
import 'package:el_race/ui/presentation/purchase_management/widgets/purchase_trend_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Compact square hub card (RFQ / MR) — reference: income/spending dashboard tiles.
class PurchaseCompactHubCard extends StatelessWidget {
  const PurchaseCompactHubCard({
    super.key,
    required this.title,
    required this.primaryValue,
    required this.valueColor,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.onTap,
    this.badge,
    this.trendLabel,
    this.trendPositive = true,
    this.subtitle,
  });

  final String title;
  final String primaryValue;
  final Color valueColor;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final VoidCallback onTap;
  final String? badge;
  final String? trendLabel;
  final bool trendPositive;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22.r),
        child: Ink(
          decoration: PurchaseTheme.glassCard(radius: 22.r),
          padding: EdgeInsets.fromLTRB(12.w, 10.h, 10.w, 8.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: PurchaseTheme.textPrimary,
                      ),
                    ),
                  ),
                  _ArrowButton(onTap: onTap, size: 26),
                ],
              ),
              SizedBox(height: 6.h),
              Container(
                width: 30.w,
                height: 30.w,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 16.sp),
              ),
              SizedBox(height: 10.h),
              Text(
                primaryValue,
                style: GoogleFonts.poppins(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w800,
                  color: valueColor,
                  height: 1,
                ),
              ),
              if (subtitle != null) ...[
                SizedBox(height: 2.h),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 8.5.sp,
                    fontWeight: FontWeight.w500,
                    color: PurchaseTheme.textMuted,
                  ),
                ),
              ],
              SizedBox(height: 4.h),
              Row(
                children: [
                  if (badge != null) PurchaseStatusPill(label: badge!),
                  if (badge != null && trendLabel != null) SizedBox(width: 4.w),
                  if (trendLabel != null)
                    Expanded(
                      child: PurchaseTrendBadge(
                        label: trendLabel!,
                        positive: trendPositive,
                        compact: true,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Slim horizontal LPO strip — reduced height vs full hero card.
class PurchaseCompactLpoStrip extends StatelessWidget {
  const PurchaseCompactLpoStrip({
    super.key,
    required this.totalCount,
    required this.onTap,
  });

  final int totalCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: Ink(
          height: 72.h,
          decoration: PurchaseTheme.glassCard(radius: 18.r),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          child: Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  color: PurchaseTheme.accentDeep.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  color: PurchaseTheme.accentDeep,
                  size: 18.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'LPOs',
                      style: GoogleFonts.poppins(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: PurchaseTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Confirmed purchase orders',
                      style: GoogleFonts.poppins(
                        fontSize: 9.sp,
                        color: PurchaseTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _LpoMetric(
                label: 'Total',
                value: totalCount,
                color: PurchaseTheme.accentBlue,
              ),
              SizedBox(width: 6.w),
              _ArrowButton(onTap: onTap, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _LpoMetric extends StatelessWidget {
  const _LpoMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 8.sp,
            fontWeight: FontWeight.w600,
            color: PurchaseTheme.textMuted,
          ),
        ),
        Text(
          formatPurchaseCompact(value),
          style: GoogleFonts.poppins(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: color,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.onTap, this.size = 30});

  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size.w,
        height: size.w,
        decoration: const BoxDecoration(
          color: PurchaseTheme.textPrimary,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.arrow_forward_rounded,
          color: Colors.white,
          size: (size * 0.5).sp,
        ),
      ),
    );
  }
}
