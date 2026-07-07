import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/ui/presentation/attendance_reports/attendance_report_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Period summary KPI cards — attendance %, worked hours, absent only.
class AttendanceKpiStrip extends StatelessWidget {
  const AttendanceKpiStrip({
    super.key,
    required this.kpi,
    this.useAttendanceTheme = false,
  });

  final AttendanceKpiView kpi;
  final bool useAttendanceTheme;

  static const _attendancePrimary = Color(0xFF1E4DB7);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final primary =
        useAttendanceTheme ? _attendancePrimary : HrModuleColors.primary;
    final items = <(String, String, Color)>[
      (
        'Attendance %',
        '${kpi.attendancePercent.toStringAsFixed(1)}%',
        useAttendanceTheme
            ? const Color(0xFF16A34A)
            : HrModuleColors.primary.withValues(alpha: 0.14),
      ),
      (
        'Worked hrs',
        kpi.workedHours.toStringAsFixed(1),
        useAttendanceTheme
            ? _attendancePrimary
            : HrModuleColors.success.withValues(alpha: 0.16),
      ),
      (
        'Absent',
        '${kpi.absentCount}',
        useAttendanceTheme
            ? const Color(0xFFDC2626)
            : HrModuleColors.danger.withValues(alpha: 0.14),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = useAttendanceTheme ? 8.w : 10.w;
        final width = constraints.maxWidth;
        final cellWidth = (width - 2 * gap) / 3;
        final aspect = useAttendanceTheme ? 1.18 : 1.15;
        final rowHeight = (cellWidth / aspect).clamp(72.h, 96.h);

        return SizedBox(
          height: rowHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                Expanded(
                  child: _KpiTile(
                    title: items[i].$1,
                    value: items[i].$2,
                    accent: items[i].$3,
                    theme: theme,
                    primary: primary,
                    useAttendanceTheme: useAttendanceTheme,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.title,
    required this.value,
    required this.accent,
    required this.theme,
    required this.primary,
    required this.useAttendanceTheme,
  });

  final String title;
  final String value;
  final Color accent;
  final TextTheme theme;
  final Color primary;
  final bool useAttendanceTheme;

  static const _skyLight = Color(0xFFEEF4FF);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: Colors.white.withValues(alpha: useAttendanceTheme ? 0.9 : 0),
        ),
        boxShadow: useAttendanceTheme
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.10),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13.r),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: useAttendanceTheme ? 10.w : 10.w,
            vertical: useAttendanceTheme ? 10.h : 10.h,
          ),
          decoration: BoxDecoration(
            gradient: useAttendanceTheme
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white,
                      _skyLight.withValues(alpha: 0.9),
                    ],
                  )
                : null,
            color: useAttendanceTheme ? null : accent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (useAttendanceTheme)
                Container(
                  height: 3,
                  margin: EdgeInsets.only(bottom: 6.h),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              Text(
                title,
                style: theme.labelSmall?.copyWith(
                      fontSize: 10.sp,
                      color: useAttendanceTheme
                          ? primary.withValues(alpha: 0.65)
                          : HrModuleColors.mutedText,
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 5.h),
              Text(
                value,
                style: theme.titleMedium?.copyWith(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color:
                          useAttendanceTheme ? accent : HrModuleColors.text,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
