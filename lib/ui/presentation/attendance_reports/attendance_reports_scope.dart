import 'package:el_race/core/hr_management/hr_effective_view.dart';
import 'package:el_race/core/hr_management/hr_module_manager_access.dart';
import 'package:el_race/core/utils/shared_pref.dart';

/// Module 5 — who sees team chrome vs employee-only (from API after list call).
enum AttendanceReportsScope {
  employee,
  manager,
}

/// Login snapshot — used before / while list API loads (Module 5 / HR roles).
bool attendanceLoginSuggestsManagerScope() {
  final data = SharedPref.getLoginDataOrNull()?.result?.data;
  if (data == null) return false;
  if (hrServerManagerForModule(data, HrManagedModule.attendance)) return true;
  if (data.isAttendanceManager == true) return true;
  final caps = data.roleCapabilities;
  if (caps != null && caps['x_is_attendance_role'] == true) return true;
  return false;
}
