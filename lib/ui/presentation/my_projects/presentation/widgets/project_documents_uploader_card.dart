import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/project_documents_models.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_file_row.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_marquee_title.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/project_documents_section_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Staff row for Uploaded By — same gradient tile language as folder section tiles.
class ProjectDocumentsUploaderCard extends StatelessWidget {
  const ProjectDocumentsUploaderCard({
    super.key,
    required this.uploader,
    required this.onTap,
  });

  final ProjectDocumentsUploaderItem uploader;
  final VoidCallback onTap;

  static const Color _titleColor = ProjectsDashboardTheme.greyDeep;
  static const Color _metaColor = ProjectsDashboardTheme.greyDark;

  @override
  Widget build(BuildContext context) {
    final lastLabel = formatDocumentDateLabel(uploader.lastUploadedAt);
    final uploadsLine = uploader.totalUploads == 1
        ? '1 upload'
        : '${uploader.totalUploads} uploads';
    final projectsLabel = projectDocumentsCountLabel(
      uploader.projectCount,
      singular: 'project',
      plural: 'projects',
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.tr),
        child: Container(
          decoration: projectDocumentsFileRowDecoration(),
          padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 10.th),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _UploaderPhoto(
                photoUrl: uploader.photoUrl,
                name: uploader.name,
                size: 54,
              ),
              SizedBox(width: 10.tw),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProjectDocumentsOneLineMarquee(
                      text: uploader.name,
                      fontSize: 15.tsp,
                      fontWeight: FontWeight.w700,
                      italic: false,
                      color: _titleColor,
                    ),
                    if (uploader.designation.trim().isNotEmpty) ...[
                      SizedBox(height: 3.th),
                      Text(
                        uploader.designation,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12.tsp,
                          fontStyle: FontStyle.italic,
                          color: _metaColor.withValues(alpha: 0.82),
                          height: 1.25,
                        ),
                      ),
                    ],
                    SizedBox(height: 6.th),
                    Text(
                      uploadsLine,
                      style: GoogleFonts.poppins(
                        fontSize: 14.tsp,
                        fontWeight: FontWeight.w600,
                        color: _metaColor.withValues(alpha: 0.92),
                        height: 1.15,
                      ),
                    ),
                    if (lastLabel != '—') ...[
                      SizedBox(height: 3.th),
                      Text(
                        'Last uploaded $lastLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: projectDocumentsUpdatedMetaStyle(),
                      ),
                    ],
                    SizedBox(height: 2.th),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Uploaded to portfolio',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 10.tsp,
                              color: _metaColor.withValues(alpha: 0.82),
                            ),
                          ),
                        ),
                        Text(
                          projectsLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 11.tsp,
                            fontWeight: FontWeight.w600,
                            color: _metaColor.withValues(alpha: 0.92),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: _metaColor.withValues(alpha: 0.55),
                size: 22.tsp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploaderPhoto extends StatelessWidget {
  const _UploaderPhoto({
    required this.photoUrl,
    required this.name,
    this.size = 54,
  });

  final String photoUrl;
  final String name;
  final double size;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      final p = parts.first;
      return p.length >= 2 ? p.substring(0, 2).toUpperCase() : p.toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final token = SharedPref.getLoginData().result?.token ?? '';
    final dim = size.tw;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14.tr),
      child: SizedBox(
        width: dim,
        height: dim,
        child: photoUrl.trim().isNotEmpty
            ? Image.network(
                photoUrl.trim(),
                fit: BoxFit.cover,
                headers: {
                  'Accept': 'image/*',
                  if (token.isNotEmpty) 'Authorization': 'Bearer $token',
                },
                errorBuilder: (_, __, ___) =>
                    _InitialsFallback(initials: _initials, size: dim),
              )
            : _InitialsFallback(initials: _initials, size: dim),
      ),
    );
  }
}

class _InitialsFallback extends StatelessWidget {
  const _InitialsFallback({
    required this.initials,
    required this.size,
  });

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ProjectsDashboardTheme.greyPanel.withValues(alpha: 0.65),
            ProjectsDashboardTheme.greyLight.withValues(alpha: 0.45),
          ],
        ),
        border: Border.all(
          color: ProjectsDashboardTheme.white.withValues(alpha: 0.55),
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.poppins(
            fontSize: (size * 0.34).tsp,
            fontWeight: FontWeight.w700,
            color: ProjectsDashboardTheme.greyDeep,
          ),
        ),
      ),
    );
  }
}
