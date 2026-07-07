import 'package:el_race/ui/presentation/my_projects/presentation/models/project_document_hub_kind.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/project_documents_mime_utils.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_kind_badge.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_kind_heading.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_marquee_title.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_mime_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared light-tile decoration for DMS file rows (dashboard + sub-screens).
BoxDecoration projectDocumentsFileRowDecoration() => BoxDecoration(
      borderRadius: BorderRadius.circular(16.r),
      gradient: LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          ProjectsDashboardTheme.white.withValues(alpha: 0.78),
          ProjectsDashboardTheme.greyPanel.withValues(alpha: 0.58),
          ProjectsDashboardTheme.greyLight.withValues(alpha: 0.42),
        ],
      ),
      border: Border.all(
        color: ProjectsDashboardTheme.white.withValues(alpha: 0.62),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );

TextStyle projectDocumentsUpdatedMetaStyle() => GoogleFonts.poppins(
      fontSize: 10.sp,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w500,
      color: ProjectsDashboardTheme.greyDeep,
      height: 1.2,
    );

/// Full-width file row — same design on dashboard recent files and sub-screen lists.
class ProjectDocumentsFileRow extends StatelessWidget {
  const ProjectDocumentsFileRow({
    super.key,
    required this.fileName,
    required this.onTap,
    this.subtitle,
    this.updatedLabel,
    this.kind,
    this.showChevron = true,
  });

  final String fileName;
  final String? subtitle;
  final String? updatedLabel;
  final ProjectDocumentHubKind? kind;
  final VoidCallback onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final mime = mimeLabelFromFileName(fileName);
    final updated = updatedLabel?.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          decoration: projectDocumentsFileRowDecoration(),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ProjectDocumentsIcons.image(isFile: true, size: 46),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProjectDocumentsOneLineMarquee(
                      text: fileName,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: ProjectsDashboardTheme.greyDeep,
                      lineHeight: 1.2,
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      SizedBox(height: 3.h),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 10.sp,
                          color: ProjectsDashboardTheme.greyDark
                              .withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                    SizedBox(height: 3.h),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (updated != null && updated.isNotEmpty)
                          Expanded(
                            child: Text(
                              updated,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: projectDocumentsUpdatedMetaStyle(),
                            ),
                          )
                        else
                          const Spacer(),
                        if (kind != null) ...[
                          ProjectDocumentsKindBadge(kind: kind!),
                          SizedBox(width: 6.w),
                        ],
                        ProjectDocumentsMimeBadge(label: mime),
                      ],
                    ),
                  ],
                ),
              ),
              if (showChevron)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22.sp,
                  color: ProjectsDashboardTheme.greyDark.withValues(alpha: 0.55),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
