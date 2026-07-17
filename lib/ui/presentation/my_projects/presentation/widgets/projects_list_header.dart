import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_cached_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Dashboard-style header for project listing / sub-screens (back + title block).
class ProjectsListHeader extends StatelessWidget {
  const ProjectsListHeader({
    super.key,
    required this.title,
    this.photoUrl,
    this.subtitle,
    this.onBack,
    this.onHome,
  });

  final String title;
  final String? photoUrl;
  final String? subtitle;
  final VoidCallback? onBack;
  final VoidCallback? onHome;

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('d MMMM, yyyy').format(DateTime.now());
    final displaySubtitle = subtitle?.trim().isNotEmpty == true
        ? subtitle!
        : dateLabel;

    return Padding(
      padding: EdgeInsets.fromLTRB(12.tw, 8.th, 16.tw, 10.th),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            onPressed: onBack ?? () => Navigator.maybePop(context),
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: ProjectsDashboardTheme.white,
              size: 20.tsp,
            ),
          ),
          if (photoUrl != null && photoUrl!.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(right: 10.tw),
              child: ClipOval(
                child: ProjectsCachedImage(
                  url: photoUrl!,
                  width: 48.tw,
                  height: 48.tw,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 20.tsp,
                    fontWeight: FontWeight.w700,
                    color: ProjectsDashboardTheme.white,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 2.th),
                Text(
                  displaySubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13.tsp,
                    color: ProjectsDashboardTheme.greyPanel.withValues(
                      alpha: 0.85,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (onHome != null)
            IconButton(
              tooltip: 'Projects home',
              onPressed: onHome,
              icon: Icon(
                Icons.home_rounded,
                color: ProjectsDashboardTheme.white,
                size: 26.tsp,
              ),
            ),
        ],
      ),
    );
  }
}
