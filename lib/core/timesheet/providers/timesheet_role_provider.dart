import 'package:el_race/core/hr_management/providers/hr_management_providers.dart';
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
  });

  final TimesheetEffectiveRole role;
  final bool hrWideScope;

  /// Foremen submit for labors; PMs review only (Phase 2).
  bool get canSubmitTimesheet => role == TimesheetEffectiveRole.foreman;

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
  return ref.watch(tmRoleResolutionProvider).role;
});

final tmRoleResolutionProvider = Provider<TimesheetRoleResolution>((ref) {
  ref.watch(loginSessionRevisionProvider);
  return tmRoleResolutionFromData(
    SharedPref.getLoginDataOrNull()?.result?.data,
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
