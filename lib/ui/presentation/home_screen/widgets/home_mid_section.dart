import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:adhan/adhan.dart';
import 'package:el_race/core/services/attendance_status_sync_service.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/attendance_checkin/attendance_checkin_activity.dart';
import 'package:el_race/ui/presentation/home_screen/bloc/home_bloc.dart';
import 'package:el_race/ui/presentation/home_screen/screens/custom_swipe_button.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_city_helper.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_theme.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_mid_attendance_times.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/location_service_banner.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_mid_prayer_panel.dart';
import 'package:el_race/ui/presentation/timesheet/widgets/tm_loading_placeholders.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

enum MidSectionMode { dual, checkIn, prayer }

enum _MidView { dual, checkIn, prayer }

/// Interactive check-in / prayer strip on the news card (mid section).
class HomeMidSection extends StatefulWidget {
  const HomeMidSection({super.key, this.onModeChanged});

  /// Fired when the visible mid-section mode changes (for parent layout).
  final ValueChanged<MidSectionMode>? onModeChanged;

  static const rollDuration = Duration(milliseconds: 100);

  /// Dual-row height (padding + content). Must clear the dual icon (`.w`) on
  /// landscape tablets where scaleW >> scaleH.
  static double estimatedHeight(BuildContext context) {
    final icon = ResponsiveBreakpoints.isTabletScreen ? 48.w : 36.w;
    final dualBody =
        ResponsiveBreakpoints.isTabletScreen ? 72.uh : 52.uh;
    final body = icon > dualBody ? icon : dualBody;
    final pad = 12.uh * 2;
    return pad + body;
  }

  /// Shared body height for attendance + prayer expanded panels.
  static double expandedBodyHeight(BuildContext context) => 140.uh;

  static double expandedHeight(BuildContext context, MidSectionMode mode) {
    if (mode == MidSectionMode.dual) return estimatedHeight(context);
    return 10.uh * 2 + 26.uh + expandedBodyHeight(context) + 6.uh;
  }

  static MidSectionMode _toPublicMode(_MidView v) {
    switch (v) {
      case _MidView.checkIn:
        return MidSectionMode.checkIn;
      case _MidView.prayer:
        return MidSectionMode.prayer;
      case _MidView.dual:
        return MidSectionMode.dual;
    }
  }

  @override
  State<HomeMidSection> createState() => _HomeMidSectionState();
}

class _HomeMidSectionState extends State<HomeMidSection> {
  _MidView _view = _MidView.dual;

  void _notifyMode() {
    widget.onModeChanged?.call(HomeMidSection._toPublicMode(_view));
  }

  void _openCheckIn() {
    if (_isCheckInWidgetDisabled()) return;
    HapticFeedback.lightImpact();
    Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        builder: (_) => const AttendanceCheckInActivity(),
        settings: const RouteSettings(name: '/attendance_checkin'),
      ),
    );
  }

  void _openPrayer() {
    if (_view == _MidView.prayer) return;
    HapticFeedback.lightImpact();
    setState(() => _view = _MidView.prayer);
    _notifyMode();
  }

  void _rollBackToDual() {
    if (_view == _MidView.dual) return;
    setState(() => _view = _MidView.dual);
    _notifyMode();
  }

  @override
  Widget build(BuildContext context) {
    final isCheckInDisabled = _isCheckInWidgetDisabled();

    final shell = switch (_view) {
      _MidView.dual => MidSectionShell.dual,
      _MidView.checkIn => MidSectionShell.attendance,
      _MidView.prayer => MidSectionShell.prayer,
    };

    final isDual = shell == MidSectionShell.dual;
    return HomeGlassTheme.midSectionShell(
      shell: shell,
      borderRadius: isDual ? null : BorderRadius.circular(18.ur),
      padding: isDual
          ? null
          : EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.uh),
      child: SizedBox(
        width: double.infinity,
        child: switch (_view) {
          _MidView.prayer => SizedBox(
              key: const ValueKey('mid_prayer'),
              height: HomeMidSection.expandedBodyHeight(context),
              child: HomeMidPrayerPanel(onBack: _rollBackToDual),
            ),
          _MidView.dual || _MidView.checkIn => ResponsiveBreakpoints
                  .isTabletScreen
              // Tablet: strip fills a taller box — center the row vertically.
              ? Column(
                  key: const ValueKey('mid_dual'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _MidDualRow(
                      onCheckInTap:
                          isCheckInDisabled ? null : () => _openCheckIn(),
                      onPrayerTap: () => _openPrayer(),
                    ),
                  ],
                )
              : _MidDualRow(
                  key: const ValueKey('mid_dual'),
                  onCheckInTap:
                      isCheckInDisabled ? null : () => _openCheckIn(),
                  onPrayerTap: () => _openPrayer(),
                ),
        },
      ),
    );
  }

  bool _isCheckInWidgetDisabled() {
    if (!SharedPref.isUserAuthenticated()) return true;
    final loginData = SharedPref.getLoginData();
    return loginData.result?.data?.defaultWidgets?.data?.checkinWidget
            ?.isDisabled ==
        true;
  }

}

class _MidDualRow extends StatelessWidget {
  const _MidDualRow({
    super.key,
    required this.onCheckInTap,
    required this.onPrayerTap,
  });

  final VoidCallback? onCheckInTap;
  final VoidCallback? onPrayerTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ResponsiveBreakpoints.isTabletScreen
          ? math.max(72.uh, 48.w)
          : math.max(52.uh, 36.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _MidDualTapHalf(
              onTap: onCheckInTap,
              child: const _CheckInSummary(),
            ),
          ),
          SizedBox(width: 12.w),
          Container(
            width: 1,
            height: ResponsiveBreakpoints.isTabletScreen
                ? math.min(56.uh, 48.w)
                : math.min(40.uh, 36.w),
            color: Colors.white.withValues(alpha: 0.45),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _MidDualTapHalf(
              onTap: onPrayerTap,
              child: const _PrayerSummary(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MidDualTapHalf extends StatelessWidget {
  const _MidDualTapHalf({required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: child),
        SizedBox(width: 4.w),
        _MidSectionArrowVisual(enabled: onTap != null),
      ],
    );

    if (onTap == null) {
      return Opacity(opacity: 0.55, child: row);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap!();
      },
      child: row,
    );
  }
}

/// Arrow affordance — tap handled by parent [_MidDualTapHalf].
class _MidSectionArrowVisual extends StatelessWidget {
  const _MidSectionArrowVisual({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final box = ResponsiveBreakpoints.isTabletScreen ? 34.w : 28.w;
    final glyph = ResponsiveBreakpoints.isTabletScreen ? 22.usp : 18.usp;
    return Container(
      width: box,
      height: box,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: enabled ? 0.22 : 0.12),
        border: Border.all(
          color: Colors.white.withValues(alpha: enabled ? 0.55 : 0.3),
          width: 1,
        ),
      ),
      child: Icon(
        Icons.chevron_right_rounded,
        size: glyph,
        color: enabled
            ? HomeGlassTheme.textPrimary
            : HomeGlassTheme.textSecondary,
      ),
    );
  }
}

class _MidCheckInPanel extends StatefulWidget {
  const _MidCheckInPanel({
    super.key,
    required this.enabled,
    required this.onBack,
    required this.onComplete,
  });

  final bool enabled;
  final VoidCallback onBack;
  final VoidCallback onComplete;

  @override
  State<_MidCheckInPanel> createState() => _MidCheckInPanelState();
}

class _MidCheckInPanelState extends State<_MidCheckInPanel> {
  final GlobalKey<CustomSwipeButtonState> _swipeKey =
      GlobalKey<CustomSwipeButtonState>();
  bool _syncingAttendance = false;

  bool get _showSyncShimmer {
    if (!_syncingAttendance) return false;
    return !SharedPref().getPreferenceBoolean('isCheckedIn');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _swipeKey.currentState?.syncFromAttendance();
      if (mounted) setState(() => _syncingAttendance = true);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      await AttendanceStatusSyncService.refreshFromServer(
        reason: 'mid_attendance_open',
      );
      if (mounted) setState(() => _syncingAttendance = false);
    });
  }

  Widget _syncShimmerOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: Colors.white.withValues(alpha: 0.55),
          child: ClipRect(
            child: Align(
              alignment: Alignment.center,
              child: TmShimmerBox(
                width: double.infinity,
                height: 44.uh,
                borderRadius: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeGlassTheme.midModePanelHeader(
          onBack: widget.onBack,
          iconColor: Colors.white,
          title: Text(
            'Attendance',
            style: GoogleFonts.poppins(
              fontSize: 14.usp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        // Location enforcement on demand: shown only when the attendance
        // panel is open with device location services off (replaces the old
        // app-wide blocking dialog on every resume).
        const LocationServiceBanner(),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 18.w),
          child: Opacity(
            opacity: widget.enabled ? 1 : 0.45,
            child: IgnorePointer(
              ignoring: !widget.enabled || _showSyncShimmer,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CustomSwipeButton(
                        key: _swipeKey,
                        trackWidth: constraints.maxWidth,
                        midSectionLayout: true,
                        onActionComplete: widget.onComplete,
                      ),
                      if (_showSyncShimmer) _syncShimmerOverlay(),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        const Spacer(),
        Stack(
          clipBehavior: Clip.none,
          children: [
            const HomeMidAttendanceTimes(),
            if (_showSyncShimmer)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Colors.white.withValues(alpha: 0.5),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.w),
                      child: Row(
                        children: [
                          TmShimmerBox(width: 48.w, height: 28.uh),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8.w),
                              child: TmShimmerBox(
                                width: double.infinity,
                                height: 4.uh,
                                borderRadius: 2,
                              ),
                            ),
                          ),
                          TmShimmerBox(width: 48.w, height: 28.uh),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// --- Dual summary widgets (from former strip) ---

const double _midDualIconSize = 36;
const double _midDualIconGap = 8;
/// Tablet misc strip fills a taller pane — boost icons/type so they don't look
/// tiny against the glass. Phone keeps the original 36 design size.
const double _midDualIconSizeTablet = 48;
const double _midDualIconGapTablet = 10;

double _midDualIcon(BuildContext context) =>
    ResponsiveBreakpoints.isTabletScreen
        ? _midDualIconSizeTablet
        : _midDualIconSize;

double _midDualGap(BuildContext context) =>
    ResponsiveBreakpoints.isTabletScreen
        ? _midDualIconGapTablet
        : _midDualIconGap;

/// Shared row layout so check-in and prayer icons + text line up.
class _MidDualSummaryLayout extends StatelessWidget {
  const _MidDualSummaryLayout({
    required this.icon,
    required this.label,
    required this.title,
    required this.subtitle,
    this.labelTrailing,
  });

  final Widget icon;
  final String label;
  final String title;
  final String subtitle;
  final Widget? labelTrailing;

  @override
  Widget build(BuildContext context) {
    final tablet = ResponsiveBreakpoints.isTabletScreen;
    final iconBox = _midDualIcon(context);
    final gap = _midDualGap(context);
    final labelSp = tablet ? 12.usp : 10.usp;
    final titleSp = tablet ? 18.usp : 15.usp;
    final subSp = tablet ? 11.usp : 9.usp;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: iconBox.w,
          height: iconBox.w,
          child: icon,
        ),
        SizedBox(width: gap.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: labelSp,
                        fontWeight: FontWeight.w500,
                        color: HomeGlassTheme.textSecondary,
                      ),
                    ),
                  ),
                  if (labelTrailing != null) ...[
                    SizedBox(width: 5.w),
                    labelTrailing!,
                  ],
                ],
              ),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: titleSp,
                  fontWeight: FontWeight.w700,
                  color: HomeGlassTheme.textPrimary,
                  height: 1.1,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: subSp,
                  color: HomeGlassTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CheckInSummary extends StatefulWidget {
  const _CheckInSummary();

  @override
  State<_CheckInSummary> createState() => _CheckInSummaryState();
}

class _CheckInSummaryState extends State<_CheckInSummary> {
  Timer? _tickTimer;
  StreamSubscription<AttendanceStatusSnapshot>? _syncSub;
  String _lastTime = '';
  String _lastSub = '';
  bool _lastCheckedIn = false;

  @override
  void initState() {
    super.initState();
    final initial = _checkInDisplay();
    _lastTime = initial.time;
    _lastSub = initial.sub;
    _lastCheckedIn = initial.checkedIn;
    _syncSub = AttendanceStatusSyncService.updates.listen((_) {
      if (!mounted) return;
      _refreshIfChanged();
    });
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _refreshIfChanged();
    });
  }

  void _refreshIfChanged() {
    final display = _checkInDisplay();
    if (display.time == _lastTime &&
        display.sub == _lastSub &&
        display.checkedIn == _lastCheckedIn) {
      return;
    }
    setState(() {
      _lastTime = display.time;
      _lastSub = display.sub;
      _lastCheckedIn = display.checkedIn;
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _syncSub?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final totalMinutes = d.inMinutes.abs();
    final h = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final m = (totalMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  DateTime? _resolveCheckInAt() {
    final checkInMillis = SharedPref().getPreferenceInt('checkInTime');
    if (checkInMillis > 0) {
      return DateTime.fromMillisecondsSinceEpoch(checkInMillis);
    }

    // Fallback: display string can exist when millis was not persisted.
    final display = SharedPref().getPreferenceString('checkInDisplayTime').trim();
    if (display.isEmpty || display == '00:00:00' || display == '--:--') {
      return null;
    }
    final parts = display.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    final second = parts.length >= 3 ? int.tryParse(parts[2]) ?? 0 : 0;
    if (hour == null || minute == null) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute, second);
  }

  ({bool checkedIn, String status, String time, String sub}) _checkInDisplay() {
    final isCheckedIn = SharedPref().getPreferenceBoolean('isCheckedIn');
    final checkInAt = _resolveCheckInAt();
    final outRaw = SharedPref().getPreferenceString('checkOutDisplayTime').trim();
    final hasCheckOut = outRaw.isNotEmpty &&
        outRaw != '00:00:00' &&
        outRaw != '--:--';

    if (checkInAt != null && (isCheckedIn || hasCheckOut)) {
      final elapsed = DateTime.now().difference(checkInAt);
      if (isCheckedIn && !hasCheckOut) {
        final remaining = const Duration(hours: 8) - elapsed;
        final remainingLabel = remaining.isNegative
            ? '00:00'
            : _formatDuration(remaining);
        return (
          checkedIn: true,
          status: 'Checked in',
          time: DateFormat('HH:mm').format(checkInAt),
          sub: 'In $remainingLabel',
        );
      }
      return (
        checkedIn: false,
        status: hasCheckOut ? 'Checked out' : 'Check In',
        time: DateFormat('HH:mm').format(checkInAt),
        sub: hasCheckOut ? 'Out ${_formatClock(outRaw)}' : 'In --:--',
      );
    }

    return (
      checkedIn: false,
      status: 'Check In',
      time: '--:--',
      sub: 'In --:--',
    );
  }

  String _formatClock(String raw) {
    final parts = raw.split(':');
    if (parts.length >= 2) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final checkIn = _checkInDisplay();

    return _MidDualSummaryLayout(
      icon: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.ur),
          color: const Color(0xFF1B2A4A),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1B2A4A).withValues(alpha: 0.28),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.fingerprint_rounded,
            size: ResponsiveBreakpoints.isTabletScreen ? 28.usp : 22.usp,
            color: Colors.white,
          ),
        ),
      ),
      label: checkIn.status,
      labelTrailing: Container(
        width: 6.w,
        height: 6.w,
        decoration: BoxDecoration(
          color: checkIn.checkedIn
              ? const Color(0xFF22C55E)
              : const Color(0xFFEF4444),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (checkIn.checkedIn
                      ? const Color(0xFF22C55E)
                      : const Color(0xFFEF4444))
                  .withValues(alpha: 0.6),
              blurRadius: 4,
            ),
          ],
        ),
      ),
      title: checkIn.time,
      subtitle: checkIn.sub,
    );
  }
}

class _PrayerSummary extends StatefulWidget {
  const _PrayerSummary();

  @override
  State<_PrayerSummary> createState() => _PrayerSummaryState();
}

class _PrayerSummaryState extends State<_PrayerSummary> {
  Prayer? _cachedPrayer;
  DateTime? _cachedTime;
  Timer? _countdownTimer;
  String _lastCountdownLabel = '';

  @override
  void initState() {
    super.initState();
    _applyFromBloc(context.read<HomeBloc>().state);
    if (_cachedPrayer == null) {
      _applyLocalFallback();
    }
    final bloc = context.read<HomeBloc>();
    if (bloc.state is! PrayerTimesLoaded && bloc.state is! PrayerTimesError) {
      bloc.add(const InitPrayerTimesEvent());
    }
    _lastCountdownLabel = _countdownLabel(_cachedTime);
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final label = _countdownLabel(_cachedTime);
      if (label == _lastCountdownLabel) return;
      setState(() => _lastCountdownLabel = label);
    });
  }

  void _applyFromBloc(HomeState state) {
    if (state is PrayerTimesLoaded) {
      _cachedPrayer = state.nextPrayer as Prayer?;
      _cachedTime = state.nextTime;
    } else if (state is PrayerTimesError && state.prayerTimes != null) {
      try {
        final pt = state.prayerTimes as PrayerTimes;
        final next = pt.nextPrayer();
        _cachedPrayer = next;
        _cachedTime = pt.timeForPrayer(next);
      } catch (_) {
        _applyLocalFallback();
      }
    }
  }

  void _applyLocalFallback() {
    try {
      final params = CalculationMethod.egyptian.getParameters()
        ..madhab = Madhab.shafi;
      final pt = PrayerTimes.today(
        Coordinates(25.2048, 55.2708),
        params,
      );
      final next = pt.nextPrayer();
      _cachedPrayer = next;
      _cachedTime = pt.timeForPrayer(next);
    } catch (_) {}
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  static const _prayerIconColor = Color(0xFFF5DBA0);

  String _prayerLabel(Prayer? prayer) {
    switch (prayer) {
      case Prayer.fajr:
        return 'Fajr';
      case Prayer.dhuhr:
        return 'Dhuhr';
      case Prayer.asr:
        return 'Asr';
      case Prayer.maghrib:
        return 'Maghrib';
      case Prayer.isha:
        return 'Isha';
      default:
        return '—';
    }
  }

  Widget _prayerIconAsset(Prayer? prayer) {
    final filter = const ColorFilter.mode(_prayerIconColor, BlendMode.srcIn);
    final size =
        ResponsiveBreakpoints.isTabletScreen ? 24.w : 18.w;
    switch (prayer) {
      case Prayer.fajr:
        return SvgPicture.asset(
          'assets/newapp/newicon/fajar_new.svg',
          width: size,
          height: size,
          colorFilter: filter,
        );
      case Prayer.asr:
        return SvgPicture.asset(
          'assets/newapp/newicon/asr_new.svg',
          width: size,
          height: size,
          colorFilter: filter,
        );
      case Prayer.maghrib:
        return SvgPicture.asset(
          'assets/newapp/newicon/maghrib.svg',
          width: size,
          height: size,
          colorFilter: filter,
        );
      case Prayer.isha:
        return Image.asset(
          'assets/newapp/Ellipse 107.png',
          width: size,
          height: size,
          color: _prayerIconColor,
          colorBlendMode: BlendMode.srcIn,
        );
      default:
        return SvgPicture.asset(
          'assets/newapp/newicon/duhur.svg',
          width: ResponsiveBreakpoints.isTabletScreen ? 26.w : 20.w,
          height: size,
          colorFilter: filter,
        );
    }
  }

  String _countdownLabel(DateTime? nextTime) {
    if (nextTime == null) return '';
    final diff = nextTime.difference(DateTime.now());
    if (diff.isNegative) return '';
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60);
    return h > 0 ? 'in ${h}h ${m}m' : 'in ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<HomeBloc, HomeState>(
      listenWhen: (prev, curr) =>
          curr is PrayerTimesLoaded || curr is PrayerTimesError,
      listener: (context, state) {
        setState(() => _applyFromBloc(state));
      },
      child: Builder(
        builder: (context) {
          final prayer = _cachedPrayer;
          final nextTime = _cachedTime;
          final prayerName = _prayerLabel(prayer);
          final timeLabel =
              nextTime != null ? DateFormat('HH:mm').format(nextTime) : '';

          final countdown = _countdownLabel(nextTime);

          return _MidDualSummaryLayout(
            icon: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.ur),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6B5328), Color(0xFF4A3820)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6B5328).withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(child: _prayerIconAsset(prayer)),
            ),
            label: prayerName,
            title: timeLabel.isEmpty ? '--:--' : timeLabel,
            subtitle: countdown,
          );
        },
      ),
    );
  }
}
