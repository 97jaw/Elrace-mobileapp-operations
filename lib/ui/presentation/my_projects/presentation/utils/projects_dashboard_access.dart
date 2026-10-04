import 'package:el_race/core/access/feature_access.dart';
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

  /// HR Management → Employees Profile.
  static bool canAccessEmployeesProfile() => FeatureAccess.allows(
        AppFeature.hrEmployeesProfile,
        legacy: isManagementUser(),
      );

  /// Company Documents (HRMS) — HR manager, management, or project manager.
  static bool canAccessCompanyDocuments() => FeatureAccess.allows(
        AppFeature.hrCompanyDocuments,
        legacy:
            isHrManagerUser() || isManagementUser() || isProjectManagerUser(),
      );

  /// Media "Projects" tab — backend `can_see_project_media` (management, PM or
  /// media role); falls back to management / PM when the flag is absent.
  static bool canSeeProjectVideos() => FeatureAccess.allows(
        AppFeature.mediaProjectsTab,
        legacy: _legacyCanSeeProjectVideos(),
      );

  static bool _legacyCanSeeProjectVideos() {
    final data = SharedPref.getLoginData().result?.data;
    final fromBackend = data?.canSeeProjectMedia;
    if (fromBackend != null) return fromBackend;
    if (data?.roleCapabilities?['x_is_media_role'] == true) return true;
    return isManagementUser() || isProjectManagerUser();
  }

  /// Domains are applied on the server from the auth token — never pass domains
  /// from the app. Portfolio KPIs / client bars use server aggregates for both
  /// management and staff (all statuses except internal/general).
  static bool get bypassesDomainScope => isManagementUser();

  /// Apply staff-list / agreement domain filtering for non-management users
  /// (v1 chart sample fallback only).
  static bool get shouldApplyDomainScope => !bypassesDomainScope;
}
