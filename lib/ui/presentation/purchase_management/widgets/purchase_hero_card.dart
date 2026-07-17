import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/purchase_management/theme/purchase_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class PurchaseHeroMetric {
  const PurchaseHeroMetric({required this.label, required this.value});
  final String label;
  final String value;
}

class PurchaseHeroCard extends StatelessWidget {
  const PurchaseHeroCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.metrics,
    required this.onTap,
    this.gradient = PurchaseTheme.heroGradient,
    this.borderColor,
    this.icon = Icons.chevron_right_rounded,
  });

  final String title;
  final String subtitle;
  final List<PurchaseHeroMetric> metrics;
  final VoidCallback onTap;
  final Gradient gradient;
  final Color? borderColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.tr),
        child: Ink(
          decoration: PurchaseTheme.glassCard(radius: 20.tr).copyWith(
            gradient: gradient,
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: 0.9),
              width: 1.2,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(18.tw),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 16.tsp,
                          fontWeight: FontWeight.w700,
                          color: PurchaseTheme.textPrimary,
                        ),
                      ),
                    ),
                    Icon(icon, color: PurchaseTheme.textMuted, size: 22.tsp),
                  ],
                ),
                SizedBox(height: 4.th),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 11.tsp,
                    fontWeight: FontWeight.w400,
                    color: PurchaseTheme.textSecondary,
                  ),
                ),
                SizedBox(height: 16.th),
                Row(
                  children: [
                    for (var i = 0; i < metrics.length; i++) ...[
                      if (i > 0) SizedBox(width: 24.tw),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              metrics[i].label,
                              style: GoogleFonts.poppins(
                                fontSize: 10.tsp,
                                fontWeight: FontWeight.w500,
                                color: PurchaseTheme.textMuted,
                              ),
                            ),
                            SizedBox(height: 4.th),
                            Text(
                              metrics[i].value,
                              style: GoogleFonts.poppins(
                                fontSize: 22.tsp,
                                fontWeight: FontWeight.w800,
                                color: PurchaseTheme.accentDeep,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
