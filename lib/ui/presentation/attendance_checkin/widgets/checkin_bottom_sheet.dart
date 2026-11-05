import 'package:el_race/ui/presentation/attendance_checkin/models/checkin_context_model.dart';
import 'package:el_race/ui/presentation/attendance_checkin/utils/checkin_sheet_logic.dart';
import 'package:el_race/ui/presentation/attendance_checkin/widgets/checkin_action_buttons.dart';
import 'package:el_race/ui/presentation/attendance_checkin/widgets/checkin_location_status_card.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_theme.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_mid_attendance_times.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class CheckinBottomSheet extends StatelessWidget {
  const CheckinBottomSheet({
    super.key,
    required this.contextModel,
    required this.checkinWidgetDisabled,
    required this.projects,
    required this.selectedProject,
    required this.hasGps,
    required this.isInsideGeofence,
    required this.distanceMeters,
    required this.onValidateBeforeCheckIn,
    this.onActionComplete,
    this.onContextRefresh,
  });

  final CheckinContextModel contextModel;
  final bool checkinWidgetDisabled;
  final List<CheckinAllowedProject> projects;
  final CheckinAllowedProject? selectedProject;
  final bool hasGps;
  final bool isInsideGeofence;
  final double? distanceMeters;
  final Future<bool> Function() onValidateBeforeCheckIn;
  final VoidCallback? onActionComplete;
  final VoidCallback? onContextRefresh;

  @override
  Widget build(BuildContext context) {
    final cardState = CheckinSheetLogic.cardState(
      context: contextModel,
      checkinWidgetDisabled: checkinWidgetDisabled,
      projects: projects,
      selectedProject: selectedProject,
      hasGps: hasGps,
      isInsideGeofence: isInsideGeofence,
    );
    final sectionMuted = !CheckinSheetLogic.actionsAvailable(cardState) &&
        cardState != CheckinLocationCardState.outside &&
        cardState != CheckinLocationCardState.waitingGps;

    return Material(
      color: Colors.white,
      elevation: 12,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      child: SafeArea(
        top: false,
        child: Opacity(
          opacity: sectionMuted ? 0.72 : 1,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                ),
                SizedBox(height: 14.h),
                CheckinLocationStatusCard(
                  state: cardState,
                  distanceMeters: distanceMeters,
                  radiusMeters: selectedProject?.geofenceRadiusM ??
                      contextModel.defaultRadiusM,
                  remote: contextModel.remote,
                ),
                SizedBox(height: 14.h),
                Container(
                  padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 6.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3FB),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(left: 6.w, bottom: 2.h),
                        child: Text(
                          'Today',
                          style: GoogleFonts.poppins(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: HomeGlassTheme.textSecondary,
                          ),
                        ),
                      ),
                      const HomeMidAttendanceTimes(),
                    ],
                  ),
                ),
                SizedBox(height: 14.h),
                CheckinActionButtons(
                  cardState: cardState,
                  todayStatus: contextModel.todayStatus,
                  selectedProjectId: selectedProject?.projectId,
                  onValidateBeforeCheckIn: onValidateBeforeCheckIn,
                  contextModel: contextModel,
                  locationTitle: contextModel.remote
                      ? 'Remote'
                      : (selectedProject?.name ?? 'Company Office'),
                  locationSubtitle: selectedProject?.woRefNo,
                  onActionComplete: onActionComplete,
                  onContextRefresh: onContextRefresh,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
