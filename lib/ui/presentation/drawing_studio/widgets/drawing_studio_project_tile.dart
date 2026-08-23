import 'package:el_race/core/drawing_studio/drawing_studio_project.dart';
import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/drawing_studio/widgets/drawing_studio_status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class DrawingStudioProjectTile extends StatelessWidget {
  const DrawingStudioProjectTile({
    super.key,
    required this.project,
    required this.onTap,
  });

  final DrawingStudioProject project;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = project.briefPreview?.trim().isNotEmpty == true
        ? project.briefPreview!
        : (project.createdAt == null
            ? project.status
            : DateFormat('d MMM yyyy').format(project.createdAt!.toLocal()));

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12.ur),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.ur),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.uh),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.ur),
            border: Border.all(color: const Color(0xFFE4E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.ur),
                  color: const Color(0xFFEEF2FF),
                ),
                child: Icon(
                  Icons.folder_outlined,
                  color: const Color(0xFF3E7BFA),
                  size: 20.usp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13.usp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A2A4F),
                      ),
                    ),
                    SizedBox(height: 2.uh),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11.usp,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF7A849C),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              DrawingStudioStatusChip(status: project.status),
              SizedBox(width: 4.w),
              Icon(
                Icons.chevron_right_rounded,
                color: const Color(0xFFB0BAC8),
                size: 22.usp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
