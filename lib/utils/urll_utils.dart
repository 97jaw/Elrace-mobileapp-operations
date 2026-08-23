class UrlUtil {
  static const String baseUrl = 'https://erp.elrace.com/api/';
  static const String login = 'login/new';
  static const String contactApi = 'employee/listx';
  static const String employeeProfileApi = 'employee/profile';
  static const String employeeProfileContractApi = 'employee/profile/contract';
  static const String employeeProfileDocumentsApi = 'employee/profile/documents';
  static const String employeeProfileFleetApi = 'employee/profile/fleet';
  static const String checkInApi = 'check_in';
  static const String checkOutApi = 'check_out';
  static const String checkinContextApi = 'attendance/checkin_context';
  static const String checkinProjectsApi = 'attendance/checkin_projects';
  static const String validateUserLocationApi = 'validate_user_location';
  static const String attendanceListApi = 'attendance/list';
  static const String mediaAttachmentsApi = 'media_attachments';
  static const String prepareShareApi = 'prepare_share';
  static const String qrCodeApi = 'qr_code/';
  static const String myActionsApi = 'my_actions';
  static const String getContentsApi = 'get_contents';
  static const String getContentsGroupedApi = 'get_contents/grouped';
  static const String firebaseRefreshToken = 'firebase/refresh_token';

  /// Current user's stamp binaries only (not on login / not session refresh).
  static const String myStamps = 'users/my_stamps';

  /// Persist FCM device token on res.users.expo_token (backend push target).
  static const String saveExpoToken = 'save_expo_token';

  /// Authenticated Hub QR login relay (mobile → Odoo → Hub).
  static const String hubQrLoginApi = 'hub/qr-login';
}
