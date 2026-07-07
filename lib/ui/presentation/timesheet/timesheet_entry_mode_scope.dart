import 'package:el_race/core/timesheet/providers/timesheet_entry_mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sets [timesheetEntryModeProvider] for the whole module navigation stack.
class TimesheetEntryModeScope extends ConsumerStatefulWidget {
  const TimesheetEntryModeScope({
    super.key,
    required this.mode,
    required this.child,
  });

  final TimesheetEntryMode mode;
  final Widget child;

  @override
  ConsumerState<TimesheetEntryModeScope> createState() =>
      _TimesheetEntryModeScopeState();
}

class _TimesheetEntryModeScopeState
    extends ConsumerState<TimesheetEntryModeScope> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(timesheetEntryModeStateProvider.notifier).setMode(widget.mode);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
