import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

/// Schedule-style week row: month title with chevrons, day labels, circular dates.
class AttendanceWeekStripCard extends StatelessWidget {
  const AttendanceWeekStripCard({
    super.key,
    required this.focusedYear,
    required this.focusedMonth,
    required this.selectedDay,
    required this.onSelectDay,
    required this.onPreviousMonth,
    required this.onNextMonth,
    this.inPrimaryHeader = false,
    this.useAttendanceTheme = false,
    this.showWeekStrip = true,
  });

  final int focusedYear;
  final int focusedMonth;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelectDay;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final bool inPrimaryHeader;
  final bool useAttendanceTheme;
  /// When false, only month title + chevrons (no day row).
  final bool showWeekStrip;

  static List<DateTime> _weekFor(DateTime anchor) {
    final d = DateTime(anchor.year, anchor.month, anchor.day);
    final fromSunday = d.weekday % DateTime.daysPerWeek;
    final start = d.subtract(Duration(days: fromSunday));
    return List.generate(
      DateTime.daysPerWeek,
      (i) => DateTime(start.year, start.month, start.day + i),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthTitle =
        DateFormat('MMMM yyyy').format(DateTime(focusedYear, focusedMonth));
    final week = _weekFor(selectedDay);
    const labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    const gold = Color(0xFFE6C200);
    const attendancePrimary = Color(0xFF1E4DB7);
    final surfaceColor = useAttendanceTheme
        ? Colors.white.withValues(alpha: 0.88)
        : inPrimaryHeader
            ? Colors.white.withValues(alpha: 0.88)
            : HrModuleColors.surface;
    final accent = useAttendanceTheme ? attendancePrimary : gold;
    final titleColor = useAttendanceTheme ? attendancePrimary : null;

    return Container(
      padding: EdgeInsets.fromLTRB(
        12.tw,
        showWeekStrip ? 12.th : 8.th,
        12.tw,
        showWeekStrip ? 14.th : 10.th,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18.tr),
        border: useAttendanceTheme
            ? Border.all(color: attendancePrimary.withValues(alpha: 0.12))
            : inPrimaryHeader
                ? Border.all(color: Colors.white.withValues(alpha: 0.45))
                : null,
        boxShadow: [
          BoxShadow(
            color: (useAttendanceTheme ? attendancePrimary : Colors.black)
                .withValues(alpha: useAttendanceTheme ? 0.06 : (inPrimaryHeader ? 0.08 : 0.06)),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onPreviousMonth,
                icon: Icon(Icons.chevron_left,
                    size: 26.tsp, color: titleColor),
              ),
              Expanded(
                child: Text(
                  monthTitle,
                  textAlign: TextAlign.center,
                  style: HrModuleTypography.sectionHeading().copyWith(
                        fontSize: 16.tsp,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onNextMonth,
                icon: Icon(Icons.chevron_right,
                    size: 26.tsp, color: titleColor),
              ),
            ],
          ),
          if (showWeekStrip) ...[
            SizedBox(height: 10.th),
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Center(
                      child: Text(
                        labels[i],
                        style: HrModuleTypography.caption().copyWith(
                              fontSize: 11.tsp,
                              fontWeight: FontWeight.w600,
                              color: useAttendanceTheme
                                  ? attendancePrimary.withValues(alpha: 0.55)
                                  : HrModuleColors.mutedText,
                            ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 8.th),
            Row(
              children: [
                for (final day in week)
                  Expanded(
                    child: _DayOrb(
                      day: day,
                      focusedYear: focusedYear,
                      focusedMonth: focusedMonth,
                      selectedDay: selectedDay,
                      weekendStriped: day.weekday == DateTime.saturday,
                      accentGold: accent,
                      inPrimaryHeader: inPrimaryHeader,
                      useAttendanceTheme: useAttendanceTheme,
                      onTap: () => onSelectDay(day),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DayOrb extends StatelessWidget {
  const _DayOrb({
    required this.day,
    required this.focusedYear,
    required this.focusedMonth,
    required this.selectedDay,
    required this.weekendStriped,
    required this.accentGold,
    required this.onTap,
    this.inPrimaryHeader = false,
    this.useAttendanceTheme = false,
  });

  final DateTime day;
  final int focusedYear;
  final int focusedMonth;
  final DateTime selectedDay;
  final bool weekendStriped;
  final Color accentGold;
  final VoidCallback onTap;
  final bool inPrimaryHeader;
  final bool useAttendanceTheme;

  @override
  Widget build(BuildContext context) {
    final inMonth =
        day.year == focusedYear && day.month == focusedMonth;
    final isSelected = day.year == selectedDay.year &&
        day.month == selectedDay.month &&
        day.day == selectedDay.day;

    final numStyle = HrModuleTypography.body().copyWith(
      fontSize: 13.tsp,
      fontWeight: FontWeight.w700,
    );

    Widget child;
    if (isSelected) {
      final selectedFill = useAttendanceTheme
          ? const Color(0xFF1E4DB7)
          : inPrimaryHeader
              ? HrModuleColors.primary
              : accentGold;
      child = Container(
        width: 36.tw,
        height: 36.tw,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selectedFill,
          shape: BoxShape.circle,
        ),
        child: Text(
          '${day.day}',
          style: numStyle.copyWith(color: Colors.white),
        ),
      );
    } else if (weekendStriped && inMonth) {
      child = Container(
        width: 36.tw,
        height: 36.tw,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFFD8DADE),
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: CustomPaint(
            painter: _DiagonalStripesPainter(),
            child: Center(
              child: Text(
                '${day.day}',
                style: numStyle.copyWith(
                  color: HrModuleColors.mutedText,
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      child = Container(
        width: 36.tw,
        height: 36.tw,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: inMonth
              ? const Color(0xFFF1F3F5)
              : HrModuleColors.lightBg,
          shape: BoxShape.circle,
        ),
        child: Text(
          '${day.day}',
          style: numStyle.copyWith(
            color: inMonth
                ? HrModuleColors.text
                : HrModuleColors.mutedText.withValues(alpha: 0.7),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Center(child: child),
      ),
    );
  }
}

class _DiagonalStripesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 2;
    const step = 5.0;
    for (double x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
