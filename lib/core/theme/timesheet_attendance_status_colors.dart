import 'package:flutter/material.dart';

import 'timesheet_module_colors.dart';

/// UI colors for normalized attendance `ui_status` values — Module 6 SRD §10.
abstract final class TimesheetAttendanceStatusColors {
  static const Color checkedInBg = TimesheetModuleColors.navyTint;
  static const Color checkedInFg = TimesheetModuleColors.success;
  static const Color checkedOutBg = TimesheetModuleColors.primaryTint;
  static const Color checkedOutFg = TimesheetModuleColors.primary;
  static const Color lateBg = Color(0xFFFFF1D6);
  static const Color lateFg = TimesheetModuleColors.warning;
  static const Color absentBg = Color(0xFFFBE2E2);
  static const Color absentFg = TimesheetModuleColors.danger;
  static const Color manualBg = Color(0xFFE4E8FA);
  static const Color manualFg = TimesheetModuleColors.info;
  static const Color outsideGeofenceBg = Color(0xFFFBE2E2);
  static const Color outsideGeofenceFg = TimesheetModuleColors.danger;
  static const Color pendingSyncBg = TimesheetModuleColors.divider;
  static const Color pendingSyncFg = TimesheetModuleColors.mutedText;

  static Color backgroundFor(String uiStatus) {
    switch (uiStatus.toUpperCase()) {
      case 'CHECKED_IN':
        return checkedInBg;
      case 'CHECKED_OUT':
        return checkedOutBg;
      case 'LATE':
        return lateBg;
      case 'ABSENT':
        return absentBg;
      case 'MANUAL':
        return manualBg;
      case 'OUTSIDE_GEOFENCE':
        return outsideGeofenceBg;
      case 'PENDING_SYNC':
        return pendingSyncBg;
      default:
        return TimesheetModuleColors.primaryTint;
    }
  }

  static Color foregroundFor(String uiStatus) {
    switch (uiStatus.toUpperCase()) {
      case 'CHECKED_IN':
        return checkedInFg;
      case 'CHECKED_OUT':
        return checkedOutFg;
      case 'LATE':
        return lateFg;
      case 'ABSENT':
        return absentFg;
      case 'MANUAL':
        return manualFg;
      case 'OUTSIDE_GEOFENCE':
        return outsideGeofenceFg;
      case 'PENDING_SYNC':
        return pendingSyncFg;
      default:
        return TimesheetModuleColors.primary;
    }
  }
}
