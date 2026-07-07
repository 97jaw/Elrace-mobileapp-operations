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
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
        clipBehavior: Clip.antiAlias,
        decoration: ProjectsDashboardTheme.frostedPanel(radius: 18),
        child: Stack(
          children: [
            if (showBackgroundLogo && bgLogo.isNotEmpty)
              Positioned(
                right: 10.w,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Opacity(
                    opacity: 0.2,
                    child: ClipOval(
                      child: ProjectsCachedImage(
                        url: bgLogo,
                        width: 72.w,
                        height: 72.w,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
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
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: ProjectsDashboardTheme.greyPanel
                                .withValues(alpha: 0.95),
                          ),
                        ),
                      ),
                      Text(
                        statusCount,
                        style: GoogleFonts.koulen(
                          fontSize: 16.sp,
                          color: _statusColor(statusCount),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    woName.isNotEmpty ? woName : '—',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: ProjectsDashboardTheme.white,
                      height: 1.25,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 10.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: ProjectsDashboardTheme.navy.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(14.r),
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
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                    color: ProjectsDashboardTheme.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                'AED',
                                style: GoogleFonts.poppins(
                                  fontSize: 10.sp,
                                  color: ProjectsDashboardTheme.greyPanel,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!hidePmAvatar)
                          _PmAvatar(photoUrl: pmPhoto, name: project.partnerId)
                        else
                          SizedBox(width: 32.w),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              formattedDate,
                              style: GoogleFonts.poppins(
                                fontSize: 12.sp,
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
          width: 32.w,
          height: 32.w,
          fit: BoxFit.cover,
        ),
      );
    }
    return CircleAvatar(
      radius: 16.r,
      backgroundColor: ProjectsDashboardTheme.maroon.withValues(alpha: 0.8),
      child: Text(
        initial,
        style: GoogleFonts.poppins(
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          color: ProjectsDashboardTheme.white,
        ),
      ),
    );
  }
}
