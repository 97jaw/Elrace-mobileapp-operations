import 'package:el_race/core/utils/shared_pref.dart';

/// Login-based access flags for the projects dashboard module.
class ProjectsDashboardAccess {
  ProjectsDashboardAccess._();

  /// True when user has management role (`is_management` or `x_is_management`).
  static bool isManagementUser() {
    final data = SharedPref.getLoginData().result?.data;
    if (data == null) return false;

    final caps = data.roleCapabilities;
    if (caps != null) {
      final mgmt = caps['x_is_management'] ?? caps['is_management'];
      if (mgmt == true) return true;
    }

    return data.isManagement == true;
  }

  /// True when user is a project manager (`is_pm` / `x_is_pm` / `x_is_pm_role`).
  static bool isProjectManagerUser() {
    final data = SharedPref.getLoginData().result?.data;
    if (data == null) return false;

    if (data.isPm == true) return true;

    final caps = data.roleCapabilities;
    if (caps != null) {
      if (caps['x_is_pm'] == true || caps['x_is_pm_role'] == true) {
        return true;
      }
    }

    return false;
  }

  /// True when user is an HR manager (`is_hr_manager` / capability variants).
  static bool isHrManagerUser() {
    final data = SharedPref.getLoginData().result?.data;
    if (data == null) return false;

    if (data.isHrManager == true) return true;

    final caps = data.roleCapabilities;
    if (caps != null) {
      if (caps['x_is_hr_manager'] == true ||
          caps['is_hr_manager'] == true ||
          caps['x_is_hr'] == true) {
        return true;
      }
    }

    return false;
  }

  /// Company Documents (HRMS) — HR manager, management, or project manager.
  static bool canAccessCompanyDocuments() =>
      isHrManagerUser() || isManagementUser() || isProjectManagerUser();

  /// Media "Projects" tab — management or project manager.
  static bool canSeeProjectVideos() =>
      isManagementUser() || isProjectManagerUser();

  /// Domains are applied on the server from the auth token — never pass domains
  /// from the app. This flag only toggles client-side summary vs scoped UI.
  static bool get bypassesDomainScope => isManagementUser();

  /// Apply staff-list / agreement domain filtering for non-management users.
  static bool get shouldApplyDomainScope => !bypassesDomainScope;
}
