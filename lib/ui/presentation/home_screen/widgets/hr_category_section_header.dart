import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Human Resource section row — icon + title only.
class HrCategorySectionHeader extends StatelessWidget {
  const HrCategorySectionHeader({
    super.key,
    this.compact = false,
  });

  /// Peek state: smaller icon, short label to save vertical space for cards.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 24.w : 32.w;
    final iconGlyph = compact ? 14.sp : 18.sp;
    final radius = compact ? 8.r : 10.r;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            color: const Color(0xFFE63946),
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE63946).withValues(alpha: 0.25),
                blurRadius: compact ? 4 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.person_outline_rounded,
            size: iconGlyph,
            color: Colors.white,
          ),
        ),
        SizedBox(width: compact ? 8.w : 10.w),
        Text(
          'Human Resource',
          style: GoogleFonts.poppins(
            fontSize: compact ? 12.sp : 16.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A2A4F),
            height: 1.1,
          ),
        ),
      ],
    );
  }
}
