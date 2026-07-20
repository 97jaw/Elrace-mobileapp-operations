import 'package:el_race/core/utils/responsive_breakpoints.dart';
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
                borderRadius: BorderRadius.vertical(top: Radius.circular(20.tr)),
              ),
              child: Padding(
                padding: EdgeInsets.all(24.tw),
                child: Column(
                  children: [
                    Container(
                      width: 40.tw,
                      height: 4.th,
                      decoration: BoxDecoration(
                        color: HrModuleColors.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    SizedBox(height: 20.th),
                    Text(header, style: HrModuleTypography.sectionHeading()),
                    SizedBox(height: 16.th),
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
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.tr)),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.tr)),
              child: Container(
                color: HrModuleColors.surface,
                child: ListView(
                  controller: scroll,
                  padding: EdgeInsets.zero,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.fromLTRB(20.tw, 14.th, 20.tw, 20.th),
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
                            width: 40.tw,
                            height: 4.th,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          SizedBox(height: 16.th),
                          Text(
                            header,
                            style: HrModuleTypography.pageTitle().copyWith(
                                  fontSize: 18.tsp,
                                  color: HrModuleColors.text,
                                ),
                          ),
                          SizedBox(height: 12.th),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 14.tw,
                              vertical: 8.th,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(12.tr),
                            ),
                            child: Text(
                              statusLabel.toUpperCase(),
                              style: HrModuleTypography.sectionHeading().copyWith(
                                    fontSize: 13.tsp,
                                    color: statusColor,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(20.tw, 18.th, 20.tw, 32.th),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Punches',
                            style: HrModuleTypography.sectionHeading()
                                .copyWith(fontSize: 14.tsp),
                          ),
                          SizedBox(height: 8.th),
                          _punchRow(Icons.login, 'Check-in', record.checkIn),
                          _punchRow(
                            Icons.logout,
                            'Check-out',
                            record.checkOut?.toString() ?? '—',
                          ),
                          SizedBox(height: 16.th),
                          Text(
                            'Summary',
                            style: HrModuleTypography.sectionHeading()
                                .copyWith(fontSize: 14.tsp),
                          ),
                          SizedBox(height: 8.th),
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
    padding: EdgeInsets.only(bottom: 8.th),
    child: Row(
      children: [
        Icon(icon, size: 20.tsp, color: HrModuleColors.primary),
        SizedBox(width: 10.tw),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: HrModuleTypography.caption().copyWith(fontSize: 11.tsp),
              ),
              Text(
                value,
                style: HrModuleTypography.body().copyWith(fontSize: 13.tsp),
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
    padding: EdgeInsets.only(bottom: 6.th),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: HrModuleTypography.caption().copyWith(fontSize: 12.tsp)),
        Text(v, style: HrModuleTypography.body().copyWith(fontSize: 13.tsp)),
      ],
    ),
  );
}
