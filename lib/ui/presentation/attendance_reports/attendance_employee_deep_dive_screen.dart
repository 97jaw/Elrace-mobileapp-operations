import 'package:el_race/ui/presentation/Attendace_list/model/attendance_model.dart';
import 'package:el_race/ui/presentation/attendance_reports/attendance_report_helpers.dart';
import 'package:el_race/ui/presentation/attendance_reports/attendance_reports_period.dart';
import 'package:el_race/ui/presentation/attendance_reports/attendance_reports_session.dart'
    show attendanceEmployeeDetailProvider, AttendanceDetailQuery;
import 'package:el_race/ui/presentation/attendance_reports/theme/attendance_dashboard_theme.dart';
import 'package:el_race/ui/presentation/attendance_reports/widgets/attendance_daily_detail_sheet.dart';
import 'package:el_race/ui/presentation/attendance_reports/widgets/attendance_glass_chrome_header.dart';
import 'package:el_race/ui/presentation/attendance_reports/widgets/attendance_kpi_strip.dart';
import 'package:el_race/ui/presentation/attendance_reports/widgets/attendance_month_calendar.dart';
import 'package:el_race/ui/presentation/attendance_reports/widgets/attendance_month_switcher_card.dart';
import 'package:el_race/ui/presentation/attendance_reports/widgets/attendance_network_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

const _kSkyLight = Color(0xFFEEF4FF);
const _kSkyMid = Color(0xFFDEEAFF);

/// Employee month view — month switcher, KPI boxes, calendar (glassy theme).
class AttendanceEmployeeDeepDiveScreen extends ConsumerWidget {
  const AttendanceEmployeeDeepDiveScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
    this.imageUrl,
    this.displayFileId,
    this.useCompactKpis = true,
  });

  final int employeeId;
  final String employeeName;
  final String? imageUrl;
  final String? displayFileId;

  /// When true (team drill-in), show employee photo + file id card above KPIs.
  final bool useCompactKpis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(attendanceReportsPeriodProvider);
    final q = AttendanceDetailQuery(
      employeeId: employeeId,
      year: period.year,
      month: period.month,
    );
    final async = ref.watch(attendanceEmployeeDetailProvider(q));
    final title = useCompactKpis ? 'Attendance' : 'My Attendance';

    Future<void> refresh() async {
      ref.invalidate(attendanceEmployeeDetailProvider(q));
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AttendanceGlassChromeHeader(
                title: title,
                trailing: [
                  AttendanceGlassChromeHeader.refreshButton(onPressed: refresh),
                ],
              ),
              Expanded(
                child: async.when(
                  data: (result) => _AttendanceMonthBody(
                    result: result,
                    period: period,
                    showEmployeeCard: useCompactKpis,
                    employeeName: employeeName,
                    imageUrl: imageUrl,
                    fileId: displayFileId?.trim().isNotEmpty == true
                        ? displayFileId!.trim()
                        : employeeId.toString(),
                    onRefresh: refresh,
                    onPreviousMonth: () => ref
                        .read(attendanceReportsPeriodProvider.notifier)
                        .previousMonth(),
                    onNextMonth: () => ref
                        .read(attendanceReportsPeriodProvider.notifier)
                        .nextMonth(),
                  ),
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: kAttendancePrimary),
                  ),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.w),
                      child: Text(
                        '$e',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: AttendanceDashboardTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceMonthBody extends StatelessWidget {
  const _AttendanceMonthBody({
    required this.result,
    required this.period,
    required this.showEmployeeCard,
    required this.employeeName,
    required this.imageUrl,
    required this.fileId,
    required this.onRefresh,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final Result result;
  final AttendancePeriod period;
  final bool showEmployeeCard;
  final String employeeName;
  final String? imageUrl;
  final String fileId;
  final Future<void> Function() onRefresh;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    final records = result.records ?? [];
    final byDay = recordsByCalendarDay(records);
    final kpis = computeKpisFromResult(result, records);

    return RefreshIndicator(
      color: kAttendancePrimary,
      onRefresh: onRefresh,
      child: ListView(
        primary: false,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(0, 0, 0, 16.h),
        children: [
          AttendanceMonthSwitcherCard(
            period: period,
            margin: EdgeInsets.fromLTRB(14.w, 6.h, 14.w, 10.h),
            onPreviousMonth: onPreviousMonth,
            onNextMonth: onNextMonth,
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showEmployeeCard) ...[
                  _EmployeeProfileCard(
                    employeeName: employeeName,
                    imageUrl: imageUrl,
                    fileId: fileId,
                  ),
                  SizedBox(height: 10.h),
                ],
                AttendanceKpiStrip(kpi: kpis, useAttendanceTheme: true),
                SizedBox(height: 10.h),
                AttendanceMonthCalendar(
                  year: period.year,
                  month: period.month,
                  recordsByDay: byDay,
                  useAttendanceTheme: true,
                  onDayTap: (d, r) {
                    showAttendanceDailyDetailSheet(context, day: d, record: r);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeProfileCard extends StatelessWidget {
  const _EmployeeProfileCard({
    required this.employeeName,
    required this.imageUrl,
    required this.fileId,
  });

  final String employeeName;
  final String? imageUrl;
  final String fileId;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.96),
            _kSkyLight.withValues(alpha: 0.88),
            _kSkyMid.withValues(alpha: 0.35),
          ],
        ),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.92)),
        boxShadow: [
          BoxShadow(
            color: kAttendancePrimary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: kAttendancePrimary.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: AttendanceNetworkAvatar(
              radius: 24.r,
              imageUrl: imageUrl,
              fallback: Text(
                employeeName.isNotEmpty
                    ? employeeName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16.sp,
                  color: kAttendancePrimary,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employeeName,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16.sp,
                    color: AttendanceDashboardTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                Text(
                  fileId,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AttendanceDashboardTheme.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
