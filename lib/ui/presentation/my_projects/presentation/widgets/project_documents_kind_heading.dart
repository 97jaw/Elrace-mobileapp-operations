import 'package:el_race/ui/presentation/my_projects/presentation/models/project_document_hub_kind.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// DMS icons — transparent PNGs from design (no baked-in card background).
abstract final class ProjectDocumentsIcons {
  static const workOrder = 'assets/png/project_docs/wo_icon.png';
  static const estimation = 'assets/png/project_docs/estimation_icon.png';
  static const sharePoint = 'assets/png/project_docs/sharepoint_icon.png';
  static const file = 'assets/png/project_docs/file_icon.png';

  static String pathFor({
    ProjectDocumentHubKind? kind,
    bool isFolder = false,
    bool isFile = false,
  }) {
    if (isFile) return file;
    if (isFolder) return sharePoint;
    return switch (kind) {
      ProjectDocumentHubKind.workOrder => workOrder,
      ProjectDocumentHubKind.cloud => sharePoint,
      ProjectDocumentHubKind.estimation => estimation,
      null => workOrder,
    };
  }

  static Widget image({
    ProjectDocumentHubKind? kind,
    bool isFolder = false,
    bool isFile = false,
    double size = 52,
  }) {
    return Image.asset(
      pathFor(kind: kind, isFolder: isFolder, isFile: isFile),
      width: size.w,
      height: size.w,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => Icon(
        isFile
            ? Icons.description_outlined
            : isFolder
                ? Icons.folder_rounded
                : Icons.folder_copy_rounded,
        size: (size * 0.62).sp,
        color: const Color(0xFF2E3445),
      ),
    );
  }
}

/// Folder heading: icon + title (e.g. icon + Workorders).
class ProjectDocumentsKindHeading extends StatelessWidget {
  const ProjectDocumentsKindHeading({
    super.key,
    required this.kind,
    this.title,
    this.iconSize = 30,
    this.fontSize,
    this.color,
    this.fontWeight = FontWeight.w700,
    this.expand = true,
  });

  final ProjectDocumentHubKind kind;
  final String? title;
  final double iconSize;
  final double? fontSize;
  final Color? color;
  final FontWeight fontWeight;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final label = title ?? kind.title;
    final row = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        ProjectDocumentsIcons.image(kind: kind, size: iconSize),
        SizedBox(width: 10.w),
        if (expand)
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: fontSize ?? 17.sp,
                fontWeight: fontWeight,
                color: color ?? ProjectsDashboardTheme.white,
                height: 1.15,
              ),
            ),
          )
        else
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: fontSize ?? 17.sp,
              fontWeight: fontWeight,
              color: color ?? ProjectsDashboardTheme.white,
              height: 1.15,
            ),
          ),
      ],
    );
    return row;
  }
}
