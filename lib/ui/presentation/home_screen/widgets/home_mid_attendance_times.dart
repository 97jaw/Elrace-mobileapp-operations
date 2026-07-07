import 'dart:async';

import 'package:el_race/core/services/attendance_status_sync_service.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/home_screen/widgets/home_glass_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// In / Out row + timeline — spaced to avoid overlap with the slider.
class HomeMidAttendanceTimes extends StatefulWidget {
  const HomeMidAttendanceTimes({super.key});

  @override
  State<HomeMidAttendanceTimes> createState() => _HomeMidAttendanceTimesState();
}

class _HomeMidAttendanceTimesState extends State<HomeMidAttendanceTimes> {
  String _checkIn = '--:--';
  String _checkOut = '--:--';
  bool _checkedIn = false;
  bool _checkedOut = false;

  StreamSubscription<AttendanceStatusSnapshot>? _syncSub;

  @override
  void initState() {
    super.initState();
    _loadFromPrefs();
    _syncSub = AttendanceStatusSyncService.updates.listen(_applySnapshot);
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  void _loadFromPrefs() {
    final inRaw = SharedPref().getPreferenceString('checkInDisplayTime');
    final outRaw = SharedPref().getPreferenceString('checkOutDisplayTime');
    setState(() {
      _checkIn = _formatClock(inRaw);
      _checkOut = _formatClock(outRaw);
      _checkedIn = SharedPref().getPreferenceBoolean('isCheckedIn');
      _checkedOut = outRaw.isNotEmpty &&
          outRaw != '--:--' &&
          outRaw != '00:00:00';
    });
  }

  void _applySnapshot(AttendanceStatusSnapshot snapshot) {
    if (!mounted) return;
    setState(() {
      _checkIn = _formatClock(snapshot.checkInDisplayTime);
      _checkOut = _formatClock(snapshot.checkOutDisplayTime);
      _checkedIn = snapshot.checkedIn && !snapshot.checkedOut;
      _checkedOut = snapshot.checkedOut;
    });
  }

  String _formatClock(String raw) {
    if (raw.isEmpty || raw == '--:--' || raw == '00:00:00') return '--:--';
    final parts = raw.split(':');
    if (parts.length >= 2) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }
    return raw;
  }

  double _progress() {
    if (_checkIn == '--:--') return 0;
    if (_checkedOut && _checkOut != '--:--') return 1;
    if (!_checkedIn) return 0;
    try {
      final p = _checkIn.split(':');
      final inMin = int.parse(p[0]) * 60 + int.parse(p[1]);
      final now = DateTime.now().toUtc().add(const Duration(hours: 4));
      var elapsed = now.hour * 60 + now.minute - inMin;
      if (elapsed < 0) elapsed += 24 * 60;
      return (elapsed / (8 * 60)).clamp(0.05, 0.95);
    } catch (_) {
      return 0.4;
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress();
    final live = _checkedIn && !_checkedOut;

    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
              SizedBox(
                width: 68.w,
                child: _TimeEnd(label: 'In', time: _checkIn, alignRight: false),
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6.w),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 2.h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        color: HomeGlassTheme.textPrimary.withValues(alpha: 0.15),
                      ),
                    ),
                    if (progress > 0)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: progress,
                          child: Container(
                            height: 2.h,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(99),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFD8C4C8),
                                  Color(0xFF3D5F85),
                                  HomeGlassTheme.textPrimary,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (live)
                      Align(
                        alignment: Alignment(progress * 2 - 1, 0),
                        child: Container(
                          width: 7.w,
                          height: 7.w,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
              SizedBox(
                width: 68.w,
                child: _TimeEnd(label: 'Out', time: _checkOut, alignRight: true),
              ),
        ],
      ),
    );
  }
}

class _TimeEnd extends StatelessWidget {
  const _TimeEnd({
    required this.label,
    required this.time,
    required this.alignRight,
  });

  final String label;
  final String time;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 9.sp,
            fontWeight: FontWeight.w500,
            color: HomeGlassTheme.textPrimary.withValues(alpha: 0.55),
            height: 1.1,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          time,
          style: GoogleFonts.poppins(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: HomeGlassTheme.textPrimary,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}
