import 'dart:async';

import 'package:el_race/core/services/attendance_status_sync_service.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/data/services/auto_checkout_service.dart';
import 'package:el_race/data/services/checkin_reminder_notification_service.dart';
import 'package:el_race/ui/presentation/attendance_checkin/models/checkin_context_model.dart';
import 'package:el_race/ui/presentation/attendance_checkin/utils/checkin_sheet_logic.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_theme.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/project_list_dialog.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/timer_controller.dart';
import 'package:el_race/ui/presentation/landing_screen/bloc/checkin_in_bloc/check_in_bloc.dart';
import 'package:el_race/ui/presentation/landing_screen/bloc/checkin_out_bloc/check_out_bloc.dart';
import 'package:el_race/utils/di.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

/// Check In / Check Out buttons — same API flow as [CustomSwipeButton].
class CheckinActionButtons extends StatefulWidget {
  const CheckinActionButtons({
    super.key,
    required this.cardState,
    required this.todayStatus,
    required this.selectedProjectId,
    required this.onValidateBeforeCheckIn,
    this.onActionComplete,
    this.onContextRefresh,
  });

  final CheckinLocationCardState cardState;
  final CheckinTodayStatus todayStatus;
  final int? selectedProjectId;
  final Future<bool> Function() onValidateBeforeCheckIn;
  final VoidCallback? onActionComplete;

  /// Re-fetch checkin_context after an API error so live flags take effect.
  final VoidCallback? onContextRefresh;

  @override
  State<CheckinActionButtons> createState() => _CheckinActionButtonsState();
}

class _CheckinActionButtonsState extends State<CheckinActionButtons> {
  bool _apiLoading = false;
  bool _checkedIn = false;
  StreamSubscription<AttendanceStatusSnapshot>? _syncSub;

  @override
  void initState() {
    super.initState();
    _checkedIn = SharedPref().getPreferenceBoolean('isCheckedIn') &&
        !widget.todayStatus.checkedOut;
    _syncSub = AttendanceStatusSyncService.updates.listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _checkedIn = snapshot.checkedIn && !snapshot.checkedOut;
      });
    });
  }

  @override
  void didUpdateWidget(covariant CheckinActionButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.todayStatus != widget.todayStatus) {
      _checkedIn =
          widget.todayStatus.checkedIn && !widget.todayStatus.checkedOut;
    }
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  void _setLoading(bool value) {
    if (!mounted || _apiLoading == value) return;
    setState(() => _apiLoading = value);
  }

  Future<void> _onCheckIn() async {
    if (!CheckinSheetLogic.checkInEnabled(
      cardState: widget.cardState,
      today: widget.todayStatus,
      apiLoading: _apiLoading,
    )) {
      return;
    }

    showLeftToRightPopupClean(
      context: context,
      loginResponseModel: SharedPref.getLoginData(),
      isCheckedIn: false,
      onConfirmed: () async {
        if (widget.selectedProjectId != null) {
          await SharedPref().setPreferenceInt(
            'checkInProjectId',
            widget.selectedProjectId!,
          );
        }
        final ok = await widget.onValidateBeforeCheckIn();
        if (!ok) return;
        await _performCheckIn();
      },
      onCancelled: () {},
    );
  }

  Future<void> _onCheckOut() async {
    if (!CheckinSheetLogic.checkOutEnabled(
      cardState: widget.cardState,
      today: widget.todayStatus,
      apiLoading: _apiLoading,
    )) {
      return;
    }

    showLeftToRightPopupClean(
      context: context,
      loginResponseModel: SharedPref.getLoginData(),
      isCheckedIn: true,
      onConfirmed: () async {
        await _performCheckOut();
      },
      onCancelled: () {},
    );
  }

  Future<void> _performCheckIn() async {
    SharedPref().setPreferencesBoolean('isCheckedIn', false);
    SharedPref().setPreferenceInt('checkInRecordId', 0);
    sl.get<CheckInBloc>().add(CheckInET());
    await Get.find<TimerController>().startTimer();
    await AutoCheckoutService.scheduleAutoCheckout();
    await CheckInReminderNotificationService().updateReminders();
    if (!mounted) return;
    setState(() => _checkedIn = true);
    SharedPref().setPreferencesBoolean('isCheckedIn', true);
  }

  Future<void> _performCheckOut() async {
    final checkInRecordId = SharedPref().getPreferenceInt('checkInRecordId');
    sl.get<CheckOutBloc>().add(
          CheckOutET(checkInRecordId, isAutoCheckout: false),
        );
    await Get.find<TimerController>().stopTimer();
    await AutoCheckoutService.cancelAutoCheckout();
    SharedPref().removePreference('checkInProjectId');
    SharedPref().removePreference('checkInBranchId');
    SharedPref().removePreference('checkInAuthMethod');
    await CheckInReminderNotificationService().updateReminders();
    if (!mounted) return;
    setState(() => _checkedIn = false);
    SharedPref().setPreferencesBoolean('isCheckedIn', false);
  }

  Future<void> _restoreAfterCheckInFailure() async {
    await SharedPref().setPreferencesBoolean('isCheckedIn', false);
    await SharedPref().setPreferenceInt('checkInRecordId', 0);
    await SharedPref().setPreferencesString('checkInDisplayTime', '00:00:00');
    await CheckInReminderNotificationService().updateReminders();
    if (!mounted) return;
    setState(() => _checkedIn = false);
  }

  Future<void> _restoreAfterCheckOutFailure() async {
    await SharedPref().setPreferencesBoolean('isCheckedIn', true);
    await CheckInReminderNotificationService().updateReminders();
    if (!mounted) return;
    setState(() => _checkedIn = true);
  }

  void _showMessage({
    required String title,
    required String message,
    required Color color,
    required IconData icon,
  }) {
    if (!mounted || message.trim().isEmpty) return;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'OK',
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = widget.todayStatus;
    final checkInOn = CheckinSheetLogic.checkInEnabled(
      cardState: widget.cardState,
      today: today,
      apiLoading: _apiLoading,
    );
    final checkOutOn = CheckinSheetLogic.checkOutEnabled(
      cardState: widget.cardState,
      today: today,
      apiLoading: _apiLoading,
    );

    final lastOutLabel = _formatLastOut(today.checkOutTime);

    return MultiBlocListener(
      listeners: [
        BlocListener<CheckInBloc, CheckInState>(
          bloc: sl.get<CheckInBloc>(),
          listener: (context, state) async {
            if (state is CheckInLoadingST) {
              _setLoading(state.isLoading);
            } else if (state is CheckedInST) {
              _setLoading(false);
              widget.onActionComplete?.call();
              _showMessage(
                title: 'Check-In Success',
                message: state.message,
                color: const Color(0xFF28A745),
                icon: Icons.check_circle,
              );
            } else if (state is CheckInWarningST) {
              _setLoading(false);
              widget.onActionComplete?.call();
              _showMessage(
                title: 'Check-In Warning',
                message: state.warningMessage,
                color: const Color(0xFFFFA000),
                icon: Icons.warning,
              );
            } else if (state is CheckInErrorST) {
              _setLoading(false);
              await _restoreAfterCheckInFailure();
              widget.onContextRefresh?.call();
              _showMessage(
                title: 'Check-In Failed',
                message: state.errorMessage,
                color: const Color(0xFFDC3545),
                icon: Icons.error,
              );
            } else if (state is CheckInBlockedST) {
              _setLoading(false);
              widget.onContextRefresh?.call();
              final timeStr =
                  '${state.currentDubaiTime.hour.toString().padLeft(2, '0')}:${state.currentDubaiTime.minute.toString().padLeft(2, '0')}';
              _showMessage(
                title: 'ACTION BLOCKED',
                message: 'check in is not available\nCurrent time: $timeStr',
                color: const Color(0xFFD32F2F),
                icon: Icons.block,
              );
            }
          },
        ),
        BlocListener<CheckOutBloc, CheckOutState>(
          bloc: sl.get<CheckOutBloc>(),
          listener: (context, state) async {
            if (state is CheckOutLoadingST) {
              _setLoading(state.isLoading);
            } else if (state is CheckedOutST) {
              _setLoading(false);
              widget.onActionComplete?.call();
              _showMessage(
                title: 'Check-Out Success',
                message: state.message,
                color: const Color(0xFF28A745),
                icon: Icons.check_circle,
              );
            } else if (state is CheckOutWarningST) {
              _setLoading(false);
              widget.onActionComplete?.call();
              _showMessage(
                title: 'Check-Out Warning',
                message: state.warningMessage,
                color: const Color(0xFFFFA000),
                icon: Icons.warning,
              );
            } else if (state is CheckOutErrorST) {
              _setLoading(false);
              await _restoreAfterCheckOutFailure();
              widget.onContextRefresh?.call();
              _showMessage(
                title: 'Check-Out Error',
                message: state.errorMessage,
                color: const Color(0xFFDC3545),
                icon: Icons.error,
              );
            }
          },
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Check In',
                  icon: Icons.login,
                  background: HomeGlassTheme.bottleGreen,
                  enabled: checkInOn,
                  loading: _apiLoading && !_checkedIn,
                  onTap: _onCheckIn,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ActionButton(
                      label: 'Check Out',
                      icon: Icons.logout,
                      background: const Color(0xFF1B2A4A),
                      enabled: checkOutOn,
                      loading: _apiLoading && today.canCheckOut,
                      onTap: _onCheckOut,
                    ),
                    if (today.checkedOut && lastOutLabel != null) ...[
                      SizedBox(height: 4.h),
                      Text(
                        'Last out $lastOutLabel',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                          color: HomeGlassTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String? _formatLastOut(String? raw) {
    if (raw == null || raw.isEmpty || raw == '00:00:00' || raw == '--:--') {
      return null;
    }
    final parts = raw.split(':');
    if (parts.length >= 2) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }
    return raw;
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color background;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12.r);
    final opacity = enabled ? 1.0 : 0.40;
    return Opacity(
      opacity: opacity,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: enabled && !loading ? onTap : null,
          borderRadius: radius,
          child: Ink(
            height: 50.h,
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  background,
                  Color.lerp(background, Colors.black, 0.12)!,
                ],
              ),
            ),
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, color: Colors.white, size: 22.sp),
                        SizedBox(width: 6.w),
                        Text(
                          label,
                          style: GoogleFonts.poppins(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
