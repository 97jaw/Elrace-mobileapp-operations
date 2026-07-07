import 'package:el_race/ui/presentation/my_projects/presentation/models/project_document_hub_kind.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class ProjectDocumentsKindBadge extends StatelessWidget {
  const ProjectDocumentsKindBadge({
    super.key,
    required this.kind,
  });

  final ProjectDocumentHubKind kind;

  Color get _background => switch (kind) {
        ProjectDocumentHubKind.workOrder =>
          ProjectsDashboardTheme.maroon.withValues(alpha: 0.12),
        ProjectDocumentHubKind.estimation =>
          const Color(0xFF2563EB).withValues(alpha: 0.12),
        ProjectDocumentHubKind.cloud =>
          const Color(0xFF0891B2).withValues(alpha: 0.12),
      };

  Color get _border => switch (kind) {
        ProjectDocumentHubKind.workOrder =>
          ProjectsDashboardTheme.maroon.withValues(alpha: 0.35),
        ProjectDocumentHubKind.estimation =>
          const Color(0xFF2563EB).withValues(alpha: 0.35),
        ProjectDocumentHubKind.cloud =>
          const Color(0xFF0891B2).withValues(alpha: 0.35),
      };

  Color get _text => switch (kind) {
        ProjectDocumentHubKind.workOrder => ProjectsDashboardTheme.maroonDark,
        ProjectDocumentHubKind.estimation => const Color(0xFF1D4ED8),
        ProjectDocumentHubKind.cloud => const Color(0xFF0E7490),
      };

  String get _shortLabel => switch (kind) {
        ProjectDocumentHubKind.workOrder => 'WO',
        ProjectDocumentHubKind.estimation => 'EST',
        ProjectDocumentHubKind.cloud => 'SP',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.r),
        color: _background,
        border: Border.all(color: _border),
      ),
      child: Text(
        _shortLabel,
        style: GoogleFonts.poppins(
          fontSize: 9.sp,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: _text,
        ),
      ),
    );
  }
}
