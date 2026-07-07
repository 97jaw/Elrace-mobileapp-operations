import 'package:el_race/ui/presentation/attendance_checkin/models/checkin_context_model.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class CheckinProjectCarousel extends StatelessWidget {
  const CheckinProjectCarousel({
    super.key,
    required this.projects,
    required this.selectedProjectId,
    required this.onProjectSelected,
  });

  final List<CheckinAllowedProject> projects;
  final int? selectedProjectId;
  final ValueChanged<CheckinAllowedProject> onProjectSelected;

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: Text(
          'No assigned projects with location coordinates.',
          style: GoogleFonts.poppins(
            fontSize: 12.sp,
            color: HomeGlassTheme.textSecondary,
          ),
        ),
      );
    }

    return SizedBox(
      height: 72.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: projects.length,
        separatorBuilder: (_, __) => SizedBox(width: 10.w),
        itemBuilder: (context, index) {
          final project = projects[index];
          final selected = project.projectId == selectedProjectId;
          return _ProjectChip(
            project: project,
            selected: selected,
            onTap: () => onProjectSelected(project),
          );
        },
      ),
    );
  }
}

class _ProjectChip extends StatelessWidget {
  const _ProjectChip({
    required this.project,
    required this.selected,
    required this.onTap,
  });

  final CheckinAllowedProject project;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          width: 168.w,
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.r),
            color: selected
                ? HomeGlassTheme.maroon.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.85),
            border: Border.all(
              color: selected
                  ? HomeGlassTheme.maroon
                  : Colors.white.withValues(alpha: 0.6),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                project.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: HomeGlassTheme.textPrimary,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                project.woRefNo.isNotEmpty
                    ? project.woRefNo
                    : project.accessType.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 10.sp,
                  color: HomeGlassTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
