import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which home card opened the module — drives project-detail chrome and tabs.
enum TimesheetEntryMode {
  timesheet,
  siteManagement,
}

final timesheetEntryModeStateProvider =
    NotifierProvider<TimesheetEntryModeNotifier, TimesheetEntryMode>(
  TimesheetEntryModeNotifier.new,
);

class TimesheetEntryModeNotifier extends Notifier<TimesheetEntryMode> {
  @override
  TimesheetEntryMode build() => TimesheetEntryMode.timesheet;

  void setMode(TimesheetEntryMode mode) => state = mode;
}

final timesheetEntryModeProvider = Provider<TimesheetEntryMode>(
  (ref) => ref.watch(timesheetEntryModeStateProvider),
);
