import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class DrawingStudioStatusChip extends StatelessWidget {
  const DrawingStudioStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final lower = status.toLowerCase();
    late Color bg;
    late Color fg;
    if (lower == 'completed') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF166534);
    } else if (lower == 'failed') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFF991B1B);
    } else {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.uh),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: GoogleFonts.poppins(
          fontSize: 11.usp,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
