import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/timesheet/models/timesheet_team_member.dart';
import 'package:el_race/core/timesheet/services/timesheet_acting_scope.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

export 'package:el_race/core/timesheet/services/timesheet_acting_scope.dart'
    show TimesheetActingSession, TimesheetActingScope;

/// `null` unless a PM / HR user explicitly entered an acting session.
///
/// A real foreman login never sets this, so every foreman code path behaves
/// exactly as it did before this feature existed.
final tmActingSessionProvider =
    NotifierProvider<TimesheetActingSessionNotifier, TimesheetActingSession?>(
  TimesheetActingSessionNotifier.new,
);

class TimesheetActingSessionNotifier extends Notifier<TimesheetActingSession?> {
  @override
  TimesheetActingSession? build() {
    // Rebuilding on login/logout drops any acting session with the session.
    ref.watch(loginSessionRevisionProvider);
    TimesheetActingScope.setForNotifier(null);
    return null;
  }

  void enter(TimesheetTeamMember foreman) {
    final session = TimesheetActingSession.fromMember(foreman);
    TimesheetActingScope.setForNotifier(session);
    state = session;
  }

  void exit() {
    TimesheetActingScope.setForNotifier(null);
    state = null;
  }
}

/// Employee id that timesheet reads should resolve against: the acted-as
/// foreman when acting, otherwise `null` for the logged-in employee.
final tmActingEmployeeIdProvider = Provider<int?>((ref) {
  return ref.watch(tmActingSessionProvider)?.foremanEmployeeId;
});
