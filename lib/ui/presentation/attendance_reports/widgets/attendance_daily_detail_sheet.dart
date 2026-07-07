import 'package:el_race/core/theme/day_status_colors.dart';
import 'package:el_race/core/theme/hr_module_colors.dart';
import 'package:el_race/core/theme/hr_module_typography.dart';
import 'package:el_race/ui/presentation/Attendace_list/model/attendance_model.dart';
import 'package:el_race/ui/presentation/attendance_reports/attendance_report_helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

/// E2 — daily detail bottom sheet with status-colored chrome.
Future<void> showAttendanceDailyDetailSheet(
  BuildContext context, {
  required DateTime day,
  AttendanceRecord? record,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final header = DateFormat('EEEE, dd MMM yyyy').format(day);
      final statusColor = record == null
          ? HrModuleColors.mutedText
          : DayStatusTokens.colorForBackendStatus(displayStatusKey(record));
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.58,
        minChildSize: 0.38,
        maxChildSize: 0.92,
        builder: (_, scroll) {
          if (record == null) {
            return Container(
              decoration: BoxDecoration(
                color: HrModuleColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
              ),
              child: Padding(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  children: [
                    Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: HrModuleColors.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Text(header, style: HrModuleTypography.sectionHeading()),
                    SizedBox(height: 16.h),
                    Text(
                      'No attendance data for this day.',
                      style: HrModuleTypography.body(),
                    ),
                  ],
                ),
              ),
            );
          }
          final statusKey = displayStatusKey(record);
          final statusLabel = DayStatusTokens.labelForBackendStatus(statusKey);

          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
              child: Container(
                color: HrModuleColors.surface,
                child: ListView(
                  controller: scroll,
                  padding: EdgeInsets.zero,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 20.h),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _brightMix(statusColor),
                            statusColor.withValues(alpha: 0.22),
                          ],
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 40.w,
                            height: 4.h,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            header,
                            style: HrModuleTypography.pageTitle().copyWith(
                                  fontSize: 18.sp,
                                  color: HrModuleColors.text,
                                ),
                          ),
                          SizedBox(height: 12.h),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 14.w,
                              vertical: 8.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Text(
                              statusLabel.toUpperCase(),
                              style: HrModuleTypography.sectionHeading().copyWith(
                                    fontSize: 13.sp,
                                    color: statusColor,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 32.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Punches',
                            style: HrModuleTypography.sectionHeading()
                                .copyWith(fontSize: 14.sp),
                          ),
                          SizedBox(height: 8.h),
                          _punchRow(Icons.login, 'Check-in', record.checkIn),
                          _punchRow(
                            Icons.logout,
                            'Check-out',
                            record.checkOut?.toString() ?? '—',
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            'Summary',
                            style: HrModuleTypography.sectionHeading()
                                .copyWith(fontSize: 14.sp),
                          ),
                          SizedBox(height: 8.h),
                          _summaryRow(
                            'Worked hours',
                            record.workedHours.toStringAsFixed(2),
                          ),
                          if ((record.attendanceType ?? '').isNotEmpty)
                            _summaryRow('Type', record.attendanceType!),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Color _brightMix(Color c) => Color.lerp(c, Colors.white, 0.82)!;

Widget _punchRow(IconData icon, String label, String value) {
  return Padding(
    padding: EdgeInsets.only(bottom: 8.h),
    child: Row(
      children: [
        Icon(icon, size: 20.sp, color: HrModuleColors.primary),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: HrModuleTypography.caption().copyWith(fontSize: 11.sp),
              ),
              Text(
                value,
                style: HrModuleTypography.body().copyWith(fontSize: 13.sp),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _summaryRow(String k, String v) {
  return Padding(
    padding: EdgeInsets.only(bottom: 6.h),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: HrModuleTypography.caption().copyWith(fontSize: 12.sp)),
        Text(v, style: HrModuleTypography.body().copyWith(fontSize: 13.sp)),
      ],
    ),
  );
}
