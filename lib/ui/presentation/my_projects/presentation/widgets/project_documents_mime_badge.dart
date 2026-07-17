import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class ProjectDocumentsMimeBadge extends StatelessWidget {
  const ProjectDocumentsMimeBadge({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.tw, vertical: 3.th),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.tr),
        color: ProjectsDashboardTheme.greyDark.withValues(alpha: 0.12),
        border: Border.all(
          color: ProjectsDashboardTheme.greyDark.withValues(alpha: 0.28),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 9.tsp,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: ProjectsDashboardTheme.greyDeep,
        ),
      ),
    );
  }
}
