import 'package:el_race/core/utils/shared_pref.dart';
import 'package:el_race/ui/presentation/my_projects/presentation/utils/projects_dashboard_access.dart';

/// Gate for AI Drawing Studio home widget / entry.
///
/// Management-only, and Cognito email + pool IDs must be present on login.
class DrawingStudioAccess {
  DrawingStudioAccess._();

  static bool canShowWidget() {
    if (!ProjectsDashboardAccess.isManagementUser()) return false;

    final data = SharedPref.getLoginData().result?.data;
    if (data == null) return false;

    if (data.drawingStudioEnabled == true) return true;

    final email = data.xCognitoEmail?.trim() ?? '';
    final poolId = data.userPoolId?.trim() ?? '';
    final clientId = data.poolClientId?.trim() ?? '';
    return email.isNotEmpty && poolId.isNotEmpty && clientId.isNotEmpty;
  }

  static String? cognitoEmail() {
    final email = SharedPref.getLoginData().result?.data?.xCognitoEmail?.trim();
    if (email == null || email.isEmpty) return null;
    return email;
  }

  static String? userPoolId() {
    final v = SharedPref.getLoginData().result?.data?.userPoolId?.trim();
    if (v == null || v.isEmpty) return null;
    return v;
  }

  static String? poolClientId() {
    final v = SharedPref.getLoginData().result?.data?.poolClientId?.trim();
    if (v == null || v.isEmpty) return null;
    return v;
  }

  static String cognitoRegion() {
    final data = SharedPref.getLoginData().result?.data;
    final fromLogin = data?.cognitoRegion?.trim();
    if (fromLogin != null && fromLogin.isNotEmpty) return fromLogin;

    final poolId = data?.userPoolId?.trim() ?? '';
    if (poolId.contains('_')) {
      return poolId.split('_').first;
    }
    return 'eu-north-1';
  }
}
