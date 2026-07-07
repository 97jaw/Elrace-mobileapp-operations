import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Footer shown at the end of a paginated project list.
class ProjectsListLoadMoreFooter extends StatelessWidget {
  const ProjectsListLoadMoreFooter({
    super.key,
    required this.loading,
    this.hint = 'Swipe up for more',
  });

  final bool loading;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Center(
        child: loading
            ? SizedBox(
                width: 28.w,
                height: 28.w,
                child: const CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: ProjectsDashboardTheme.white,
                ),
              )
            : Text(
                hint,
                style: GoogleFonts.poppins(
                  fontSize: 11.sp,
                  fontStyle: FontStyle.italic,
                  color: ProjectsDashboardTheme.greyPanel,
                ),
              ),
      ),
    );
  }
}
