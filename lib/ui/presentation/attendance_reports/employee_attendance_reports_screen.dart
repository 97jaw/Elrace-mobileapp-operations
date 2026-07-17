import 'package:el_race/core/utils/responsive_breakpoints.dart';
import 'package:el_race/ui/presentation/attendance_reports/attendance_report_helpers.dart';
import 'package:el_race/ui/presentation/attendance_reports/attendance_reports_period.dart';
import 'package:el_race/ui/presentation/attendance_reports/attendance_reports_session.dart';
import 'package:el_race/ui/presentation/attendance_reports/theme/attendance_dashboard_theme.dart';
import 'package:el_race/ui/presentation/attendance_reports/widgets/attendance_daily_detail_sheet.dart';
import 'package:el_race/ui/presentation/attendance_reports/widgets/attendance_glass_chrome_header.dart';
import 'package:el_race/ui/presentation/attendance_reports/widgets/attendance_kpi_strip.dart';
import 'package:el_race/ui/presentation/attendance_reports/widgets/attendance_month_calendar.dart';
import 'package:el_race/ui/presentation/attendance_reports/widgets/attendance_month_switcher_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

const _kSkyLight = Color(0xFFEEF4FF);

/// E1 — My Attendance: month switcher, KPI boxes, calendar.
class EmployeeAttendanceReportsScreen extends ConsumerWidget {
  const EmployeeAttendanceReportsScreen({
    super.key,
    required this.session,
    this.sessionRefreshing = false,
  });

  final AttendanceSession session;
  final bool sessionRefreshing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(attendanceReportsPeriodProvider);
    final result = session.result;
    final records = result.records ?? [];
    final byDay = recordsByCalendarDay(records);
    final kpis = computeKpisFromResult(result, records);

    Future<void> refresh() async {
      await ref.read(attendanceSessionProvider.notifier).refresh();
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _kSkyLight,
        body: Container(
          decoration: const BoxDecoration(
            gradient: AttendanceDashboardTheme.scaffoldGradient,
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AttendanceGlassChromeHeader(
                    title: 'My Attendance',
                    showBack: false,
                    trailing: [
                      AttendanceGlassChromeHeader.refreshButton(
                        onPressed: refresh,
                      ),
                    ],
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      color: kAttendancePrimary,
                      onRefresh: refresh,
                      child: ListView(
                        primary: false,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(0, 0, 0, 16.th),
                        children: [
                          AttendanceMonthSwitcherCard(
                            period: period,
                            margin: EdgeInsets.fromLTRB(14.tw, 6.th, 14.tw, 10.th),
                            onPreviousMonth: () => ref
                                .read(attendanceReportsPeriodProvider.notifier)
                                .previousMonth(),
                            onNextMonth: () => ref
                                .read(attendanceReportsPeriodProvider.notifier)
                                .nextMonth(),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14.tw),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (kDebugMode)
                                  Text(
                                    'Module 5 · Employee · ${result.employeeName ?? ''}',
                                    style: TextStyle(
                                      fontSize: 10.tsp,
                                      color: AttendanceDashboardTheme.textMuted,
                                    ),
                                  ),
                                if (kDebugMode) SizedBox(height: 4.th),
                                AttendanceKpiStrip(
                                  kpi: kpis,
                                  useAttendanceTheme: true,
                                ),
                                SizedBox(height: 10.th),
                                AttendanceMonthCalendar(
                                  year: period.year,
                                  month: period.month,
                                  recordsByDay: byDay,
                                  useAttendanceTheme: true,
                                  onDayTap: (d, r) {
                                    showAttendanceDailyDetailSheet(
                                      context,
                                      day: d,
                                      record: r,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (sessionRefreshing)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    minHeight: 2.5,
                    backgroundColor: Colors.transparent,
                    color: kAttendancePrimary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
