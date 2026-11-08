import 'dart:async';

import 'package:el_race/core/services/attendance_status_sync_service.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/core/widgets/timesheet/tm_marquee_text.dart';
import 'package:el_race/ui/presentation/attendance_checkin/models/checkin_context_model.dart';
import 'package:el_race/ui/presentation/attendance_checkin/providers/checkin_activity_controller.dart';
import 'package:el_race/ui/presentation/attendance_checkin/widgets/checkin_bottom_sheet.dart';
import 'package:el_race/ui/presentation/attendance_checkin/widgets/checkin_map_section.dart';
import 'package:el_race/ui/presentation/attendance_checkin/widgets/checkin_project_search_panel.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Full-screen check-in activity: map + bottom sheet actions.
class AttendanceCheckInActivity extends StatefulWidget {
  const AttendanceCheckInActivity({super.key});

  @override
  State<AttendanceCheckInActivity> createState() =>
      _AttendanceCheckInActivityState();
}

class _AttendanceCheckInActivityState extends State<AttendanceCheckInActivity>
    with WidgetsBindingObserver {
  late final CheckinActivityController _controller;
  late final bool _checkinWidgetDisabled;
  bool _searchOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = CheckinActivityController();
    _controller.addListener(_onControllerChanged);
    // Cached once: reading login prefs is a full JSON parse, too costly
    // to repeat on every rebuild.
    _checkinWidgetDisabled = _resolveCheckinWidgetDisabled();
    // Live flags: always fetch checkin_context on open (never cache from login).
    _controller.initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(_controller.refreshContext());
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _openSearch() {
    setState(() => _searchOpen = true);
  }

  void _closeSearch() {
    if (!_searchOpen) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _searchOpen = false);
  }

  bool _resolveCheckinWidgetDisabled() {
    if (!SharedPref.isUserAuthenticated()) return true;
    return SharedPref.getLoginData()
            .result
            ?.data
            ?.defaultWidgets
            ?.data
            ?.checkinWidget
            ?.isDisabled ==
        true;
  }

  Future<void> _onActionComplete() async {
    // Sync and context refresh are independent; run them in parallel so the
    // screen pops back as soon as both finish.
    await Future.wait([
      AttendanceStatusSyncService.refreshFromServer(
        reason: 'checkin_activity_action',
      ),
      _controller.refreshContext(),
    ]);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onPullRefresh() => _controller.refreshContext();

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final contextModel = state.context;
    final topInset = MediaQuery.paddingOf(context).top;
    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;
    final sheetReserve = MediaQuery.sizeOf(context).height * 0.42;
    final bannerTop = topInset + 52.h;
    final topOverlay = bannerTop + 48.h;
    final showProjectBanner =
        state.selectedProject != null && !(contextModel?.remote ?? false);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.white,
        body: state.error != null && contextModel == null
            ? _ErrorBody(
                message: state.error!,
                onRetry: _controller.initialize,
              )
            : RefreshIndicator(
                onRefresh: _onPullRefresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: MediaQuery.sizeOf(context).height,
                    child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: CheckinMapSection(
                      userPosition: state.userPosition,
                      selectedProject: state.selectedProject,
                      isInsideGeofence: state.isInsideGeofence,
                      distanceMeters: state.distancePreview?.distanceM,
                      routePoints: state.routePoints,
                      routeLoading: state.routeLoading,
                      bottomOverlayPadding: sheetReserve,
                      topOverlayPadding: topOverlay,
                    ),
                  ),
                  Positioned(
                    left: 8.w,
                    top: topInset + 6.h,
                    child: _MapCircleButton(
                      icon: Icons.arrow_back,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Positioned(
                    right: 12.w,
                    top: topInset + 6.h,
                    child: _MapCircleButton(
                      icon: Icons.search,
                      onTap: _openSearch,
                    ),
                  ),
                  if (state.loading)
                    Positioned(
                      right: 56.w,
                      top: topInset + 14.h,
                      child: SizedBox(
                        width: 18.w,
                        height: 18.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  if (state.error != null)
                    Positioned(
                      left: 14.w,
                      right: 14.w,
                      top: bannerTop,
                      child: Material(
                        color: HomeGlassTheme.accentRed.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(8.r),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 8.h,
                          ),
                          child: Text(
                            state.error!,
                            style: GoogleFonts.poppins(
                              fontSize: 11.sp,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    )
                  else if (showProjectBanner)
                    Positioned(
                      left: 14.w,
                      right: 14.w,
                      top: bannerTop,
                      child: _ProjectBanner(
                        project: state.selectedProject!,
                        canOpenSearch: state.checkinProjects.length > 1,
                        onTap: _openSearch,
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: contextModel == null
                        ? Container(
                            height: 180.h,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(22.r),
                              ),
                            ),
                            child: const CircularProgressIndicator(),
                          )
                        : CheckinBottomSheet(
                            contextModel: contextModel,
                            checkinWidgetDisabled: _checkinWidgetDisabled,
                            projects: state.checkinProjects,
                            selectedProject: state.selectedProject,
                            hasGps: state.userPosition != null,
                            isInsideGeofence: state.isInsideGeofence,
                            distanceMeters: state.distancePreview?.distanceM,
                            onValidateBeforeCheckIn:
                                _controller.validateSelectedProjectLocation,
                            onActionComplete: _onActionComplete,
                            onContextRefresh: _controller.refreshContext,
                          ),
                  ),
                  if (_searchOpen) ...[
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: _closeSearch,
                        behavior: HitTestBehavior.translucent,
                        child: const SizedBox.expand(),
                      ),
                    ),
                    Positioned(
                      top: topInset + 50.h,
                      right: 12.w,
                      width: 290.w,
                      bottom: keyboardBottom > 0
                          ? keyboardBottom + 12.h
                          : sheetReserve + 12.h,
                      child: CheckinProjectSearchPanel(
                        projects: state.checkinProjects,
                        selectedProjectId: state.selectedProject?.projectId,
                        onProjectSelected: _controller.selectProject,
                        onClose: _closeSearch,
                      ),
                    ),
                  ],
                ],
              ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _ProjectBanner extends StatelessWidget {
  const _ProjectBanner({
    required this.project,
    required this.canOpenSearch,
    required this.onTap,
  });

  final CheckinAllowedProject project;
  final bool canOpenSearch;
  final VoidCallback onTap;

  static String labelFor(CheckinAllowedProject project) {
    final name = project.name.trim();
    final wo = project.woRefNo.trim();
    if (name.isEmpty && wo.isEmpty) return 'No linked location';
    if (wo.isEmpty) return name;
    if (name.isEmpty) return wo;
    return '$name · $wo';
  }

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFE67E22);
    return Material(
      color: orange.withValues(alpha: 0.14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.r),
        side: BorderSide(color: orange.withValues(alpha: 0.55), width: 1),
      ),
      child: InkWell(
        onTap: canOpenSearch ? onTap : null,
        borderRadius: BorderRadius.circular(10.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          child: TmMarqueeText(
            text: labelFor(project),
            height: 20.h,
            style: GoogleFonts.poppins(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: HomeGlassTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _MapCircleButton extends StatelessWidget {
  const _MapCircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      elevation: 3,
      shadowColor: Colors.black26,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(9.w),
          child: Icon(
            icon,
            size: 20.sp,
            color: HomeGlassTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13.sp,
                color: HomeGlassTheme.textSecondary,
              ),
            ),
            SizedBox(height: 16.h),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
