import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Compact header for group-by pickers and sub-screens (no greeting / user name).
class ProjectsSubScreenHeader extends StatelessWidget {
  const ProjectsSubScreenHeader({
    super.key,
    required this.title,
    this.onBack,
    this.onHome,
    this.showHome = true,
  });

  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onHome;
  final bool showHome;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 8.h, 12.w, 10.h),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack ?? () => Navigator.maybePop(context),
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: ProjectsDashboardTheme.white,
              size: 20.sp,
            ),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                color: ProjectsDashboardTheme.white,
                height: 1.2,
              ),
            ),
          ),
          if (showHome)
            IconButton(
              tooltip: 'Projects home',
              onPressed: onHome ?? () => Navigator.of(context).pop(),
              icon: Icon(
                Icons.home_rounded,
                color: ProjectsDashboardTheme.white,
                size: 26.sp,
              ),
            ),
        ],
      ),
    );
  }
}
