/// Keys from Odoo `/api/login/new` → `hr_module_manager` (see elrace_backend_apis).
enum HrManagedModule {
  payslip,
  attendance,
  hrRequest,
  recruitment,
  evaluation,
}

/// Per-HR-submodule manager scope from login; null when API omits `hr_module_manager`.
class HrModuleManagerAccess {
  const HrModuleManagerAccess({
    required this.payslip,
    required this.attendance,
    required this.hrRequest,
    required this.recruitment,
    required this.evaluation,
  });

  final bool payslip;
  final bool attendance;
  final bool hrRequest;
  final bool recruitment;
  final bool evaluation;

  bool forModule(HrManagedModule m) => switch (m) {
        HrManagedModule.payslip => payslip,
        HrManagedModule.attendance => attendance,
        HrManagedModule.hrRequest => hrRequest,
        HrManagedModule.recruitment => recruitment,
        HrManagedModule.evaluation => evaluation,
      };

  static HrModuleManagerAccess? tryParse(dynamic raw) {
    if (raw == null || raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    return HrModuleManagerAccess(
      payslip: _parseBool(m['payslip']) ?? false,
      attendance: _parseBool(m['attendance']) ?? false,
      hrRequest: _parseBool(m['hr_request']) ?? false,
      recruitment: _parseBool(m['recruitment']) ?? false,
      evaluation: _parseBool(m['evaluation']) ?? false,
    );
  }

  static bool? _parseBool(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().trim().toLowerCase();
    if (s.isEmpty) return null;
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
    return null;
  }
}
