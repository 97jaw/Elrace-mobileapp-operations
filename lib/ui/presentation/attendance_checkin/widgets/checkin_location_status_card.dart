import 'package:el_race/ui/presentation/attendance_checkin/utils/checkin_distance_formatter.dart';
import 'package:el_race/ui/presentation/attendance_checkin/utils/checkin_sheet_logic.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class CheckinLocationStatusCard extends StatelessWidget {
  const CheckinLocationStatusCard({
    super.key,
    required this.state,
    this.distanceMeters,
    this.radiusMeters,
    this.remote = false,
  });

  final CheckinLocationCardState state;
  final double? distanceMeters;
  final double? radiusMeters;
  final bool remote;

  @override
  Widget build(BuildContext context) {
    final visual = _visualFor(state, remote: remote);
    final radiusText = radiusMeters == null
        ? null
        : 'Allowed radius ${radiusMeters!.round()} m';
    final away = CheckinDistanceFormatter.formatAway(distanceMeters);
    final subtitle = _subtitle(
      state: state,
      away: away,
      radiusText: radiusText,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44.w,
          height: 44.w,
          decoration: BoxDecoration(
            color: visual.iconBg,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(visual.icon, color: visual.accent, size: 22.sp),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                visual.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 21.sp,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: visual.titleColor,
                ),
              ),
              if (subtitle != null) ...[
                SizedBox(height: 4.h),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: HomeGlassTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (visual.chipLabel == null && visual.chipIcon != null) ...[
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: visual.chipBg,
              shape: BoxShape.circle,
            ),
            child: Icon(visual.chipIcon, size: 18.sp, color: visual.accent),
          ),
        ] else if (visual.chipLabel != null) ...[
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: visual.chipBg,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              visual.chipLabel!,
              style: GoogleFonts.poppins(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: visual.accent,
              ),
            ),
          ),
        ],
      ],
    );
  }

  static String? _subtitle({
    required CheckinLocationCardState state,
    required String away,
    required String? radiusText,
  }) {
    switch (state) {
      case CheckinLocationCardState.inside:
      case CheckinLocationCardState.outside:
        if (radiusText == null) return away;
        return '$away • $radiusText';
      case CheckinLocationCardState.waitingGps:
        return radiusText;
      case CheckinLocationCardState.anywhere:
      case CheckinLocationCardState.noLinkedLocation:
      case CheckinLocationCardState.mobileDisabled:
        return null;
    }
  }

  static _CardVisual _visualFor(
    CheckinLocationCardState state, {
    bool remote = false,
  }) {
    switch (state) {
      case CheckinLocationCardState.inside:
        return _CardVisual(
          title: 'Inside allowed area',
          icon: Icons.location_on,
          accent: HomeGlassTheme.bottleGreen,
          titleColor: HomeGlassTheme.bottleGreen,
          iconBg: HomeGlassTheme.bottleGreen.withValues(alpha: 0.14),
          chipBg: HomeGlassTheme.bottleGreen.withValues(alpha: 0.12),
          chipIcon: Icons.check_circle,
        );
      case CheckinLocationCardState.outside:
        return const _CardVisual(
          title: 'Outside allowed area',
          icon: Icons.location_on,
          accent: Color(0xFFC45C26),
          titleColor: Color(0xFFC45C26),
          iconBg: Color(0xFFFFF0E6),
          chipBg: Color(0xFFFFF0E6),
          chipLabel: 'Move closer',
        );
      case CheckinLocationCardState.waitingGps:
        return const _CardVisual(
          title: 'Getting your location…',
          icon: Icons.gps_not_fixed,
          accent: HomeGlassTheme.textSecondary,
          titleColor: HomeGlassTheme.textPrimary,
          iconBg: Color(0xFFF3F4F6),
          chipBg: Color(0xFFF3F4F6),
        );
      case CheckinLocationCardState.anywhere:
        return _CardVisual(
          title: remote ? 'Remote check-in' : 'Check-in from anywhere',
          icon: remote ? Icons.home_work_outlined : Icons.public,
          accent: HomeGlassTheme.textSecondary,
          titleColor: HomeGlassTheme.textPrimary,
          iconBg: const Color(0xFFF5F7FA),
          chipBg: const Color(0xFFF5F7FA),
        );
      case CheckinLocationCardState.noLinkedLocation:
        return const _CardVisual(
          title: 'No linked location',
          icon: Icons.link_off,
          accent: HomeGlassTheme.textSecondary,
          titleColor: HomeGlassTheme.textPrimary,
          iconBg: Color(0xFFF3F4F6),
          chipBg: Color(0xFFF3F4F6),
        );
      case CheckinLocationCardState.mobileDisabled:
        return const _CardVisual(
          title: 'Mobile check-in unavailable',
          icon: Icons.phonelink_erase,
          accent: HomeGlassTheme.textSecondary,
          titleColor: HomeGlassTheme.textPrimary,
          iconBg: Color(0xFFF3F4F6),
          chipBg: Color(0xFFF3F4F6),
        );
    }
  }
}

class _CardVisual {
  const _CardVisual({
    required this.title,
    required this.icon,
    required this.accent,
    required this.titleColor,
    required this.iconBg,
    required this.chipBg,
    this.chipLabel,
    this.chipIcon,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final Color titleColor;
  final Color iconBg;
  final Color chipBg;
  final String? chipLabel;
  final IconData? chipIcon;
}
