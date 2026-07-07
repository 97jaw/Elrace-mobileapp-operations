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

  /// Domains are applied on the server from the auth token — never pass domains
  /// from the app. This flag only toggles client-side summary vs scoped UI.
  static bool get bypassesDomainScope => isManagementUser();

  /// Apply staff-list / agreement domain filtering for non-management users.
  static bool get shouldApplyDomainScope => !bypassesDomainScope;
}
