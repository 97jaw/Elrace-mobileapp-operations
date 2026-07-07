import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/theme/day_status_colors.dart';
import 'package:el_race/ui/presentation/Attendace_list/model/attendance_model.dart';
import 'package:el_race/ui/presentation/attendance_reports/attendance_report_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

/// Month grid — Sunday first. **Squircle** cells in an optional white card.
///
/// Colors (light / bright): present green, absent red, non-normal attendance type
/// or leave/mission blue, **weekends** (Sat–Sun) yellow when there is no record.
class AttendanceMonthCalendar extends StatelessWidget {
  const AttendanceMonthCalendar({
    super.key,
    required this.year,
    required this.month,
    required this.recordsByDay,
    required this.onDayTap,
    this.wrapInCard = true,
    this.showMonthHeader = false,
    this.onPreviousMonth,
    this.onNextMonth,
    this.useAttendanceTheme = false,
  });

  final int year;
  final int month;
  final Map<DateTime, AttendanceRecord> recordsByDay;
  final void Function(DateTime day, AttendanceRecord? record) onDayTap;

  /// Padded white card + shadow (reference layout).
  final bool wrapInCard;

  /// Calendar icon + `MMMM yyyy` + chevrons (hide when month is in AppBar).
  final bool showMonthHeader;
  final VoidCallback? onPreviousMonth;
  final VoidCallback? onNextMonth;
  final bool useAttendanceTheme;

  static const _attendancePrimary = Color(0xFF1E4DB7);
  static const _skyLight = Color(0xFFEEF4FF);

  static Color _blendLight(Color c, [double towardsWhite = 0.68]) {
    return Color.lerp(c, Colors.white, towardsWhite)!;
  }

  Color get _primary =>
      useAttendanceTheme ? _attendancePrimary : HrModuleColors.primary;

  static _AttendanceDayStyle _styleForDay({
    required DateTime date,
    required DateTime todayKey,
    required AttendanceRecord? rec,
    required bool useAttendanceTheme,
  }) {
    final isFuture = date.isAfter(todayKey);
    if (isFuture) {
      return _AttendanceDayStyle(
        fill: useAttendanceTheme
            ? _skyLight
            : HrModuleColors.lightBg,
        border: useAttendanceTheme
            ? _attendancePrimary.withValues(alpha: 0.08)
            : HrModuleColors.border.withValues(alpha: 0.2),
        labelColor: useAttendanceTheme
            ? _attendancePrimary.withValues(alpha: 0.45)
            : HrModuleColors.mutedText,
        stripe: false,
      );
    }

    final isWeekend = date.weekday == DateTime.saturday ||
        date.weekday == DateTime.sunday;

    if (rec == null) {
      if (isWeekend) {
        return _AttendanceDayStyle(
          fill: _blendLight(const Color(0xFFFFEB3B), 0.55),
          border: const Color(0xFFFFC107).withValues(alpha: 0.35),
          labelColor: HrModuleColors.text,
          stripe: true,
        );
      }
      return _AttendanceDayStyle(
        fill: HrModuleColors.surface,
        border: HrModuleColors.border.withValues(alpha: 0.25),
        labelColor: HrModuleColors.mutedText,
        stripe: false,
      );
    }

    final statusKey = displayStatusKey(rec);
    final norm = DayStatusTokens.normalize(statusKey);
    final type = (rec.attendanceType ?? '').trim().toLowerCase();
    final nonNormalType =
        type.isNotEmpty && type != 'normal' && type != 'regular';

    if (norm.contains('ABSENT')) {
      final base = const Color(0xFFE53935);
      return _AttendanceDayStyle(
        fill: _blendLight(base),
        border: base.withValues(alpha: 0.35),
        labelColor: const Color(0xFFB71C1C),
        stripe: false,
      );
    }

    if (nonNormalType ||
        norm.contains('LEAVE') ||
        norm.contains('MISSION')) {
      final base = useAttendanceTheme
          ? const Color(0xFF0284C7)
          : const Color(0xFF1E88E5);
      return _AttendanceDayStyle(
        fill: _blendLight(base),
        border: base.withValues(alpha: 0.35),
        labelColor: useAttendanceTheme
            ? const Color(0xFF0369A1)
            : const Color(0xFF0D47A1),
        stripe: false,
      );
    }

    // Present, late, early departure, etc.
    final base = useAttendanceTheme
        ? const Color(0xFF16A34A)
        : const Color(0xFF43A047);
    return _AttendanceDayStyle(
      fill: _blendLight(base),
      border: base.withValues(alpha: 0.35),
      labelColor: useAttendanceTheme
          ? const Color(0xFF15803D)
          : const Color(0xFF1B5E20),
      stripe: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final leading = weekdaySundayFirst(first);
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final totalCells = ((leading + daysInMonth + 6) ~/ 7) * 7;

    const headers = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    final grid = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final h in headers)
              Expanded(
                child: Center(
                  child: Text(
                    h,
                    style: HrModuleTypography.caption().copyWith(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: useAttendanceTheme
                              ? _attendancePrimary.withValues(alpha: 0.55)
                              : HrModuleColors.secondary,
                        ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: useAttendanceTheme ? 6.h : 10.h),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: useAttendanceTheme ? 6.h : 8.h,
            crossAxisSpacing: useAttendanceTheme ? 6.w : 8.w,
            childAspectRatio: 0.95,
          ),
          itemCount: totalCells,
          itemBuilder: (context, i) {
            if (i < leading || i >= leading + daysInMonth) {
              return _CalendarPadCell();
            }
            final day = i - leading + 1;
            final date = DateTime(year, month, day);
            final key = DateTime(year, month, day);
            final rec = recordsByDay[key];
            final isFuture = date.isAfter(todayKey);
            final isToday = key == todayKey;
            final style = _styleForDay(
              date: date,
              todayKey: todayKey,
              rec: rec,
              useAttendanceTheme: useAttendanceTheme,
            );

            return Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16.r),
              child: InkWell(
                onTap: isFuture ? null : () => onDayTap(date, rec),
                borderRadius: BorderRadius.circular(16.r),
                child: Container(
                  decoration: BoxDecoration(
                    color: style.fill,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: isToday
                          ? _primary
                          : style.border,
                      width: isToday ? 2.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      if (style.stripe)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16.r),
                            child: CustomPaint(
                              painter: _LightStripePainter(),
                            ),
                          ),
                        ),
                      Center(
                        child: Text(
                          '$day',
                          style: HrModuleTypography.body().copyWith(
                                fontSize: 13.sp,
                                fontWeight: isToday
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                                color: style.labelColor,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );

    Widget content = grid;
    if (showMonthHeader) {
      final prev = onPreviousMonth;
      final next = onNextMonth;
      if (prev != null && next != null) {
        final title =
            DateFormat('MMMM yyyy').format(DateTime(year, month));
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40.r,
                  height: 40.r,
                  decoration: BoxDecoration(
                    color: HrModuleColors.lightBg,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    size: 22.sp,
                    color: HrModuleColors.secondary,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    title,
                    style: HrModuleTypography.cardTitle().copyWith(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                _RoundNavIcon(
                  icon: Icons.chevron_left,
                  onTap: prev,
                ),
                SizedBox(width: 8.w),
                _RoundNavIcon(
                  icon: Icons.chevron_right,
                  onTap: next,
                ),
              ],
            ),
            SizedBox(height: 16.h),
            grid,
          ],
        );
      }
    }

    if (!wrapInCard) {
      return content;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        useAttendanceTheme ? 12.w : 16.w,
        useAttendanceTheme ? 12.h : 18.h,
        useAttendanceTheme ? 12.w : 16.w,
        useAttendanceTheme ? 12.h : 18.h,
      ),
      decoration: BoxDecoration(
        gradient: useAttendanceTheme
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.96),
                  _skyLight.withValues(alpha: 0.88),
                ],
              )
            : null,
        color: useAttendanceTheme ? null : HrModuleColors.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: useAttendanceTheme
            ? Border.all(color: _attendancePrimary.withValues(alpha: 0.12))
            : null,
        boxShadow: [
          BoxShadow(
            color: (useAttendanceTheme ? _attendancePrimary : Colors.black)
                .withValues(alpha: useAttendanceTheme ? 0.08 : 0.07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: content,
    );
  }
}

class _AttendanceDayStyle {
  const _AttendanceDayStyle({
    required this.fill,
    required this.border,
    required this.labelColor,
    required this.stripe,
  });

  final Color fill;
  final Color border;
  final Color labelColor;
  final bool stripe;
}

class _RoundNavIcon extends StatelessWidget {
  const _RoundNavIcon({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HrModuleColors.lightBg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(8.r),
          child: Icon(icon, size: 22.sp, color: HrModuleColors.text),
        ),
      ),
    );
  }
}

/// Leading / trailing pad cells (reference: light diagonal stripes).
class _CalendarPadCell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: HrModuleColors.border.withValues(alpha: 0.2),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: CustomPaint(
          painter: _LightStripePainter(
            lineColor: Colors.white.withValues(alpha: 0.65),
          ),
        ),
      ),
    );
  }
}

class _LightStripePainter extends CustomPainter {
  _LightStripePainter({this.lineColor});

  final Color? lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor ?? Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 1.5;
    const step = 6.0;
    for (double x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LightStripePainter oldDelegate) =>
      oldDelegate.lineColor != lineColor;
}
