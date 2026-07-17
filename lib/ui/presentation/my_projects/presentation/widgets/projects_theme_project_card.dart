import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/my_projects/domain/entities/project_entity.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_dashboard_aggregator.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_cached_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Frosted project card for the themed project listing screen.
class ProjectsThemeProjectCard extends StatelessWidget {
  const ProjectsThemeProjectCard({
    super.key,
    required this.project,
    required this.onTap,
    this.showBackgroundLogo = false,
    this.hidePmAvatar = false,
  });

  final ProjectEntity project;
  final VoidCallback onTap;
  final bool showBackgroundLogo;
  final bool hidePmAvatar;

  @override
  Widget build(BuildContext context) {
    final woNo = project.woRefNo.trim();
    final woName = project.name.trim();
    final formattedAmount = _formatAmount(project.woAmount);
    final formattedDate = _formatDate(project.date);
    final statusCount = _formatDifferenceDays(project.differenceDays ?? 0);
    final bgLogo = ProjectsDashboardAggregator.normalizePhotoUrl(
      project.clientImageUrl,
    );
    final pmPhoto = ProjectsDashboardAggregator.normalizePhotoUrl(
      project.managerPhoto ?? project.projectManagerPhoto,
    );
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.tw, vertical: 6.th),
        clipBehavior: Clip.antiAlias,
        decoration: ProjectsDashboardTheme.frostedPanel(radius: 18),
        child: Stack(
          children: [
            if (showBackgroundLogo && bgLogo.isNotEmpty)
              Positioned(
                right: 10.tw,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Opacity(
                    opacity: 0.2,
                    child: ClipOval(
                      child: ProjectsCachedImage(
                        url: bgLogo,
                        width: 72.tw,
                        height: 72.tw,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(14.tw, 12.th, 14.tw, 12.th),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          woNo.isNotEmpty ? woNo : '#${project.projectId}',
                          style: GoogleFonts.poppins(
                            fontSize: 12.tsp,
                            fontWeight: FontWeight.w600,
                            color: ProjectsDashboardTheme.greyPanel
                                .withValues(alpha: 0.95),
                          ),
                        ),
                      ),
                      Text(
                        statusCount,
                        style: GoogleFonts.koulen(
                          fontSize: 16.tsp,
                          color: _statusColor(statusCount),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.th),
                  Text(
                    woName.isNotEmpty ? woName : '—',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14.tsp,
                      fontWeight: FontWeight.w600,
                      color: ProjectsDashboardTheme.white,
                      height: 1.25,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 10.th),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 8.th),
                    decoration: BoxDecoration(
                      color: ProjectsDashboardTheme.navy.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(14.tr),
                      border: Border.all(
                        color: ProjectsDashboardTheme.white.withValues(
                          alpha: 0.25,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  formattedAmount,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13.tsp,
                                    fontWeight: FontWeight.w600,
                                    color: ProjectsDashboardTheme.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 4.tw),
                              Text(
                                'AED',
                                style: GoogleFonts.poppins(
                                  fontSize: 10.tsp,
                                  color: ProjectsDashboardTheme.greyPanel,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!hidePmAvatar)
                          _PmAvatar(photoUrl: pmPhoto, name: project.partnerId)
                        else
                          SizedBox(width: 32.tw),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              formattedDate,
                              style: GoogleFonts.poppins(
                                fontSize: 12.tsp,
                                fontWeight: FontWeight.w500,
                                color: ProjectsDashboardTheme.greyPanel,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatAmount(double amount) {
    return NumberFormat('#,##0', 'en').format(amount);
  }

  static String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      final normalized = raw.contains(' ') && !raw.contains('T')
          ? raw.replaceFirst(' ', 'T')
          : raw;
      final parsed = DateTime.tryParse(normalized);
      if (parsed == null) return raw;
      return DateFormat('dd/MM/yyyy').format(parsed);
    } catch (_) {
      return raw;
    }
  }

  static String _formatDifferenceDays(int days) {
    if (days > 0) return '+$days';
    if (days < 0) return '$days';
    return '0';
  }

  static Color _statusColor(String status) {
    if (status.startsWith('+')) {
      return ProjectsDashboardTheme.greyPanel;
    }
    return ProjectsDashboardTheme.navy;
  }
}

class _PmAvatar extends StatelessWidget {
  const _PmAvatar({required this.photoUrl, required this.name});

  final String photoUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final initial =
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'P';
    if (photoUrl.isNotEmpty) {
      return ClipOval(
        child: ProjectsCachedImage(
          url: photoUrl,
          width: 32.tw,
          height: 32.tw,
          fit: BoxFit.cover,
        ),
      );
    }
    return CircleAvatar(
      radius: 16.tr,
      backgroundColor: ProjectsDashboardTheme.maroon.withValues(alpha: 0.8),
      child: Text(
        initial,
        style: GoogleFonts.poppins(
          fontSize: 11.tsp,
          fontWeight: FontWeight.w700,
          color: ProjectsDashboardTheme.white,
        ),
      ),
    );
  }
}
