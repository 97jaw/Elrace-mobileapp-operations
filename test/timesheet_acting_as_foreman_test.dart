import 'package:el_race/core/timesheet/models/timesheet_team_member.dart';
import 'package:el_race/core/timesheet/providers/timesheet_acting_session_provider.dart';
import 'package:el_race/core/timesheet/providers/timesheet_role_provider.dart';
import 'package:el_race/core/timesheet/services/timesheet_project_access_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _foreman = TimesheetRoleResolution(
  role: TimesheetEffectiveRole.foreman,
  hrWideScope: false,
);

const _pm = TimesheetRoleResolution(
  role: TimesheetEffectiveRole.pm,
  hrWideScope: false,
);

const _hrWidePm = TimesheetRoleResolution(
  role: TimesheetEffectiveRole.pm,
  hrWideScope: true,
);

/// Container whose raw login resolution is fixed, so these tests exercise the
/// acting-as layer without touching SharedPref.
ProviderContainer _containerFor(TimesheetRoleResolution login) {
  final container = ProviderContainer(
    overrides: [tmRoleResolutionProvider.overrideWithValue(login)],
  );
  addTearDown(container.dispose);
  return container;
}

TimesheetTeamMember _member(int id, String name) =>
    TimesheetTeamMember(employeeId: id, name: name, fileId: '$id');

void main() {
  tearDown(() => TimesheetActingScope.setForNotifier(null));

  group('real foreman login is unaffected', () {
    test('effective resolution is the untouched login resolution', () {
      final container = _containerFor(_foreman);

      expect(
        container.read(tmEffectiveResolutionProvider),
        same(container.read(tmRoleResolutionProvider)),
      );
      expect(container.read(tmEffectiveRoleProvider),
          TimesheetEffectiveRole.foreman);
    });

    test('can still submit, and reads carry no as_employee_id hint', () {
      final container = _containerFor(_foreman);

      expect(
        container.read(tmEffectiveResolutionProvider).canSubmitTimesheet,
        isTrue,
      );
      expect(container.read(tmActingEmployeeIdProvider), isNull);
    });

    test('persistence backstop is a no-op outside an acting session', () {
      expect(TimesheetActingScope.isActing, isFalse);
      expect(TimesheetActingScope.refusePersist('queue.enqueue'), isFalse);
    });
  });

  group('PM acting as one of their foremen', () {
    test('reads resolve as that foreman, writes stay blocked', () {
      final container = _containerFor(_pm);
      container
          .read(tmActingSessionProvider.notifier)
          .enter(_member(42, 'Ali Hassan'));

      final resolution = container.read(tmEffectiveResolutionProvider);
      expect(resolution.role, TimesheetEffectiveRole.foreman);
      expect(resolution.isActingAsForeman, isTrue);
      expect(resolution.canSubmitTimesheet, isFalse);
      expect(container.read(tmActingEmployeeIdProvider), 42);
    });

    test('HR-wide PM loses portfolio scope while acting', () {
      final container = _containerFor(_hrWidePm);
      expect(container.read(tmEffectiveResolutionProvider).hrWideScope, isTrue);

      container
          .read(tmActingSessionProvider.notifier)
          .enter(_member(7, 'Sara Nabil'));

      expect(container.read(tmEffectiveResolutionProvider).hrWideScope, isFalse);
    });

    test('exiting restores the PM context exactly', () {
      final container = _containerFor(_pm);
      final notifier = container.read(tmActingSessionProvider.notifier);

      notifier.enter(_member(42, 'Ali Hassan'));
      notifier.exit();

      expect(container.read(tmActingSessionProvider), isNull);
      expect(container.read(tmActingEmployeeIdProvider), isNull);
      expect(
        container.read(tmEffectiveResolutionProvider).role,
        TimesheetEffectiveRole.pm,
      );
      expect(TimesheetActingScope.isActing, isFalse);
    });

    test('project scope switches to the foreman supervisor branch', () {
      final rows = [
        TimesheetProjectAccessService.parseAccessRow({
          'project_id': 'p1',
          'supervisor_ids': [42],
          'staff_line_ids': [
            {'employee_id': 99, 'access': 'project'},
          ],
        }),
        TimesheetProjectAccessService.parseAccessRow({
          'project_id': 'p2',
          'supervisor_ids': [7],
          'staff_line_ids': [
            {'employee_id': 99, 'access': 'project'},
          ],
        }),
      ];

      // PM 99 staffs both projects; foreman 42 supervises only p1.
      final asPm = TimesheetProjectAccessService.filterForRole(
        rows: rows,
        resolution: _pm,
        employeeId: 99,
      );
      expect(asPm.map((r) => r.projectId), ['p1', 'p2']);

      final asForeman = TimesheetProjectAccessService.filterForRole(
        rows: rows,
        resolution: const TimesheetRoleResolution(
          role: TimesheetEffectiveRole.foreman,
          hrWideScope: false,
          isActingAsForeman: true,
        ),
        employeeId: 42,
      );
      expect(asForeman.map((r) => r.projectId), ['p1']);
    });

    test('persistence backstop trips loudly while acting', () {
      TimesheetActingScope.setForNotifier(
        TimesheetActingSession.fromMember(_member(42, 'Ali Hassan')),
      );

      expect(
        () => TimesheetActingScope.refusePersist('queue.enqueue'),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
