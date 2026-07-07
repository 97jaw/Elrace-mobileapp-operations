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
        borderRadius: BorderRadius.circular(18.r),
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
          decoration: ProjectsDashboardTheme.frostedPanel(radius: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  gradient: ProjectsDashboardTheme.cardHeaderGradient,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(17.r),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: ProjectsDashboardTheme.maroon.withValues(
                          alpha: 0.25,
                        ),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: ProjectsDashboardTheme.white.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      child: Text(
                        agreementNo,
                        style: GoogleFonts.poppins(
                          fontSize: 11.sp,
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
                      size: 22.sp,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(12.w),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12.r),
                      child: _ClientThumb(
                        photoUrl: photoUrl,
                        name: agreement.projectName,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            agreement.projectName,
                            style: GoogleFonts.poppins(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: ProjectsDashboardTheme.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 10.h),
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10.w,
                                  vertical: 4.h,
                                ),
                                decoration: BoxDecoration(
                                  color: ProjectsDashboardTheme.maroon
                                      .withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(20.r),
                                  border: Border.all(
                                    color: ProjectsDashboardTheme.white
                                        .withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Text(
                                  'In progress',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w600,
                                    color: ProjectsDashboardTheme.white,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10.w,
                                  vertical: 4.h,
                                ),
                                decoration: BoxDecoration(
                                  color: ProjectsDashboardTheme.white
                                      .withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(20.r),
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
                                      size: 14.sp,
                                      color: ProjectsDashboardTheme.white,
                                    ),
                                    SizedBox(width: 4.w),
                                    Text(
                                      '${agreement.totalProjects}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11.sp,
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
    final size = 64.w;
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
          fontSize: 24.sp,
          color: ProjectsDashboardTheme.navy,
        ),
      ),
    );
  }
}
