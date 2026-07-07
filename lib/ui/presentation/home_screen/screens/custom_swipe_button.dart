import 'dart:async';
import 'dart:math' as math;
import 'package:el_race/core/services/attendance_status_sync_service.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/data/services/auto_checkout_service.dart';
import 'package:el_race/data/services/checkin_reminder_notification_service.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_theme.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/project_list_dialog.dart';
import 'package:el_race/ui/presentation/landing_screen/bloc/checkin_in_bloc/check_in_bloc.dart';
import 'package:el_race/ui/presentation/landing_screen/bloc/checkin_out_bloc/check_out_bloc.dart';
import 'package:el_race/utils/di.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';
import 'package:el_race/core/services/app_config_service.dart';
import 'package:google_fonts/google_fonts.dart' show GoogleFonts;
import 'package:el_race/core/biometric/unified_biometric_helper.dart';

import '../widgets/timer_controller.dart';

class CustomSwipeButton extends StatefulWidget {
  const CustomSwipeButton({
    super.key,
    this.onActionComplete,
    this.trackWidth,
    this.compactStyle = false,
    this.midSectionLayout = false,
    this.swipeEnabled = true,
    this.selectedProjectId,
    this.onValidateBeforeCheckIn,
  });

  /// Fired after a successful check-in or check-out swipe flow completes.
  final VoidCallback? onActionComplete;

  /// When set (e.g. mid-section), the swipe track uses this width instead of [300.w].
  final double? trackWidth;

  /// Lighter styling for legacy compact embeds.
  final bool compactStyle;

  /// Home mid-section: premium track, no legacy timeline (use [HomeMidAttendanceTimes]).
  final bool midSectionLayout;

  /// When false, swipe interaction is disabled (e.g. BioTime office staff).
  final bool swipeEnabled;

  /// Project selected on the check-in map activity (stored for display).
  final int? selectedProjectId;

  /// Called before check-in biometric/API flow; return false to abort.
  final Future<bool> Function()? onValidateBeforeCheckIn;

  @override
  State<CustomSwipeButton> createState() => CustomSwipeButtonState();
}

class CustomSwipeButtonState extends State<CustomSwipeButton>
    with TickerProviderStateMixin {
  bool isCheckedIn = false;
  double dragOffset = 0.0;
  bool isDragging = false;
  bool _isVisualCheckedIn = false; // Visual state for transitions
  late AnimationController _arrowController;
  bool? matchResult; // null = no result, true = matched, false = not matched
  late AnimationController _checkmarkController;
  late AnimationController _bounceController;
  bool isProcessingFace = false;
  bool _isApiLoading = false;
  Timer? _sliderClockTimer;

  // Time display variables - updated via BlocListener
  String _checkInDisplayTime = '00:00:00';
  String _checkOutDisplayTime = '00:00:00';
  String _totalHoursDisplay = '00:00';

  // Timer للعداد التصاعدي
  Timer? _liveTimer;
  StreamSubscription<AttendanceStatusSnapshot>? _attendanceSyncSubscription;

  final double buttonHeight = 48.w; // Reduced from 56.w to 48.w for shorter bar
  final double knobSize =
      35.w; // Reduced from 40.w to 35.w to maintain proportion

  double get buttonWidth => widget.trackWidth ?? 300.w;

  double get _trackH => widget.midSectionLayout ? 44.h : buttonHeight;

  double get _midTrackPad => widget.midSectionLayout ? 4.0 : 0.0;

  /// Thumb fits inside track height (not too small/large).
  double get _knob => widget.midSectionLayout
      ? (_trackH - _midTrackPad * 2)
      : knobSize;

  double get _maxDragOffset =>
      math.max(0, buttonWidth - _knob - _midTrackPad);

  /// Done for today: has both times and is not in an active check-in session.
  bool _hasCompletedAttendanceToday() {
    if (isCheckedIn) return false;
    return _isValidAttendanceTime(_checkInDisplayTime) &&
        _isValidAttendanceTime(_checkOutDisplayTime);
  }

  DateTime _dubaiNow() =>
      DateTime.now().toUtc().add(const Duration(hours: 4));

  bool _hasCheckInDataToday() =>
      _isValidAttendanceTime(_checkInDisplayTime);

  /// Check-out swipe allowed from 4:30 PM Dubai.
  bool _isCheckOutAllowedByTime() {
    final now = _dubaiNow();
    return now.hour > 16 || (now.hour == 16 && now.minute >= 30);
  }

  bool _isCheckedInLockedUntilCheckout() =>
      isCheckedIn && _hasCheckInDataToday() && !_isCheckOutAllowedByTime();

  bool _isSliderInteractionDisabled() =>
      !widget.swipeEnabled ||
      _isApiLoading ||
      _hasCompletedAttendanceToday() ||
      _isCheckedInLockedUntilCheckout();

  void _notifyActionComplete() {
    widget.onActionComplete?.call();
  }

  void _resetPosition() {
    setState(() {
      _applyDragOffsetForCheckInState();
      isDragging = false;
      startSwipe = false;
    });
  }

  void _applyDragOffsetForCheckInState() {
    final max = _maxDragOffset;
    dragOffset = isCheckedIn && max > 0 ? max : 0;
    _isVisualCheckedIn = isCheckedIn;
  }

  void _startSliderClockTimer() {
    _sliderClockTimer?.cancel();
    _sliderClockTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      if (isCheckedIn || _hasCompletedAttendanceToday()) {
        setState(() {});
      }
    });
  }

  /// Called when mid attendance panel opens — syncs thumb with server/local check-in.
  void syncFromAttendance() {
    _loadDisplayTimes();
    _loadCheckInState();
  }

  static bool _isValidAttendanceTime(String raw) =>
      raw.isNotEmpty && raw != '00:00:00' && raw != '--:--';

  /// Active session — server/prefs `isCheckedIn` is the source of truth.
  bool _resolveCheckedInState() =>
      SharedPref().getPreferenceBoolean('isCheckedIn');

  void _applyAttendanceSnapshot(AttendanceStatusSnapshot snapshot) {
    isCheckedIn = snapshot.checkedIn && !snapshot.checkedOut;
    _checkInDisplayTime = snapshot.checkInDisplayTime;
    _checkOutDisplayTime = snapshot.checkOutDisplayTime;
    _applyDragOffsetForCheckInState();
  }

  @override
  void didUpdateWidget(CustomSwipeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trackWidth != widget.trackWidth && !isDragging) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !isDragging) {
          setState(_applyDragOffsetForCheckInState);
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // IMPORTANT: Load display times FIRST so _checkInDisplayTime has a value
    // before _loadCheckInState starts the live timer calculation.
    _loadDisplayTimes();
    _loadCheckInState();
    _attendanceSyncSubscription = AttendanceStatusSyncService.updates.listen(
      (snapshot) {
        if (!mounted) return;

        _loadDisplayTimes();
        setState(() => _applyAttendanceSnapshot(snapshot));

        if (snapshot.checkedIn && !snapshot.checkedOut) {
          _startLiveTimer();
        } else {
          _stopLiveTimer();
        }
      },
    );

    // Mid-section sync is triggered when the attendance panel opens.
    if (!widget.midSectionLayout) {
      AttendanceStatusSyncService.refreshFromServer(reason: 'widget_init');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(_applyDragOffsetForCheckInState);
      }
    });
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _checkmarkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Forward movement animation controller
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    if (!AppConfigService.instance.isTestMode) {
      if (mounted) {
        _bounceController.repeat(reverse: true);
      }
    }
    _startSliderClockTimer();
  }

  /// Load display times from SharedPref
  void _loadDisplayTimes() {
    final checkIn = SharedPref().getPreferenceString('checkInDisplayTime');
    final checkOut = SharedPref().getPreferenceString('checkOutDisplayTime');

    // print('\n⏰ ===== LOADING DISPLAY TIMES =====');
    // print('⏰ Reading from SharedPref:');
    // print('⏰   checkInDisplayTime = "$checkIn"');
    // print('⏰   checkOutDisplayTime = "$checkOut"');

    setState(() {
      _checkInDisplayTime =
          (checkIn.isEmpty || checkIn == '--:--') ? '00:00:00' : checkIn;
      _checkOutDisplayTime =
          (checkOut.isEmpty || checkOut == '--:--') ? '00:00:00' : checkOut;
      _calculateTotalHours();
      _applyDragOffsetForCheckInState();
    });

    // print('⏰ After setState:');
    // print('⏰   _checkInDisplayTime (GREEN/LEFT) = $_checkInDisplayTime');
    // print('⏰   _checkOutDisplayTime (RED/RIGHT) = $_checkOutDisplayTime');
    // print('⏰ ===================================\n');
  }

  /// Calculate total hours between check-in and check-out
  void _calculateTotalHours() {
    if (_checkInDisplayTime == '00:00:00' ||
        _checkOutDisplayTime == '00:00:00') {
      _totalHoursDisplay = '00:00';
      return;
    }

    try {
      // Parse times (format: HH:mm:ss)
      final checkInParts = _checkInDisplayTime.split(':');
      final checkOutParts = _checkOutDisplayTime.split(':');

      if (checkInParts.length >= 2 && checkOutParts.length >= 2) {
        final checkInMinutes =
            int.parse(checkInParts[0]) * 60 + int.parse(checkInParts[1]);
        final checkOutMinutes =
            int.parse(checkOutParts[0]) * 60 + int.parse(checkOutParts[1]);

        int totalMinutes = checkOutMinutes - checkInMinutes;
        if (totalMinutes < 0) {
          totalMinutes += 24 * 60; // Handle crossing midnight
        }

        final hours = totalMinutes ~/ 60;
        final minutes = totalMinutes % 60;

        _totalHoursDisplay =
            '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      _totalHoursDisplay = '00:00';
    }
  }

  /// حساب الوقت التصاعدي من check-in حتى الآن
  void _calculateLiveTotalHours() {
    if (_checkInDisplayTime == '00:00:00') {
      _totalHoursDisplay = '00:00';
      return;
    }

    try {
      // Parse check-in time (format: HH:mm:ss)
      final checkInParts = _checkInDisplayTime.split(':');
      if (checkInParts.length >= 2) {
        final checkInMinutes =
            int.parse(checkInParts[0]) * 60 + int.parse(checkInParts[1]);

        // Get current Dubai time
        final now = DateTime.now().toUtc().add(const Duration(hours: 4));
        final currentMinutes = now.hour * 60 + now.minute;

        int totalMinutes = currentMinutes - checkInMinutes;
        if (totalMinutes < 0) {
          totalMinutes += 24 * 60; // Handle crossing midnight
        }

        final hours = totalMinutes ~/ 60;
        final minutes = totalMinutes % 60;

        _totalHoursDisplay =
            '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      _totalHoursDisplay = '00:00';
    }
  }

  /// بدء العداد التصاعدي
  void _startLiveTimer() {
    _liveTimer?.cancel();
    // Update every second so the display is always current
    _liveTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && isCheckedIn) {
        setState(() {
          _calculateLiveTotalHours();
        });
      } else {
        timer.cancel();
      }
    });
    // Update immediately on the first frame
    setState(() {
      _calculateLiveTotalHours();
    });
  }

  /// إيقاف العداد التصاعدي
  void _stopLiveTimer() {
    _liveTimer?.cancel();
    _liveTimer = null;
  }

  /// التحقق من أن الوقت الحالي ضمن فترة السماح بـ Check-in
  /// Check-in مسموح من 5:00 AM حتى 11:59 AM بتوقيت دبي
  bool _isCheckInAllowed() {
    final dubaiTime = DateTime.now().toUtc().add(const Duration(hours: 4));
    // Check-in مسموح من الساعة 5 صباحاً حتى 11:59 صباحاً
    if (dubaiTime.hour >= 5 && dubaiTime.hour < 12) {
      return true;
    }
    return false;
  }

  /// الحصول على الوقت الحالي بتوقيت دبي
  DateTime _getDubaiTime() {
    return DateTime.now().toUtc().add(const Duration(hours: 4));
  }

  @override
  void dispose() {
    _sliderClockTimer?.cancel();
    _liveTimer?.cancel();
    _attendanceSyncSubscription?.cancel();
    _arrowController.dispose();
    _checkmarkController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  bool _shouldResetForDubai5Am(bool storedCheckedIn) {
    if (!storedCheckedIn) return false;
    final checkInTime = SharedPref().getPreferenceInt('checkInTime');
    if (checkInTime == 0) return false;

    final checkInDubaiTime = DateTime.fromMillisecondsSinceEpoch(checkInTime)
        .toUtc()
        .add(const Duration(hours: 4));
    final dubaiNow = DateTime.now().toUtc().add(const Duration(hours: 4));

    final DateTime lastResetTime;
    if (dubaiNow.hour >= 5) {
      lastResetTime =
          DateTime(dubaiNow.year, dubaiNow.month, dubaiNow.day, 5, 0);
    } else {
      final yesterday = dubaiNow.subtract(const Duration(days: 1));
      lastResetTime =
          DateTime(yesterday.year, yesterday.month, yesterday.day, 5, 0);
    }

    return checkInDubaiTime.isBefore(lastResetTime);
  }

  Future<void> _clearLocalCheckInAfter5AmReset() async {
    await SharedPref().setPreferencesBoolean('isCheckedIn', false);
    await SharedPref().setPreferenceInt('checkInRecordId', 0);
    await SharedPref().setPreferencesString('checkInDisplayTime', '00:00:00');
    await SharedPref().setPreferencesString('checkOutDisplayTime', '00:00:00');
    await SharedPref().removePreference('checkInProjectId');
    await SharedPref().removePreference('checkInBranchId');
    await SharedPref().removePreference('checkInAuthMethod');
    await SharedPref().setPreferenceInt('checkInTime', 0);
    await SharedPref().setPreferenceInt('lastLocalCheckOutTime', 0);
    await CheckInReminderNotificationService().updateReminders();
    _stopLiveTimer();
  }

  _loadCheckInState() {
    final storedState = SharedPref().getPreferenceBoolean('isCheckedIn');

    if (_shouldResetForDubai5Am(storedState)) {
      _clearLocalCheckInAfter5AmReset();
      if (!mounted) return;
      setState(() {
        isCheckedIn = false;
        _isVisualCheckedIn = false;
        dragOffset = 0;
        _checkInDisplayTime = '00:00:00';
        _checkOutDisplayTime = '00:00:00';
        _totalHoursDisplay = '00:00';
      });
      return;
    }

    setState(() {
      isCheckedIn = _resolveCheckedInState();
      _applyDragOffsetForCheckInState();
    });

    // بدء العداد إذا كان checked in
    if (isCheckedIn && _checkOutDisplayTime == '00:00:00') {
      _startLiveTimer();
    }
  }

  void animateTo(double target, VoidCallback onComplete) {
    final controller = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: widget.midSectionLayout ? 160 : 300,
      ),
    );

    late Animation<double> animation;
    animation =
        Tween<double>(begin: dragOffset, end: target).animate(controller);

    animation.addListener(() {
      setState(() {
        dragOffset = animation.value;
        if (dragOffset < 2.0) {
          startSwipe = false;
        }
        // Update visual state based on animation progress
        if (widget.midSectionLayout) {
          _updateMidVisualFromDrag();
        } else {
          final progress = dragOffset / (buttonWidth - _knob);
          _isVisualCheckedIn = progress > 0.5;
        }
      });
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        onComplete();
        controller.dispose();
      }
    });

    controller.forward();
  }

  bool startSwipe = false;

  void _showCheckInNotAvailablePopup({String? currentTime}) {
    final message = currentTime == null || currentTime.isEmpty
        ? 'check in is not available'
        : 'check in is not available\nCurrent time: $currentTime';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF5F5), Color(0xFFFFEBEE)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD32F2F),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.block,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'ACTION BLOCKED',
                  style: TextStyle(
                    color: Color(0xFFB71C1C),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF3A3A3A),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAttendanceApiMessage({
    required String title,
    required String message,
    required Color color,
    required IconData icon,
  }) {
    if (!mounted || message.trim().isEmpty) return;

    final normalizedMessage = message.replaceAll(RegExp(r'\s+'), ' ').trim();
    final messageHeader = _attendanceMessageHeader(normalizedMessage);
    final messageItems = _attendanceMessageItems(normalizedMessage);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
          content: SizedBox(
            width: 320,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(dialogContext).size.height * 0.42,
              ),
              child: Scrollbar(
                thumbVisibility: messageItems.length > 6,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        messageHeader,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          color: Color(0xFF303030),
                        ),
                      ),
                      if (messageItems.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ...messageItems.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Text(
                                    '•',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                      height: 1.35,
                                      color: Color(0xFF3A3A3A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'OK',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _setApiLoading(bool isLoading) {
    if (!mounted || _isApiLoading == isLoading) return;
    setState(() {
      _isApiLoading = isLoading;
    });
  }

  String _attendanceMessageHeader(String message) {
    final colonIndex = message.indexOf(':');
    if (colonIndex > 0) {
      final header = message.substring(0, colonIndex + 1).trim();
      final hasListAfterColon =
          message.substring(colonIndex + 1).contains(RegExp(r'[,،]\s*'));
      return hasListAfterColon ? header : message;
    }

    final commaParts = message
        .split(RegExp(r'[,،]\s*'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (commaParts.length >= 3) {
      final firstPart = _sanitizeAttendanceText(commaParts.first);
      if (firstPart.endsWith(':')) return firstPart;
      return '$firstPart:';
    }

    return _sanitizeAttendanceText(message);
  }

  List<String> _attendanceMessageItems(String message) {
    final colonIndex = message.indexOf(':');
    if (colonIndex > 0) {
      final tail = message.substring(colonIndex + 1).trim();
      if (!tail.contains(RegExp(r'[,،]\s*'))) return const [];

      final items = tail
          .split(RegExp(r'[,،]\s*'))
          .map((item) => _sanitizeAttendanceText(item))
          .where((item) => item.isNotEmpty)
          .toList();

      return items.length > 1 ? items : const [];
    }

    final parts = message
        .split(RegExp(r'[,،]\s*'))
      .map((part) => _sanitizeAttendanceText(part))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.length < 3) return const [];

    final items = parts.sublist(1);

    return items.length > 1 ? items : const [];
  }

  String _sanitizeAttendanceText(String text) {
    return text
        .trim()
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  Future<void> _restoreAfterCheckInFailure() async {
    await SharedPref().setPreferencesBoolean('isCheckedIn', false);
    await SharedPref().setPreferenceInt('checkInRecordId', 0);
    await SharedPref().setPreferencesString('checkInDisplayTime', '00:00:00');
    await Get.find<TimerController>().stopTimer();
    await AutoCheckoutService.cancelAutoCheckout();
    await CheckInReminderNotificationService().updateReminders();
    _stopLiveTimer();

    if (!mounted) return;
    setState(() {
      isCheckedIn = false;
      _isVisualCheckedIn = false;
      dragOffset = 0;
      _checkInDisplayTime = '00:00:00';
      _totalHoursDisplay = '00:00';
      startSwipe = false;
    });
  }

  Future<void> _restoreAfterCheckOutFailure() async {
    await SharedPref().setPreferencesBoolean('isCheckedIn', true);
    await Get.find<TimerController>().startTimer();
    await AutoCheckoutService.scheduleAutoCheckout();
    await CheckInReminderNotificationService().updateReminders();
    _startLiveTimer();

    if (!mounted) return;
    setState(() {
      isCheckedIn = true;
      _isVisualCheckedIn = true;
      dragOffset = _maxDragOffset;
      startSwipe = false;
    });
  }

  void _updateMidVisualFromDrag() {
    final max = _maxDragOffset;
    if (max <= 0) return;
    final progress = dragOffset / max;
    if (isCheckedIn) {
      _isVisualCheckedIn = progress > 0.45;
    } else {
      _isVisualCheckedIn = progress > 0.55;
    }
  }

  void _startAttendanceAction() {
    SharedPref()
        .setPreferencesBoolean('wasCheckedInBeforeFaceAuth', isCheckedIn);
    SharedPref().setPreferencesBoolean('isCheckedIn', isCheckedIn);
    if (!isCheckedIn) SharedPref().setPreferenceInt('checkInRecordId', 0);

    showLeftToRightPopupClean(
      context: context,
      loginResponseModel: SharedPref.getLoginData(),
      isCheckedIn: isCheckedIn,
      onConfirmed: () async {
        if (!isCheckedIn) {
          if (widget.selectedProjectId != null) {
            await SharedPref().setPreferenceInt(
              'checkInProjectId',
              widget.selectedProjectId!,
            );
          }
          if (widget.onValidateBeforeCheckIn != null) {
            final ok = await widget.onValidateBeforeCheckIn!();
            if (!ok) {
              _resetPosition();
              return;
            }
          }
        }

        if (AppConfigService.instance.shouldSkipFaceId) {
          _performCheckInOut();
          _resetPosition();
          return;
        }

        final authenticated =
            await UnifiedBiometricHelper.authenticateForAttendance(context);

        if (authenticated) {
          _performCheckInOut();
          _resetPosition();
        } else {
          _resetPosition();
        }
      },
      onCancelled: _resetPosition,
    );
  }

  void _onDragEnd() async {
    if (_isSliderInteractionDisabled()) {
      _resetPosition();
      return;
    }
    setState(() => isDragging = false);
    final max = buttonWidth - _knob;
    final threshold = buttonWidth * 0.6;
    if ((!isCheckedIn && dragOffset >= threshold) ||
        (isCheckedIn && dragOffset <= (max - threshold))) {
      final targetOffset = isCheckedIn ? 0.0 : max;
      animateTo(targetOffset, _startAttendanceAction);
    } else {
      animateTo(isCheckedIn ? max : 0.0, () {
        if (mounted) setState(_applyDragOffsetForCheckInState);
      });
    }
  }

  /// Perform check-in or check-out action
  ///
  /// Note: Check-in/Check-out is global and unified
  /// - Timer applies to all projects (8 hours fixed)
  /// - Project selection is for display/reference only
  /// - Detailed time management handled via job missions
  ///
  /// NOTE: The 8 working hours are global and shared across all projects.
  ///       Switching projects does NOT reset or create a new timer.
  void _performCheckInOut() async {
    if (!isCheckedIn) {
      // Perform global check-in
      sl.get<CheckInBloc>().add(CheckInET());
      // await startTimer to guarantee isCheckedIn=true is persisted
      // BEFORE updateReminders() reads SharedPref
      await Get.find<TimerController>().startTimer();

      // جدولة Auto Check-out في الساعة 5:10 مساءً
      await AutoCheckoutService.scheduleAutoCheckout();
      // debugPrint('✅ Auto checkout scheduled for 5:10 PM after check-in');

      // جدولة إشعارات التذكير بـ check out (من 4 مساءً - 5 مساءً)
      await CheckInReminderNotificationService().updateReminders();
      // debugPrint('✅ Check-out reminder notifications scheduled');
    } else {
      // Perform global check-out (manual)
      final checkInRecordId = SharedPref().getPreferenceInt('checkInRecordId');
      print(
          '🔴 _performCheckInOut: CHECK-OUT requested, checkInRecordId=$checkInRecordId');
      if (checkInRecordId == 0) {
        print(
            '⚠️ _performCheckInOut: checkInRecordId is 0! Sending anyway — backend should resolve.');
      }
      sl
          .get<CheckOutBloc>()
          .add(CheckOutET(checkInRecordId, isAutoCheckout: false));
      // await stopTimer to guarantee isCheckedIn=false is persisted
      // BEFORE updateReminders() reads SharedPref
      await Get.find<TimerController>().stopTimer();

      // إلغاء جدولة Auto Check-out عند Check-out اليدوي
      await AutoCheckoutService.cancelAutoCheckout();
      // debugPrint('✅ Auto checkout cancelled after manual check-out');

      // Clear saved check-in project (used for display only)
      SharedPref().removePreference('checkInProjectId');
      SharedPref().removePreference('checkInBranchId');
      SharedPref().removePreference('checkInAuthMethod');

      // تحديث الإشعارات لجدولة تذكيرات check in (من 8 صباحاً - 9 صباحاً)
      await CheckInReminderNotificationService().updateReminders();
      // debugPrint('✅ Check-in reminder notifications scheduled');
    }

    setState(() {
      isCheckedIn = !isCheckedIn;
      _applyDragOffsetForCheckInState();
    });
    SharedPref().setPreferencesBoolean('isCheckedIn', isCheckedIn);
  }

  Widget _buildSwipeLabels({
    required Color textColor,
    required double fontSize,
    double filledProgress = 0,
    Color? labelOnFill,
    Color? labelOnTrack,
  }) {
    if (_isCheckedInLockedUntilCheckout()) {
      return Center(
        child: Text(
          translate('custom_swipe_button.already_checked_in'),
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      );
    }

    if (_hasCompletedAttendanceToday()) {
      return Center(
        child: Text(
          translate('custom_swipe_button.checked_out_today'),
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      );
    }

    final progress = filledProgress > 0
        ? filledProgress
        : (dragOffset / (buttonWidth - _knob)).clamp(0.0, 1.0);
    final onFill = labelOnFill ?? textColor;
    final onTrack = labelOnTrack ?? textColor;

    Widget label(String key, double opacity, bool useFillColor) {
      return Opacity(
        opacity: opacity,
        child: Text(
          translate(key),
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: useFillColor ? onFill : onTrack,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      );
    }

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          label(
            'custom_swipe_button.swipe_to_check_in',
            _isVisualCheckedIn ? 0.0 : 1.0 - progress,
            progress > 0.35,
          ),
          label(
            'custom_swipe_button.swipe_to_check_out',
            _isVisualCheckedIn ? 1.0 : progress,
            _isVisualCheckedIn || progress > 0.55,
          ),
        ],
      ),
    );
  }

  Widget _buildClassicTrack() {
    final labelFontSize = widget.midSectionLayout ? 11.sp : 18.sp;
    final labelColor = widget.midSectionLayout
        ? HomeGlassTheme.textPrimary
        : const Color(0xFF151544);
    final trackRadius =
        widget.midSectionLayout ? _trackH / 2 : 40.0;
    return Container(
      width: buttonWidth,
      height: _trackH,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(trackRadius),
        color: const Color(0xFFFFFFFF),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(trackRadius),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            _buildSwipeLabels(
              textColor: labelColor,
              fontSize: labelFontSize,
            ),
            Positioned(
              left: _isVisualCheckedIn ? null : dragOffset + 2,
              right: _isVisualCheckedIn
                  ? (buttonWidth - dragOffset - _knob)
                  : null,
              top: (_trackH - 36.88) / 2,
              child: Builder(
                builder: (context) {
                  final progress =
                      (dragOffset / (buttonWidth - _knob)).clamp(0.0, 1.0);
                  double opacity;
                  double scaleX;
                  if (progress <= 0.5) {
                    opacity = 1.0 - (progress * 2);
                    scaleX = 1.0 - (progress * 2);
                  } else {
                    opacity = (progress - 0.5) * 2;
                    scaleX = (progress - 0.5) * 2;
                  }
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, anim) =>
                        FadeTransition(opacity: anim, child: child),
                    child: Transform(
                      transform: Matrix4.identity()..scale(scaleX, 1.0),
                      alignment: Alignment.center,
                      child: Opacity(
                        opacity: opacity,
                        child: Transform.flip(
                          key: ValueKey(_isVisualCheckedIn),
                          flipX: _isVisualCheckedIn,
                          child: ColorFiltered(
                            colorFilter: ColorFilter.mode(
                              _isVisualCheckedIn
                                  ? const Color(0xFF81819d)
                                  : const Color(0xFF848484),
                              BlendMode.srcIn,
                            ),
                            child: Image.asset(
                              'assets/gif/arrow_animation.gif',
                              width: 50,
                              height: 36.88,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              left: dragOffset,
              top: (_trackH - _knob) / 2,
              child: Container(
                width: _knob,
                height: _knob,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(_knob / 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (_isSliderInteractionDisabled()) return;
    setState(() => isDragging = true);
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_isSliderInteractionDisabled() || !isDragging) return;

    setState(() {
      dragOffset += details.delta.dx;
      dragOffset = dragOffset.clamp(0.0, buttonWidth - _knob);
      final progress = dragOffset / (buttonWidth - _knob);
      if (dragOffset > 2.0) {
        startSwipe = true;
        if (progress > 0.5) {
          if (_isVisualCheckedIn != !isCheckedIn) {
            _isVisualCheckedIn = !isCheckedIn;
            HapticFeedback.lightImpact();
          }
        } else if (_isVisualCheckedIn != isCheckedIn) {
          _isVisualCheckedIn = isCheckedIn;
        }
      } else {
        startSwipe = false;
        if (_isVisualCheckedIn != isCheckedIn) {
          _isVisualCheckedIn = isCheckedIn;
        }
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails _) {
    if (!isDragging) return;
    setState(() => isDragging = false);
    if (_isSliderInteractionDisabled()) {
      _resetPosition();
      return;
    }
    _onDragEnd();
  }

  Widget _buildSwipeGesture() {
    final disabled = _isSliderInteractionDisabled();
    final track = RepaintBoundary(
      child: SizedBox(
        width: buttonWidth,
        height: _trackH,
        child: _buildClassicTrack(),
      ),
    );

    return SizedBox(
      width: buttonWidth,
      height: widget.midSectionLayout ? 52.h : _trackH,
      child: Center(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onHorizontalDragStart: disabled ? null : _onHorizontalDragStart,
          onHorizontalDragUpdate: disabled ? null : _onHorizontalDragUpdate,
          onHorizontalDragEnd: disabled ? null : _onHorizontalDragEnd,
          child: Opacity(
            opacity: disabled ? 0.55 : 1,
            child: track,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final labelColor =
        widget.compactStyle ? const Color(0xFF1B2A4A) : Colors.white;

    return MultiBlocListener(
      listeners: [
        // Listen to CheckInBloc to update time display after successful check-in
        BlocListener<CheckInBloc, CheckInState>(
          bloc: sl.get<CheckInBloc>(),
          listener: (context, state) async {
            if (state is CheckInLoadingST) {
              if (state.isLoading) {
                _setApiLoading(true);
              } else {
                _setApiLoading(false);
              }
            } else if (state is CheckedInST) {
              _setApiLoading(false);
              _loadDisplayTimes();
              _startLiveTimer();
              _notifyActionComplete();
              _showAttendanceApiMessage(
                title: 'Check-In Success',
                message: state.message,
                color: const Color(0xFF28A745),
                icon: Icons.check_circle,
              );
            } else if (state is CheckInWarningST) {
              _setApiLoading(false);
              _loadDisplayTimes();
              _startLiveTimer();
              _notifyActionComplete();
              _showAttendanceApiMessage(
                title: 'Check-In Warning',
                message: state.warningMessage,
                color: const Color(0xFFFFA000),
                icon: Icons.warning,
              );
            } else if (state is CheckInErrorST) {
              _setApiLoading(false);
              await _restoreAfterCheckInFailure();
              _showAttendanceApiMessage(
                title: 'Invalid Project Location',
                message: state.errorMessage,
                color: const Color(0xFFDC3545),
                icon: Icons.error,
              );
            } else if (state is CheckInBlockedST) {
              _setApiLoading(false);
              // Check-in is blocked due to time restriction (after 11:59 AM)
              _resetPosition();
              final timeStr =
                  '${state.currentDubaiTime.hour.toString().padLeft(2, '0')}:${state.currentDubaiTime.minute.toString().padLeft(2, '0')}';
              _showCheckInNotAvailablePopup(currentTime: timeStr);
            }
          },
        ),
        // Listen to CheckOutBloc to update time display after successful check-out
        BlocListener<CheckOutBloc, CheckOutState>(
          bloc: sl.get<CheckOutBloc>(),
          listener: (context, state) async {
            if (state is CheckOutLoadingST) {
              if (state.isLoading) {
                _setApiLoading(true);
              } else {
                _setApiLoading(false);
              }
            } else if (state is CheckedOutST) {
              _setApiLoading(false);
              _loadDisplayTimes();
              _stopLiveTimer();
              _notifyActionComplete();
              _showAttendanceApiMessage(
                title: 'Check-Out Success',
                message: state.message,
                color: const Color(0xFF28A745),
                icon: Icons.check_circle,
              );
            } else if (state is CheckOutWarningST) {
              _setApiLoading(false);
              _loadDisplayTimes();
              _stopLiveTimer();
              _notifyActionComplete();
              _showAttendanceApiMessage(
                title: 'Check-Out Warning',
                message: state.warningMessage,
                color: const Color(0xFFFFA000),
                icon: Icons.warning,
              );
            } else if (state is CheckOutErrorST) {
              _setApiLoading(false);
              await _restoreAfterCheckOutFailure();
              _showAttendanceApiMessage(
                title: 'Check-Out Error',
                message: state.errorMessage,
                color: const Color(0xFFDC3545),
                icon: Icons.error,
              );
            }
          },
        ),
      ],
      child: widget.midSectionLayout
          ? _buildSwipeGesture()
          : Stack( // legacy home widget embed with times row
        children: [
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Finger animation GIF on top left (behind swipe)
                if (!widget.compactStyle && !widget.midSectionLayout)
                  Positioned(
                  left: -80,
                  top: -80,
                  child: Opacity(
                    opacity: 0.4,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomRight: Radius.circular(23),
                      ),
                      child: Image.asset(
                        'assets/gif/finger-print.gif',
                        width: 150,
                        height: 160,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSwipeGesture(),
                    if (!widget.midSectionLayout) ...[
                      SizedBox(height: 24.h),
                      SizedBox(
                        width: buttonWidth,
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _checkInDisplayTime,
                                  style: GoogleFonts.poppins(
                                    color: labelColor,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  _checkOutDisplayTime,
                                  style: GoogleFonts.poppins(
                                    color: labelColor,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8.h),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 25.w),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Image.asset(
                                          'assets/newapp/row.png',
                                          height: 3,
                                          fit: BoxFit.fill,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Image.asset(
                                        'assets/newapp/left.png',
                                        width: 10.w,
                                        height: 15.w,
                                      ),
                                      Image.asset(
                                        'assets/newapp/right.png',
                                        width: 10.w,
                                        height: 15.w,
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
                  ],
                ),
              ],
            ),
          ),
          if (_isApiLoading && !widget.midSectionLayout)
            const Positioned.fill(
              child: AbsorbPointer(
                absorbing: true,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
          ],
      ),
    );
  }
}
