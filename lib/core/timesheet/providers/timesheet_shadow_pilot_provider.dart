import 'package:flutter/foundation.dart';

/// Set when any timesheet API response includes `shadow: true`.
///
/// A [ValueNotifier] so the Dio transport (no Ref) can flip it and the
/// timesheet header can listen with [ValueListenableBuilder].
class TimesheetShadowPilotFlag {
  TimesheetShadowPilotFlag._();

  static final ValueNotifier<bool> active = ValueNotifier<bool>(false);

  static void markActive() {
    if (!active.value) {
      active.value = true;
    }
  }

  static void reset() {
    active.value = false;
  }
}
