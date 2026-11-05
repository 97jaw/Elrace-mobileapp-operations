import 'package:el_race/ui/presentation/attendance_checkin/models/checkin_context_model.dart';

/// Visual state for the check-in location status card.
enum CheckinLocationCardState {
  inside,
  outside,
  waitingGps,
  anywhere,
  noLinkedLocation,
  mobileDisabled,
}

/// Pure enable / card rules for the check-in bottom sheet (testable).
abstract final class CheckinSheetLogic {
  static bool hasLinkedCoordinates(List<CheckinAllowedProject> projects) {
    return projects.any((p) => p.hasCoordinates);
  }

  static CheckinLocationCardState cardState({
    required CheckinContextModel context,
    required bool checkinWidgetDisabled,
    required List<CheckinAllowedProject> projects,
    required CheckinAllowedProject? selectedProject,
    required bool hasGps,
    required bool isInsideGeofence,
  }) {
    if (checkinWidgetDisabled || !context.mobileCheckinAllowed) {
      return CheckinLocationCardState.mobileDisabled;
    }

    if (context.remote) {
      return CheckinLocationCardState.anywhere;
    }

    final linked = hasLinkedCoordinates(projects);

    if (context.locationRequired) {
      if (!linked) return CheckinLocationCardState.noLinkedLocation;
      if (!hasGps || selectedProject == null) {
        return CheckinLocationCardState.waitingGps;
      }
      return isInsideGeofence
          ? CheckinLocationCardState.inside
          : CheckinLocationCardState.outside;
    }

    // Location not required — anywhere unless the server asks for a linked site.
    if (context.requireLinkedLocation && !linked) {
      return CheckinLocationCardState.noLinkedLocation;
    }
    return CheckinLocationCardState.anywhere;
  }

  static String infoStripMessage(CheckinLocationCardState state) {
    switch (state) {
      case CheckinLocationCardState.inside:
      case CheckinLocationCardState.anywhere:
        return 'Actions available at this location';
      case CheckinLocationCardState.outside:
      case CheckinLocationCardState.waitingGps:
        return 'Move inside the zone to check in';
      case CheckinLocationCardState.noLinkedLocation:
        return 'No linked location — contact HR';
      case CheckinLocationCardState.mobileDisabled:
        return 'Mobile check-in is not enabled for your profile';
    }
  }

  /// Whether the location / geofence gates allow an action (ignores today status).
  static bool actionsAvailable(CheckinLocationCardState state) {
    switch (state) {
      case CheckinLocationCardState.inside:
      case CheckinLocationCardState.anywhere:
        return true;
      case CheckinLocationCardState.outside:
      case CheckinLocationCardState.waitingGps:
      case CheckinLocationCardState.noLinkedLocation:
      case CheckinLocationCardState.mobileDisabled:
        return false;
    }
  }

  static bool checkInEnabled({
    required CheckinLocationCardState cardState,
    required CheckinTodayStatus today,
    required bool apiLoading,
  }) {
    if (apiLoading) return false;
    if (!actionsAvailable(cardState)) return false;
    // A record exists today (checked in, even if already out).
    if (today.checkedIn || today.checkInRecordId != null) return false;
    return true;
  }

  static bool checkOutEnabled({
    required CheckinLocationCardState cardState,
    required CheckinTodayStatus today,
    required bool apiLoading,
  }) {
    if (apiLoading) return false;
    if (!actionsAvailable(cardState)) return false;
    // Stay available after a mid-day gate exit (checkedOut informational only),
    // but office-hours window can still disable (blocked / not_required).
    if (today.checkoutMode == CheckinCheckoutMode.blocked ||
        today.checkoutMode == CheckinCheckoutMode.notRequired) {
      return false;
    }
    return today.canCheckOut;
  }
}
