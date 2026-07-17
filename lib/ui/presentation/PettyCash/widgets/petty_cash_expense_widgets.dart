import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/PettyCash/theme/petty_cash_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class PettyCashActionChip extends StatelessWidget {
  const PettyCashActionChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.tr),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.th),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50.tw,
                  height: 50.tw,
                  decoration: BoxDecoration(
                    color: PettyCashTheme.iconCircleBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: PettyCashTheme.glassBorder),
                  ),
                  child: Icon(
                    icon,
                    color: PettyCashTheme.white,
                    size: 22.tsp,
                  ),
                ),
                SizedBox(height: 8.th),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11.tsp,
                    fontWeight: FontWeight.w600,
                    color: PettyCashTheme.textSecondary,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PettyCashExpenseTile extends StatelessWidget {
  const PettyCashExpenseTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.icon = Icons.receipt_long_rounded,
    this.amountColor,
    this.trailing,
    this.onTap,
    this.highlight = false,
  });

  final String title;
  final String subtitle;
  final String amount;
  final IconData icon;
  final Color? amountColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlight
          ? PettyCashTheme.mint.withValues(alpha: 0.12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(14.tr),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.tr),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12.th, horizontal: 4.tw),
          child: Row(
            children: [
              Container(
                width: 46.tw,
                height: 46.tw,
                decoration: BoxDecoration(
                  color: PettyCashTheme.iconCircleBg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: highlight
                        ? PettyCashTheme.mint.withValues(alpha: 0.35)
                        : PettyCashTheme.glassBorder,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 20.tsp,
                  color: highlight
                      ? PettyCashTheme.mint
                      : PettyCashTheme.textSecondary,
                ),
              ),
              SizedBox(width: 12.tw),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14.tsp,
                        fontWeight: FontWeight.w700,
                        color: PettyCashTheme.white,
                      ),
                    ),
                    SizedBox(height: 2.th),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11.tsp,
                        fontWeight: FontWeight.w500,
                        color: PettyCashTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.tw),
              Text(
                amount,
                style: GoogleFonts.poppins(
                  fontSize: 14.tsp,
                  fontWeight: FontWeight.w700,
                  color: amountColor ?? PettyCashTheme.white,
                ),
              ),
              if (trailing != null) ...[
                SizedBox(width: 6.tw),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
