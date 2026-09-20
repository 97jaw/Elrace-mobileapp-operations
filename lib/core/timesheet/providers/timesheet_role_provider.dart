import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
import 'package:el_race/core/timesheet/providers/timesheet_acting_session_provider.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TimesheetEffectiveRole { foreman, pm }

extension TimesheetEffectiveRoleX on TimesheetEffectiveRole {
  String get label => switch (this) {
        TimesheetEffectiveRole.foreman => 'Foreman',
        TimesheetEffectiveRole.pm => 'PM',
      };
}

class TimesheetRoleResolution {
  const TimesheetRoleResolution({
    required this.role,
    required this.hrWideScope,
    this.isActingAsForeman = false,
  });

  final TimesheetEffectiveRole role;
  final bool hrWideScope;

  /// True when a PM / HR user is viewing the module as one of their foremen.
  ///
  /// Reads follow the foreman, but writes stay blocked: `/api/timesheet/submit`
  /// records no submitter, so an impersonated submit would be
  /// indistinguishable from a genuine on-site capture.
  final bool isActingAsForeman;

  /// Foremen submit for labors; PMs review only (Phase 2).
  bool get canSubmitTimesheet =>
      role == TimesheetEffectiveRole.foreman && !isActingAsForeman;

  bool get canReviewTimesheetReports => role == TimesheetEffectiveRole.pm;
}

final tmDevRoleOverrideProvider =
    NotifierProvider<TmDevRoleOverrideNotifier, TimesheetEffectiveRole?>(
  TmDevRoleOverrideNotifier.new,
);

class TmDevRoleOverrideNotifier extends Notifier<TimesheetEffectiveRole?> {
  @override
  TimesheetEffectiveRole? build() => null;

  void setOverride(TimesheetEffectiveRole? role) => state = role;
}

final tmDevHrWideScopeProvider =
    NotifierProvider<TmDevHrWideScopeNotifier, bool>(
  TmDevHrWideScopeNotifier.new,
);

class TmDevHrWideScopeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setWideScope(bool value) => state = value;
}

final tmEffectiveRoleProvider = Provider<TimesheetEffectiveRole>((ref) {
  return ref.watch(tmEffectiveResolutionProvider).role;
});

/// Raw resolution from login flags, ignoring any acting-as-foreman session.
///
/// Use this only to decide whether a user may *start* an acting session (the
/// Timesheet home gate). Everything that scopes data should watch
/// [tmEffectiveResolutionProvider] instead.
final tmRoleResolutionProvider = Provider<TimesheetRoleResolution>((ref) {
  ref.watch(loginSessionRevisionProvider);
  return tmRoleResolutionFromData(
    SharedPref.getLoginDataOrNull()?.result?.data,
  );
});

/// Resolution after applying an acting-as-foreman session.
///
/// With no acting session this returns [tmRoleResolutionProvider] unchanged, so
/// a real foreman login behaves exactly as before.
final tmEffectiveResolutionProvider = Provider<TimesheetRoleResolution>((ref) {
  final acting = ref.watch(tmActingSessionProvider);
  if (acting == null) return ref.watch(tmRoleResolutionProvider);
  return const TimesheetRoleResolution(
    role: TimesheetEffectiveRole.foreman,
    hrWideScope: false,
    isActingAsForeman: true,
  );
});

bool _roleCap(Data? data, String key) =>
    data?.roleCapabilities?[key] == true;

TimesheetRoleResolution tmRoleResolutionFromData(Data? data) {
  if (data?.isHrManager == true || _roleCap(data, 'x_is_hr_manager')) {
    return const TimesheetRoleResolution(
      role: TimesheetEffectiveRole.pm,
      hrWideScope: true,
    );
  }
  if (data?.isPm == true ||
      _roleCap(data, 'x_is_pm') ||
      _roleCap(data, 'x_is_pm_role')) {
    return const TimesheetRoleResolution(
      role: TimesheetEffectiveRole.pm,
      hrWideScope: false,
    );
  }
  if (data?.isForeman == true || _roleCap(data, 'x_is_foreman')) {
    return const TimesheetRoleResolution(
      role: TimesheetEffectiveRole.foreman,
      hrWideScope: false,
    );
  }

  return const TimesheetRoleResolution(
    role: TimesheetEffectiveRole.foreman,
    hrWideScope: false,
  );
}
