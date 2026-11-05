import 'package:el_race/ui/presentation/attendance_checkin/models/checkin_context_model.dart';
import 'package:el_race/ui/presentation/attendance_checkin/utils/checkin_distance_formatter.dart';
import 'package:el_race/ui/presentation/attendance_checkin/utils/checkin_sheet_logic.dart';
import 'package:flutter_test/flutter_test.dart';

CheckinContextModel _context({
  bool mobile = true,
  bool locationRequired = true,
  bool requireLinked = false,
  bool remote = false,
  bool checkedIn = false,
  bool checkedOut = false,
  bool? canCheckOut,
  CheckinCheckoutMode checkoutMode = CheckinCheckoutMode.open,
  String? checkoutMessage,
}) {
  return CheckinContextModel(
    mobileCheckinAllowed: mobile,
    biotimeOffices: const [],
    biotimeTerminals: const [],
    todayStatus: CheckinTodayStatus(
      checkedIn: checkedIn,
      checkedOut: checkedOut,
      canCheckOut: canCheckOut ?? (checkedIn || checkedOut),
      checkoutMode: checkoutMode,
      checkoutMessage: checkoutMessage,
      checkInTime: checkedIn ? '08:00:00' : null,
      checkOutTime: checkedOut ? '17:00:00' : null,
      checkInRecordId: checkedIn || checkedOut ? 1 : null,
      isToday: true,
    ),
    defaultRadiusM: 100,
    locationRequired: locationRequired,
    requireLinkedLocation: requireLinked,
    remote: remote,
  );
}

CheckinAllowedProject _project({bool hasCoordinates = true}) {
  return CheckinAllowedProject(
    projectId: 1,
    name: 'Site A',
    woRefNo: 'WO-1',
    lat: hasCoordinates ? 25.2 : 0,
    lng: hasCoordinates ? 55.2 : 0,
    geofenceRadiusM: 100,
    accessType: 'staff',
    hasCoordinates: hasCoordinates,
  );
}

void main() {
  group('CheckinDistanceFormatter.formatAway', () {
    test('metres below 1000', () {
      expect(CheckinDistanceFormatter.formatAway(11), '11 m away');
    });

    test('kilometres with one decimal', () {
      expect(CheckinDistanceFormatter.formatAway(1200), '1.2 km away');
    });
  });

  group('CheckinSheetLogic.cardState', () {
    test('inside when location required and in zone', () {
      final state = CheckinSheetLogic.cardState(
        context: _context(),
        checkinWidgetDisabled: false,
        projects: [_project()],
        selectedProject: _project(),
        hasGps: true,
        isInsideGeofence: true,
      );
      expect(state, CheckinLocationCardState.inside);
    });

    test('outside when location required and out of zone', () {
      final state = CheckinSheetLogic.cardState(
        context: _context(),
        checkinWidgetDisabled: false,
        projects: [_project()],
        selectedProject: _project(),
        hasGps: true,
        isInsideGeofence: false,
      );
      expect(state, CheckinLocationCardState.outside);
    });

    test('waiting GPS when location required and no fix', () {
      final state = CheckinSheetLogic.cardState(
        context: _context(),
        checkinWidgetDisabled: false,
        projects: [_project()],
        selectedProject: _project(),
        hasGps: false,
        isInsideGeofence: false,
      );
      expect(state, CheckinLocationCardState.waitingGps);
    });

    test('anywhere when location not required and require_linked false', () {
      final state = CheckinSheetLogic.cardState(
        context: _context(locationRequired: false, requireLinked: false),
        checkinWidgetDisabled: false,
        projects: const [],
        selectedProject: null,
        hasGps: false,
        isInsideGeofence: false,
      );
      expect(state, CheckinLocationCardState.anywhere);
    });

    test('no linked when location not required but require_linked true', () {
      final state = CheckinSheetLogic.cardState(
        context: _context(locationRequired: false, requireLinked: true),
        checkinWidgetDisabled: false,
        projects: const [],
        selectedProject: null,
        hasGps: true,
        isInsideGeofence: false,
      );
      expect(state, CheckinLocationCardState.noLinkedLocation);
    });

    test('anywhere when require_linked true but a project has coords', () {
      final state = CheckinSheetLogic.cardState(
        context: _context(locationRequired: false, requireLinked: true),
        checkinWidgetDisabled: false,
        projects: [_project()],
        selectedProject: _project(),
        hasGps: true,
        isInsideGeofence: false,
      );
      expect(state, CheckinLocationCardState.anywhere);
    });

    test('no linked when location required and no coords', () {
      final state = CheckinSheetLogic.cardState(
        context: _context(),
        checkinWidgetDisabled: false,
        projects: [_project(hasCoordinates: false)],
        selectedProject: null,
        hasGps: true,
        isInsideGeofence: false,
      );
      expect(state, CheckinLocationCardState.noLinkedLocation);
    });

    test('mobile disabled', () {
      final state = CheckinSheetLogic.cardState(
        context: _context(mobile: false),
        checkinWidgetDisabled: false,
        projects: [_project()],
        selectedProject: _project(),
        hasGps: true,
        isInsideGeofence: true,
      );
      expect(state, CheckinLocationCardState.mobileDisabled);
    });
  });

  group('CheckinSheetLogic button matrix', () {
    test('not checked in → check-in only when actions available', () {
      final today = _context().todayStatus;
      expect(
        CheckinSheetLogic.checkInEnabled(
          cardState: CheckinLocationCardState.inside,
          today: today,
          apiLoading: false,
        ),
        isTrue,
      );
      expect(
        CheckinSheetLogic.checkOutEnabled(
          cardState: CheckinLocationCardState.inside,
          today: today,
          apiLoading: false,
        ),
        isFalse,
      );
    });

    test('checked in → check-out only', () {
      final today = _context(checkedIn: true).todayStatus;
      expect(
        CheckinSheetLogic.checkInEnabled(
          cardState: CheckinLocationCardState.inside,
          today: today,
          apiLoading: false,
        ),
        isFalse,
      );
      expect(
        CheckinSheetLogic.checkOutEnabled(
          cardState: CheckinLocationCardState.inside,
          today: today,
          apiLoading: false,
        ),
        isTrue,
      );
    });

    test('checked out → check-in disabled, check-out stays available', () {
      final today = _context(checkedIn: true, checkedOut: true).todayStatus;
      expect(
        CheckinSheetLogic.checkInEnabled(
          cardState: CheckinLocationCardState.inside,
          today: today,
          apiLoading: false,
        ),
        isFalse,
      );
      expect(
        CheckinSheetLogic.checkOutEnabled(
          cardState: CheckinLocationCardState.inside,
          today: today,
          apiLoading: false,
        ),
        isTrue,
      );
    });

    test('remote → anywhere card', () {
      final state = CheckinSheetLogic.cardState(
        context: _context(locationRequired: true, remote: true),
        checkinWidgetDisabled: false,
        projects: const [],
        selectedProject: null,
        hasGps: false,
        isInsideGeofence: false,
      );
      expect(state, CheckinLocationCardState.anywhere);
    });

    test('checkout_mode does not disable check-out button', () {
      for (final mode in [
        CheckinCheckoutMode.blocked,
        CheckinCheckoutMode.notRequired,
        CheckinCheckoutMode.warn,
        CheckinCheckoutMode.open,
      ]) {
        final today = _context(
          checkedIn: true,
          canCheckOut: false,
          checkoutMode: mode,
          checkoutMessage: 'msg',
        ).todayStatus;
        expect(
          CheckinSheetLogic.checkOutEnabled(
            cardState: CheckinLocationCardState.inside,
            today: today,
            apiLoading: false,
          ),
          isTrue,
          reason: 'mode=$mode should still enable when checked in',
        );
      }
    });

    test('checkoutTapKind maps each mode', () {
      expect(
        CheckinSheetLogic.checkoutTapKind(
          _context(checkedIn: true, checkoutMode: CheckinCheckoutMode.blocked)
              .todayStatus,
        ),
        CheckinCheckoutTapKind.blockedInfo,
      );
      expect(
        CheckinSheetLogic.checkoutTapKind(
          _context(
            checkedIn: true,
            checkoutMode: CheckinCheckoutMode.notRequired,
          ).todayStatus,
        ),
        CheckinCheckoutTapKind.notRequiredInfo,
      );
      expect(
        CheckinSheetLogic.checkoutTapKind(
          _context(checkedIn: true, checkoutMode: CheckinCheckoutMode.warn)
              .todayStatus,
        ),
        CheckinCheckoutTapKind.warnConfirm,
      );
      expect(
        CheckinSheetLogic.checkoutTapKind(
          _context(checkedIn: true, checkoutMode: CheckinCheckoutMode.open)
              .todayStatus,
        ),
        CheckinCheckoutTapKind.openConfirm,
      );
    });

    test('outside zone disables both', () {
      final today = _context().todayStatus;
      expect(
        CheckinSheetLogic.checkInEnabled(
          cardState: CheckinLocationCardState.outside,
          today: today,
          apiLoading: false,
        ),
        isFalse,
      );
      expect(
        CheckinSheetLogic.checkOutEnabled(
          cardState: CheckinLocationCardState.outside,
          today: today,
          apiLoading: false,
        ),
        isFalse,
      );
    });

    test('anywhere with require_linked false enables check-in', () {
      final today = _context(locationRequired: false).todayStatus;
      expect(
        CheckinSheetLogic.checkInEnabled(
          cardState: CheckinLocationCardState.anywhere,
          today: today,
          apiLoading: false,
        ),
        isTrue,
      );
    });

    test('no linked location disables both', () {
      final today = _context(
        locationRequired: false,
        requireLinked: true,
      ).todayStatus;
      expect(
        CheckinSheetLogic.checkInEnabled(
          cardState: CheckinLocationCardState.noLinkedLocation,
          today: today,
          apiLoading: false,
        ),
        isFalse,
      );
    });
  });
}
