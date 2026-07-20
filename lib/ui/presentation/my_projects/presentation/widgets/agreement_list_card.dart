import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/my_projects/data/models/user_project_model.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_dashboard_aggregator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class AgreementListCard extends StatelessWidget {
  const AgreementListCard({
    super.key,
    required this.agreement,
    required this.onTap,
  });

  final UserProjectModel agreement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final photoUrl =
        ProjectsDashboardAggregator.normalizePhotoUrl(agreement.photoUrl);
    final agreementNo = agreement.agreementNo?.isNotEmpty == true
        ? agreement.agreementNo!
        : '${agreement.projectId}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.tr),
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 16.tw, vertical: 6.th),
          decoration: ProjectsDashboardTheme.frostedPanel(radius: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.tw, vertical: 6.th),
                decoration: BoxDecoration(
                  gradient: ProjectsDashboardTheme.cardHeaderGradient,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(17.tr),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.tw,
                        vertical: 2.th,
                      ),
                      decoration: BoxDecoration(
                        color: ProjectsDashboardTheme.maroon.withValues(
                          alpha: 0.25,
                        ),
                        borderRadius: BorderRadius.circular(8.tr),
                        border: Border.all(
                          color: ProjectsDashboardTheme.white.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      child: Text(
                        agreementNo,
                        style: GoogleFonts.poppins(
                          fontSize: 11.tsp,
                          fontWeight: FontWeight.w700,
                          color: ProjectsDashboardTheme.white,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: ProjectsDashboardTheme.white.withValues(
                        alpha: 0.85,
                      ),
                      size: 22.tsp,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(12.tw),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12.tr),
                      child: _ClientThumb(
                        photoUrl: photoUrl,
                        name: agreement.projectName,
                      ),
                    ),
                    SizedBox(width: 12.tw),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            agreement.projectName,
                            style: GoogleFonts.poppins(
                              fontSize: 14.tsp,
                              fontWeight: FontWeight.w700,
                              color: ProjectsDashboardTheme.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 10.th),
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10.tw,
                                  vertical: 4.th,
                                ),
                                decoration: BoxDecoration(
                                  color: ProjectsDashboardTheme.maroon
                                      .withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(20.tr),
                                  border: Border.all(
                                    color: ProjectsDashboardTheme.white
                                        .withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Text(
                                  'In progress',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10.tsp,
                                    fontWeight: FontWeight.w600,
                                    color: ProjectsDashboardTheme.white,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10.tw,
                                  vertical: 4.th,
                                ),
                                decoration: BoxDecoration(
                                  color: ProjectsDashboardTheme.white
                                      .withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(20.tr),
                                  border: Border.all(
                                    color: ProjectsDashboardTheme.white
                                        .withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.folder_open_rounded,
                                      size: 14.tsp,
                                      color: ProjectsDashboardTheme.white,
                                    ),
                                    SizedBox(width: 4.tw),
                                    Text(
                                      '${agreement.totalProjects}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11.tsp,
                                        fontWeight: FontWeight.w700,
                                        color: ProjectsDashboardTheme.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
      ),
    );
  }
}

class _ClientThumb extends StatelessWidget {
  const _ClientThumb({
    required this.photoUrl,
    required this.name,
  });

  final String photoUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final size = 64.tw;
    if (photoUrl.isNotEmpty) {
      return Image.network(
        photoUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(size),
      );
    }
    return _placeholder(size);
  }

  Widget _placeholder(double size) {
    final letter =
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      color: ProjectsDashboardTheme.grey.withValues(alpha: 0.25),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: GoogleFonts.koulen(
          fontSize: 24.tsp,
          color: ProjectsDashboardTheme.navy,
        ),
      ),
    );
  }
}
