import 'package:el_race/ui/presentation/my_projects/presentation/theme/projects_dashboard_theme.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_dashboard_aggregator.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/widgets/projects_cached_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Agreement / client hero — large background logo with name on top.
class ProjectsAgreementHeroHeader extends StatelessWidget {
  const ProjectsAgreementHeroHeader({
    super.key,
    required this.title,
    this.photoUrl,
    this.subtitle,
    this.showBack = false,
    this.onBack,
  });

  final String title;
  final String? photoUrl;
  final String? subtitle;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final normalized =
        ProjectsDashboardAggregator.normalizePhotoUrl(photoUrl);

    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 8.h),
      constraints: BoxConstraints(minHeight: 88.h),
      clipBehavior: Clip.antiAlias,
      decoration: ProjectsDashboardTheme.frostedPanel(radius: 20),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          if (normalized.isNotEmpty)
            Positioned(
              right: -12.w,
              bottom: -20.h,
              child: Opacity(
                opacity: 0.2,
                child: ProjectsCachedImage(
                  url: normalized,
                  width: 120.w,
                  height: 120.w,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    ProjectsDashboardTheme.navy.withValues(alpha: 0.55),
                    ProjectsDashboardTheme.maroon.withValues(alpha: 0.45),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 10.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (showBack)
                  _HeroBackButton(onBack: onBack)
                else if (normalized.isNotEmpty)
                  ClipOval(
                    child: ProjectsCachedImage(
                      url: normalized,
                      width: 36.w,
                      height: 36.w,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  _InitialsBadge(title: title),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: ProjectsDashboardTheme.white,
                          height: 1.15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                        SizedBox(height: 3.h),
                        Text(
                          subtitle!,
                          style: GoogleFonts.poppins(
                            fontSize: 10.sp,
                            color: ProjectsDashboardTheme.greyPanel
                                .withValues(alpha: 0.95),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBackButton extends StatelessWidget {
  const _HeroBackButton({this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onBack ?? () => Navigator.maybePop(context),
        customBorder: const CircleBorder(),
        child: Container(
          width: 36.w,
          height: 36.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: ProjectsDashboardTheme.maroonAccentGradient,
            border: Border.all(
              color: ProjectsDashboardTheme.white.withValues(alpha: 0.5),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: ProjectsDashboardTheme.white,
            size: 16.sp,
          ),
        ),
      ),
    );
  }
}

class _InitialsBadge extends StatelessWidget {
  const _InitialsBadge({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final initial =
        title.trim().isNotEmpty ? title.trim()[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 18.r,
      backgroundColor: ProjectsDashboardTheme.maroon.withValues(alpha: 0.85),
      child: Text(
        initial,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w700,
          color: ProjectsDashboardTheme.white,
          fontSize: 14.sp,
        ),
      ),
    );
  }
}
