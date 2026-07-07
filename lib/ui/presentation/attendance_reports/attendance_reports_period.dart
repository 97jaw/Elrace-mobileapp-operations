import 'package:flutter_riverpod/flutter_riverpod.dart';

class AttendancePeriod {
  const AttendancePeriod({required this.year, required this.month});

  final int year;
  final int month;
}

final attendanceReportsPeriodProvider =
    NotifierProvider<AttendanceReportsPeriodNotifier, AttendancePeriod>(
  AttendanceReportsPeriodNotifier.new,
);

class AttendanceReportsPeriodNotifier extends Notifier<AttendancePeriod> {
  @override
  AttendancePeriod build() {
    final n = DateTime.now();
    return AttendancePeriod(year: n.year, month: n.month);
  }

  void setPeriod(int year, int month) =>
      state = AttendancePeriod(year: year, month: month);

  void previousMonth() {
    final d = DateTime(state.year, state.month - 1);
    state = AttendancePeriod(year: d.year, month: d.month);
  }

  void nextMonth() {
    final d = DateTime(state.year, state.month + 1);
    state = AttendancePeriod(year: d.year, month: d.month);
  }
}
