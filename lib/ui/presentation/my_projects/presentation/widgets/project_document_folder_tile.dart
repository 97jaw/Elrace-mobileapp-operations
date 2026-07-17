import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/models/project_document_hub_kind.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_section_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Full-width horizontal folder row for the documents hub list.
class ProjectDocumentFolderTile extends StatelessWidget {
  const ProjectDocumentFolderTile({
    super.key,
    required this.item,
    required this.onTap,
    this.compact = false,
  });

  final ProjectDocumentHubFolderItem item;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bottomLabel = item.projectCount > 0
        ? projectDocumentsCountLabel(
            item.projectCount,
            singular: item.kind == ProjectDocumentHubKind.cloud
                ? 'site'
                : 'project',
            plural: item.kind == ProjectDocumentHubKind.cloud
                ? 'sites'
                : 'projects',
          )
        : null;

    return ProjectDocumentsSectionTile(
      title: item.kind.title,
      kind: item.kind,
      fileCount: item.fileCount,
      iconSize: compact ? 48 : 54,
      lastUpdatedLabel: item.lastUpdatedLabel,
      updatedBy: item.updatedBy,
      bottomRightLabel: bottomLabel,
      onTap: onTap,
    );
  }
}

/// Reference-style section header: title + subtitle count + optional menu.
class ProjectDocumentSectionHeader extends StatelessWidget {
  const ProjectDocumentSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.onMoreTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onMoreTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.tw, 8.th, 4.tw, 8.th),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 15.tsp,
                    fontWeight: FontWeight.w600,
                    color: ProjectsDashboardTheme.white,
                  ),
                ),
                SizedBox(height: 2.th),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12.tsp,
                    color: ProjectsDashboardTheme.greyPanel
                        .withValues(alpha: 0.88),
                  ),
                ),
              ],
            ),
          ),
          if (onMoreTap != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onMoreTap,
                borderRadius: BorderRadius.circular(10.tr),
                child: Container(
                  width: 34.tw,
                  height: 34.tw,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.tr),
                    color: ProjectsDashboardTheme.white.withValues(alpha: 0.12),
                    border: Border.all(
                      color: ProjectsDashboardTheme.white.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Icon(
                    Icons.more_horiz_rounded,
                    size: 20.tsp,
                    color: ProjectsDashboardTheme.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
