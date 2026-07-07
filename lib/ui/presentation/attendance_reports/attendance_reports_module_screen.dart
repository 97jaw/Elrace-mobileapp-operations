import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_service_screen_backdrop.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/ui/presentation/attendance_reports/attendance_reports_scope.dart';
import 'package:el_race/ui/presentation/attendance_reports/attendance_reports_session.dart';
import 'package:el_race/ui/presentation/attendance_reports/employee_attendance_reports_screen.dart';
import 'package:el_race/ui/presentation/attendance_reports/screens/attendance_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Module 5 entry — scope from `/api/attendance/list` (TASKS §2).
class AttendanceReportsModuleScreen extends ConsumerWidget {
  const AttendanceReportsModuleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(attendanceSessionProvider);

    final loginRevision = ref.watch(loginSessionRevisionProvider);
    final loginManager = attendanceLoginSuggestsManagerScope();

    return async.when(
      // Avoid showing the previous user's scope while a new session loads.
      skipLoadingOnReload: false,
      data: (session) {
        final refreshing = async.isLoading;
        var scope = session.scope;
        if (refreshing &&
            loginManager &&
            scope == AttendanceReportsScope.employee) {
          scope = AttendanceReportsScope.manager;
        }
        if (scope == AttendanceReportsScope.manager) {
          return AttendanceDashboardScreen(
            key: ValueKey('dash-att-$loginRevision'),
            session: session,
            sessionRefreshing: refreshing,
          );
        }
        return EmployeeAttendanceReportsScreen(
          key: ValueKey('emp-att-$loginRevision'),
          session: session,
          sessionRefreshing: refreshing,
        );
      },
      loading: () => Scaffold(
        backgroundColor:
            HrServiceScreenBackdrop.scaffoldBackground(HrServiceScreenKind.attendance),
        appBar: AppBar(
          backgroundColor: HrModuleColors.surface,
          foregroundColor: HrModuleColors.text,
          elevation: 0,
          title: Text(
            'Attendance',
            style: HrModuleTypography.pageTitle().copyWith(fontSize: 18.sp),
          ),
        ),
        body: HrServiceScreenBackdrop.wrap(
          kind: HrServiceScreenKind.attendance,
          child: const Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => Scaffold(
        backgroundColor:
            HrServiceScreenBackdrop.scaffoldBackground(HrServiceScreenKind.attendance),
        appBar: AppBar(
          backgroundColor: HrModuleColors.surface,
          foregroundColor: HrModuleColors.text,
          elevation: 0,
          title: Text(
            'Attendance',
            style: HrModuleTypography.pageTitle().copyWith(fontSize: 18.sp),
          ),
        ),
        body: HrServiceScreenBackdrop.wrap(
          kind: HrServiceScreenKind.attendance,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Text(
                '$e',
                textAlign: TextAlign.center,
                style: HrModuleTypography.body(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
