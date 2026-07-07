import 'package:el_race/ui/presentation/my_projects/presentation/models/project_document_hub_kind.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/project_documents_breadcrumb.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_breadcrumb_sheet.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_kind_heading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Drill-down header: back, kind icon + title, path hierarchy button.
class ProjectDocumentsDrillHeader extends StatelessWidget {
  const ProjectDocumentsDrillHeader({
    super.key,
    required this.title,
    required this.breadcrumbs,
    this.kind,
    this.onBack,
  });

  final String title;
  final List<ProjectDocumentsBreadcrumb> breadcrumbs;
  final ProjectDocumentHubKind? kind;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 4.h, 8.w, 8.h),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18.sp,
              color: ProjectsDashboardTheme.white,
            ),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 38.w, minHeight: 38.w),
          ),
          Expanded(
            child: kind != null
                ? ProjectDocumentsKindHeading(
                    kind: kind!,
                    title: title,
                    iconSize: 28,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  )
                : Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: ProjectsDashboardTheme.white,
                      height: 1.15,
                    ),
                  ),
          ),
          if (breadcrumbs.length > 1)
            IconButton(
              onPressed: () => showProjectDocumentsBreadcrumbSheet(
                context,
                trail: breadcrumbs,
              ),
              tooltip: 'Path',
              icon: Icon(
                Icons.route_rounded,
                size: 22.sp,
                color: ProjectsDashboardTheme.white.withValues(alpha: 0.92),
              ),
              style: IconButton.styleFrom(
                backgroundColor: ProjectsDashboardTheme.navy.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                  side: BorderSide(
                    color: ProjectsDashboardTheme.white.withValues(alpha: 0.2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
