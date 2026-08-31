import 'package:el_race/ui/presentation/Email%20Approval/utils/approval_display_helpers.dart';

/// Shared field resolvers for HR waiting-approval list cards.
class HrApprovalDisplay {
  HrApprovalDisplay._();

  static const _dateKeys = [
    'date',
    'request_date',
    'request_date_from',
    'start_date',
    'submission_date',
    'created_date',
    'create_date',
    'write_date',
    'requestDate',
  ];

  static const Map<String, String> _leaveTypeLabels = {
    'annual': 'Annual Leave',
    'short': 'Short Leave',
    'maternity': 'Maternity Leave',
    'parental': 'Parental Leave',
    'death': 'Death Leave',
    'compensation': 'Compensation Leave',
    'sick': 'Sick Leave',
    'emergency': 'Emergency Leave',
    'unpaid': 'Unpaid Leave',
  };

  static String sequence(Map<dynamic, dynamic> item) {
    return _pick(item, const [
      'name',
      'request_no',
      'ref_no',
      'reference_no',
      'req_no',
    ]);
  }

  static String requestTypeName(Map<dynamic, dynamic> item) {
    final direct = _pick(item, const [
      'request_type',
      'request_type_name',
      'requestType',
    ]);
    if (direct.isNotEmpty) return direct;

    final typeId = item['request_type_id'];
    if (typeId is List && typeId.length > 1) {
      return typeId[1]?.toString().trim() ?? '';
    }
    if (typeId is Map) {
      return typeId['name']?.toString().trim() ?? '';
    }
    return '';
  }

  static bool isLeaveRequest(Map<dynamic, dynamic> item) {
    final code = _pick(item, const [
      'request_type_code',
      'request_code',
      'type_code',
    ]).toLowerCase();
    if (code == 'annualleave' || code.startsWith('annualleave_')) {
      return true;
    }

    final requestType = requestTypeName(item).toLowerCase();
    if (requestType.contains('leave')) return true;

    // Do NOT treat a leftover leave_request_type on non-leave records
    // (e.g. Sim Card) as a leave request — that caused "Annual" under SIM.
    return false;
  }

  static String leaveSubtypeLabel(Map<dynamic, dynamic> item) {
    if (!isLeaveRequest(item)) return '';

    final requestType = requestTypeName(item);
    final apiType = _pick(item, const ['type', 'title']);
    if (apiType.isNotEmpty &&
        apiType.toLowerCase() != requestType.toLowerCase()) {
      return apiType;
    }

    final raw = _pick(item, const [
      'leave_request_subtype',
      'leave_request_type',
      'leave_request_type_labor',
      'leave_type',
      'holiday_status_name',
    ]);
    if (raw.isEmpty) return '';

    final normalized = raw.trim().toLowerCase().replaceAll(' ', '_');
    return _leaveTypeLabels[normalized] ?? _titleCase(raw);
  }

  static String formattedDate(Map<dynamic, dynamic> item) {
    return ApprovalDisplayHelpers.formatFullDateFromItem(item, _dateKeys);
  }

  static bool shouldHideDraftStatus(Map<dynamic, dynamic> item) {
    final raw = _pick(item, const ['state', 'status'], fallback: '').toUpperCase();
    return raw == 'DRAFT';
  }

  static String _titleCase(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return trimmed
        .split(RegExp(r'[_\s]+'))
        .where((part) => part.isNotEmpty)
        .map((part) {
      final lower = part.toLowerCase();
      return '${lower[0].toUpperCase()}${lower.substring(1)}';
    }).join(' ');
  }

  static String _pick(
    Map<dynamic, dynamic> item,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = item[key];
      if (value == null || value == false || value == true) continue;
      final str = value.toString().trim();
      if (str.isEmpty ||
          str.toLowerCase() == 'null' ||
          str.toLowerCase() == 'false') {
        continue;
      }
      return str;
    }
    return fallback;
  }
}
