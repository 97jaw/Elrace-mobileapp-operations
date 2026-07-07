import 'package:el_race/ui/presentation/attendance_reports/attendance_reports_period.dart';
import 'package:el_race/ui/presentation/attendance_reports/widgets/attendance_glass_chrome_header.dart';
import 'package:el_race/ui/presentation/attendance_reports/widgets/attendance_week_strip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Month title + chevrons only (no day row).
class AttendanceMonthSwitcherCard extends StatelessWidget {
  const AttendanceMonthSwitcherCard({
    super.key,
    required this.period,
    required this.onPreviousMonth,
    required this.onNextMonth,
    this.margin,
  });

  final AttendancePeriod period;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final EdgeInsetsGeometry? margin;

  static DateTime anchorDay(AttendancePeriod period) {
    final now = DateTime.now();
    if (now.year == period.year && now.month == period.month) {
      return DateTime(now.year, now.month, now.day);
    }
    return DateTime(period.year, period.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final anchor = anchorDay(period);
    return Container(
      margin: margin ?? EdgeInsets.fromLTRB(14.w, 6.h, 14.w, 8.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: kAttendancePrimary.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: kAttendancePrimary.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: AttendanceWeekStripCard(
        focusedYear: period.year,
        focusedMonth: period.month,
        selectedDay: anchor,
        onSelectDay: (_) {},
        onPreviousMonth: onPreviousMonth,
        onNextMonth: onNextMonth,
        useAttendanceTheme: true,
        showWeekStrip: false,
      ),
    );
  }
}
