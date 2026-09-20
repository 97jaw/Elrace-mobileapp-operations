import 'package:el_race/core/timesheet/models/timesheet_team_member.dart';
import 'package:flutter/foundation.dart';

/// A PM / HR user temporarily viewing the Timesheet module as one of their own
/// foremen (`hr.employee.x_foreman_ids`).
///
/// Read paths follow [foremanEmployeeId]; every write path is refused.
/// Submitting attendance requires a real foreman login because
/// `account.analytic.line` records no submitter, so an impersonated submit
/// would be indistinguishable from a genuine on-site capture.
class TimesheetActingSession {
  const TimesheetActingSession({
    required this.foremanEmployeeId,
    required this.foremanName,
    this.fileId,
    this.avatarUrl,
  });

  factory TimesheetActingSession.fromMember(TimesheetTeamMember member) {
    return TimesheetActingSession(
      foremanEmployeeId: member.employeeId,
      foremanName: member.name,
      fileId: member.fileId,
      avatarUrl: member.imageUrl,
    );
  }

  final int foremanEmployeeId;
  final String foremanName;
  final String? fileId;
  final String? avatarUrl;
}

/// Process-wide mirror of the acting session for code that cannot reach a
/// Riverpod `ref` (offline queue / capture store services).
///
/// In-memory only — never persisted, so a cold start always returns the user
/// to their own context. Kept in sync by `TimesheetActingSessionNotifier`.
abstract final class TimesheetActingScope {
  static TimesheetActingSession? _current;

  static TimesheetActingSession? get current => _current;

  static bool get isActing => _current != null;

  /// Only `TimesheetActingSessionNotifier` should call this.
  static void setForNotifier(TimesheetActingSession? session) {
    _current = session;
  }

  /// Backstop for services that persist work (offline queue, capture store).
  ///
  /// Returns `true` when the caller must abort. Reaching this means a write
  /// path was not guarded at the UI layer: loud in debug, silently refused in
  /// release so a user never loses data to a crash.
  static bool refusePersist(String debugLabel) {
    if (!isActing) return false;
    assert(
      false,
      'TimesheetActingScope: $debugLabel attempted a write while acting as '
      'foreman "${_current?.foremanName}". Guard the calling UI path with '
      'TimesheetActingGuard.blockWrite.',
    );
    debugPrint('TimesheetActingScope: refused $debugLabel while acting.');
    return true;
  }
}
