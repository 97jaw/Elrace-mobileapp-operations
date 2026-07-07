import 'package:el_race/ui/presentation/my_projects/presentation/models/project_document_hub_kind.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_file_row.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_kind_heading.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_marquee_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

enum ProjectDocumentsTileVariant { main, sub }

/// Shared DMS section row — large icon left, title + counters stacked.
class ProjectDocumentsSectionTile extends StatelessWidget {
  const ProjectDocumentsSectionTile({
    super.key,
    required this.title,
    required this.fileCount,
    required this.onTap,
    this.kind,
    this.isFolder = false,
    this.isFile = false,
    this.iconSize = 52,
    this.lastUpdatedLabel,
    this.updatedBy,
    this.bottomRightLabel,
    this.fileCountLabel,
    this.subtitle,
    this.showFileCount = true,
    this.showMeta = true,
    this.showChevron = true,
    this.variant = ProjectDocumentsTileVariant.main,
  });

  final String title;
  final int fileCount;
  final VoidCallback onTap;
  final ProjectDocumentHubKind? kind;
  final bool isFolder;
  final bool isFile;
  final double iconSize;
  final String? lastUpdatedLabel;
  final String? updatedBy;
  final String? bottomRightLabel;
  final String? fileCountLabel;
  final String? subtitle;
  final bool showFileCount;
  final bool showMeta;
  final bool showChevron;
  final ProjectDocumentsTileVariant variant;

  static const Color _titleColor = ProjectsDashboardTheme.greyDeep;
  static const Color _metaColor = ProjectsDashboardTheme.greyDark;

  bool get _isSub => variant == ProjectDocumentsTileVariant.sub;

  @override
  Widget build(BuildContext context) {
    final filesLine = fileCountLabel ?? '$fileCount files';
    final updated = _cleanMeta(lastUpdatedLabel);
    final by = _cleanMeta(updatedBy);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          decoration: projectDocumentsFileRowDecoration(),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          child: Row(
            crossAxisAlignment:
                _isSub ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              ProjectDocumentsIcons.image(
                kind: kind,
                isFolder: isFolder,
                isFile: isFile,
                size: iconSize,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProjectDocumentsOneLineMarquee(
                      text: title,
                      fontSize: _isSub ? 14.sp : 15.sp,
                      fontWeight: _isSub ? FontWeight.w500 : FontWeight.w700,
                      italic: _isSub,
                      color: _titleColor,
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      SizedBox(height: 3.h),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 10.sp,
                          color: _metaColor.withValues(alpha: 0.88),
                        ),
                      ),
                    ],
                    if (showFileCount) ...[
                      SizedBox(height: 6.h),
                      Text(
                        filesLine,
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.normal,
                          color: _metaColor.withValues(alpha: 0.92),
                          height: 1.15,
                        ),
                      ),
                    ],
                    if (showMeta && _isSub && (updated != null || by != null)) ...[
                      SizedBox(height: 3.h),
                      Text(
                        _subMetaLine(updated, by),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: projectDocumentsUpdatedMetaStyle(),
                      ),
                    ] else if (showMeta && !_isSub) ...[
                      if (updated != null) ...[
                        SizedBox(height: 3.h),
                        Text(
                          'Updated $updated',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: projectDocumentsUpdatedMetaStyle(),
                        ),
                      ],
                      if (by != null || bottomRightLabel != null) ...[
                        SizedBox(height: 2.h),
                        Row(
                          children: [
                            if (by != null)
                              Expanded(
                                child: Text(
                                  'By $by',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10.sp,
                                    color: _metaColor.withValues(alpha: 0.82),
                                  ),
                                ),
                              ),
                            if (bottomRightLabel != null)
                              Text(
                                bottomRightLabel!,
                                style: GoogleFonts.poppins(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: _metaColor.withValues(alpha: 0.92),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ] else if (!showMeta && bottomRightLabel != null) ...[
                      SizedBox(height: 4.h),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          bottomRightLabel!,
                          style: GoogleFonts.poppins(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: _metaColor.withValues(alpha: 0.92),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showChevron)
                Icon(
                  Icons.chevron_right_rounded,
                  color: _metaColor.withValues(alpha: 0.55),
                  size: 22.sp,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _subMetaLine(String? updated, String? by) {
    final parts = <String>[
      if (updated != null) 'Updated $updated',
      if (by != null) 'By $by',
    ];
    return parts.join(' · ');
  }

  String? _cleanMeta(String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty || v == '—') return null;
    return v;
  }
}

String projectDocumentsCountLabel(int count, {required String singular, required String plural}) {
  return '$count ${count == 1 ? singular : plural}';
}
