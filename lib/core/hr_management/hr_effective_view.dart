import 'package:el_race/core/hr_management/hr_module_manager_access.dart';
import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/signin/data/model.dart';

/// Resolved HR Management landing experience — SRD §1.4.
///
/// When login includes [Data.hrModuleManager] (live `/api/login/new`), that map is
/// authoritative for **whether** the user has any HR manager scope. Otherwise a
/// line manager (`is_management` / `is_pm`) with no HR flags would still see the
/// full HR manager hub because those booleans are global in Odoo.
///
/// Inside “has HR manager scope”, precedence stays:
/// `is_hr_manager` → HR Manager tier → `is_management` / `is_pm` → Manager tier
/// → else Manager tier (HR-only role lines such as evaluation without line mgmt).
enum HrEffectiveView {
  employee,
  manager,
  hrManager,
}

extension HrEffectiveViewX on HrEffectiveView {
  String get label => switch (this) {
        HrEffectiveView.employee => 'Employee',
        HrEffectiveView.manager => 'Manager',
        HrEffectiveView.hrManager => 'HR Manager',
      };
}

bool _anyHrSubmoduleManager(Data data) {
  final s = data.hrModuleManager;
  if (s == null) return false;
  return s.payslip ||
      s.attendance ||
      s.hrRequest ||
      s.recruitment ||
      s.evaluation;
}

/// Computes view from login [Data] (no session override).
HrEffectiveView hrEffectiveViewFromData(Data? data) {
  if (data == null) return HrEffectiveView.employee;

  final hasSpec = data.hrModuleManager != null;
  if (hasSpec) {
    if (!_anyHrSubmoduleManager(data)) {
      if (data.isHrManager == true) return HrEffectiveView.hrManager;
      return HrEffectiveView.employee;
    }
    if (data.isHrManager == true) return HrEffectiveView.hrManager;
    return HrEffectiveView.manager;
  }

  if (data.isHrManager == true) return HrEffectiveView.hrManager;
  if (data.isManagement == true || data.isPm == true) {
    return HrEffectiveView.manager;
  }
  return HrEffectiveView.employee;
}

/// Uses [SharedPref] login snapshot.
HrEffectiveView hrEffectiveViewFromLoginPref() {
  final data = SharedPref.getLoginData().result?.data;
  return hrEffectiveViewFromData(data);
}

/// Manager UI for one HR submodule — prefers login `hr_module_manager` when present.
///
/// When the backend omits [Data.hrModuleManager], falls back to the legacy single
/// [HrEffectiveView] (any non-employee view counts as manager for every module).
bool hrServerManagerForModule(Data? data, HrManagedModule module) {
  final spec = data?.hrModuleManager;
  if (spec != null) return spec.forModule(module);
  return hrEffectiveViewFromData(data) != HrEffectiveView.employee;
}
