import 'package:el_race/core/widgets/timesheet/tm_marquee_text.dart';
import 'package:el_race/ui/presentation/attendance_checkin/models/checkin_context_model.dart';
import 'package:el_race/ui/presentation/home_screen/screens/custom_swipe_button.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_theme.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_mid_attendance_times.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class CheckinEligibilitySection extends StatelessWidget {
  const CheckinEligibilitySection({
    super.key,
    required this.contextModel,
    required this.checkinWidgetDisabled,
    required this.selectedProjectId,
    required this.selectedProjectName,
    required this.onValidateBeforeCheckIn,
    required this.onActionComplete,
  });

  final CheckinContextModel contextModel;
  final bool checkinWidgetDisabled;
  final int? selectedProjectId;
  final String? selectedProjectName;
  final Future<bool> Function() onValidateBeforeCheckIn;
  final VoidCallback? onActionComplete;

  bool get _hasAssignment => contextModel.hasBiotimeAssignment;

  bool get _sliderEnabled {
    if (_hasAssignment) return false;
    if (checkinWidgetDisabled || !contextModel.mobileCheckinAllowed) {
      return false;
    }
    if (!contextModel.todayStatus.checkedIn && selectedProjectId == null) {
      return false;
    }
    return true;
  }

  String get _statusHeadline {
    final status = contextModel.todayStatus;
    if (status.checkedOut) return 'Checked out for today';
    if (status.checkedIn) return 'Checked in';
    return 'Not checked in';
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(18.w, 14.h, 18.w, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _statusHeadline,
                    style: GoogleFonts.poppins(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: HomeGlassTheme.textPrimary,
                    ),
                  ),
                ),
                if (selectedProjectName != null &&
                    selectedProjectName!.isNotEmpty) ...[
                  SizedBox(width: 8.w),
                  SizedBox(
                    width: 130.w,
                    child: TmMarqueeText(
                      text: selectedProjectName!,
                      height: 20.h,
                      style: GoogleFonts.poppins(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: HomeGlassTheme.bottleGreen,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(18.w, 8.h, 18.w, 0),
            child: const HomeMidAttendanceTimes(),
          ),
          SizedBox(height: 10.h),
          Expanded(
            child: _hasAssignment
                ? _OfficeDeviceList(contextModel: contextModel)
                : _MobileCheckinPanel(
                    sliderEnabled: _sliderEnabled,
                    selectedProjectId: selectedProjectId,
                    onValidateBeforeCheckIn: onValidateBeforeCheckIn,
                    onActionComplete: onActionComplete,
                  ),
          ),
        ],
      ),
    );
  }
}

class _OfficeDeviceList extends StatelessWidget {
  const _OfficeDeviceList({required this.contextModel});

  final CheckinContextModel contextModel;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(18.w, 0, 18.w, 16.h),
      children: [
        Text(
          'Your BioTime offices',
          style: GoogleFonts.poppins(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: HomeGlassTheme.textSecondary,
          ),
        ),
        SizedBox(height: 8.h),
        for (final office in contextModel.biotimeOffices)
          _OfficeRow(
            title: office.name,
            subtitle: office.code.isNotEmpty ? office.code : 'Office',
          ),
        if (contextModel.biotimeTerminals.isNotEmpty) ...[
          SizedBox(height: 12.h),
          Text(
            'Assigned devices',
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: HomeGlassTheme.textSecondary,
            ),
          ),
          SizedBox(height: 8.h),
          for (final terminal in contextModel.biotimeTerminals)
            _OfficeRow(
              title: terminal.alias,
              subtitle: terminal.officeName.isNotEmpty
                  ? terminal.officeName
                  : 'Terminal',
              icon: Icons.fingerprint,
            ),
        ],
        SizedBox(height: 12.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: HomeGlassTheme.bottleGreen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: HomeGlassTheme.bottleGreen.withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            'Use your assigned BioTime office or device to check in. Mobile GPS check-in is disabled for your profile.',
            style: GoogleFonts.poppins(
              fontSize: 11.sp,
              color: HomeGlassTheme.bottleGreen,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _OfficeRow extends StatelessWidget {
  const _OfficeRow({
    required this.title,
    required this.subtitle,
    this.icon = Icons.thumb_up,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: HomeGlassTheme.bottleGreen.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: HomeGlassTheme.bottleGreen,
              size: 18.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: HomeGlassTheme.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11.sp,
                    color: HomeGlassTheme.textSecondary,
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

class _MobileCheckinPanel extends StatelessWidget {
  const _MobileCheckinPanel({
    required this.sliderEnabled,
    required this.selectedProjectId,
    required this.onValidateBeforeCheckIn,
    required this.onActionComplete,
  });

  final bool sliderEnabled;
  final int? selectedProjectId;
  final Future<bool> Function() onValidateBeforeCheckIn;
  final VoidCallback? onActionComplete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18.w, 0, 18.w, 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Mobile field check-in',
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: HomeGlassTheme.textSecondary,
            ),
          ),
          SizedBox(height: 8.h),
          Expanded(
            child: Center(
              child: Opacity(
                opacity: sliderEnabled ? 1 : 0.45,
                child: IgnorePointer(
                  ignoring: !sliderEnabled,
                  child: CustomSwipeButton(
                    midSectionLayout: true,
                    swipeEnabled: sliderEnabled,
                    selectedProjectId: selectedProjectId,
                    onValidateBeforeCheckIn: onValidateBeforeCheckIn,
                    onActionComplete: onActionComplete,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
