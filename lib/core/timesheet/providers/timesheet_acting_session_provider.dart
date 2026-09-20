import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/timesheet/models/timesheet_team_member.dart';
import 'package:el_race/core/timesheet/services/timesheet_acting_scope.dart';
import 'package:el_race/core/timesheet/services/timesheet_project_access_service.dart';
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
  /// Login employee the current acting session (if any) belongs to.
  int? _boundLoginEmployeeId;

  @override
  TimesheetActingSession? build() {
    // Token refresh bumps this revision. We must NOT clear acting on every
    // bump — only when the logged-in employee actually changes (logout /
    // switch user). Clearing on refresh disposed in-flight capture task loads
    // and kicked PMs out of "Access with Foreman" mid-flow.
    ref.watch(loginSessionRevisionProvider);
    int? loginId;
    try {
      loginId = TimesheetProjectAccessService.loginEmployeeId();
    } catch (_) {
      loginId = null;
    }

    if (_boundLoginEmployeeId != null && _boundLoginEmployeeId != loginId) {
      TimesheetActingScope.setForNotifier(null);
      _boundLoginEmployeeId = loginId;
      return null;
    }

    _boundLoginEmployeeId = loginId;
    return TimesheetActingScope.current;
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
