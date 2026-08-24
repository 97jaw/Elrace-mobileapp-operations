/// Named routes for HR Management module — TASKS F.5.
abstract final class HrRouteNames {
  static const String moduleHome = '/hr_management';
  /// Hub — module picker (Requests, Recruitment, …).
  static const String hub = '/hr_management/hub';
  /// E1 / M1 — opens hub; kept for backward-compatible named routes.
  static const String employeeLanding = '/hr_management/employee';
  /// Module 2 entry (placeholder until R1).
  static const String recruitment = '/hr_management/recruitment';
  /// Module 3 — performance evaluation (Odoo-aligned).
  static const String performance = '/hr_management/performance';
  /// Module 4 — payslips.
  static const String payslips = '/hr_management/payslips';
  /// Module 5 — attendance reports (uses existing `/api/attendance/*`; scope from API `user_type`).
  static const String attendanceReports = '/hr_management/attendance_reports';
  /// Circulars and announcements (company communications).
  static const String circularAnnouncements =
      '/hr_management/circular_announcements';
  /// Employee directory — smart search by name / file id.
  static const String employeesProfile = '/hr_management/employees_profile';
  /// Company documents — operating-unit folders (managers / HR / PM).
  static const String companyDocuments = '/hr_management/company_documents';
  /// Module 1 — employee/manager HR requests (from hub or deep link).
  static const String requests = '/hr_management/requests';
  static const String simRequest = '/hr_management/asset/sim';
  static const String carRentRequest = '/hr_management/asset/car_rent';
  static const String carAllowanceRequest = '/hr_management/asset/car_allowance';
  static const String incrementRequest = '/hr_management/request/increment';
  static const String terminationRequest = '/hr_management/request/termination';
  static const String promotionRequest = '/hr_management/request/promotion';
  static const String resignationRequest = '/hr_management/request/resignation';
  static const String encashmentRequest = '/hr_management/request/encashment';
  static const String certificateRequest = '/hr_management/request/certificate';
  static const String loanRequest = '/hr_management/request/loan';
  static const String widgetSandbox = '/hr_management/dev/widgets';
}
