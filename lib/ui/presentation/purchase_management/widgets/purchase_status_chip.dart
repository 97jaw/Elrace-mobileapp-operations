import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Small coloured pill used to display purchase state labels.
class PurchaseStatusChip extends StatelessWidget {
  const PurchaseStatusChip({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.tw, vertical: 3.th),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8.tr),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 0.8),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 9.5.tsp,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
