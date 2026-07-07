import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Library section row — icon + title.
class LibraryCategorySectionHeader extends StatelessWidget {
  const LibraryCategorySectionHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 32.w,
          height: 32.w,
          decoration: BoxDecoration(
            color: const Color(0xFF6B7A94),
            borderRadius: BorderRadius.circular(10.r),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6B7A94).withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.folder_copy_outlined,
            size: 18.sp,
            color: Colors.white,
          ),
        ),
        SizedBox(width: 10.w),
        Text(
          'Library',
          style: GoogleFonts.poppins(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A2A4F),
            height: 1.1,
          ),
        ),
      ],
    );
  }
}
