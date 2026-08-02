import 'package:el_race/ui/presentation/Email%20Approval/utils/approval_display_helpers.dart';

/// Shared field resolvers for Invoice waiting-approval list cards.
class InvoiceApprovalDisplay {
  InvoiceApprovalDisplay._();

  static const _dateKeys = [
    'invoice_date',
    'date_of_invoice',
    'date',
    'request_date',
    'create_date',
    'created_date',
    'write_date',
    'requestDate',
  ];

  static const _woRefKeys = [
    'wo_ref_no',
    'wo_ref',
    'wo_ref_number',
    'work_order_no',
    'work_order_number',
    'w_o',
    'wo_no',
    'wo',
  ];

  static String formattedDate(Map<dynamic, dynamic> item) {
    return ApprovalDisplayHelpers.formatFullDateFromItem(item, _dateKeys);
  }

  /// W.O / reference from related `project.project` on
  /// `x_folder_count_project_id` (`wo_ref_no`), with safe fallbacks.
  static String referenceNumber(Map<dynamic, dynamic> item) {
    final fromLinkedProject = woRefFromProjectLink(
      item['x_folder_count_project_id'],
    );
    if (fromLinkedProject.isNotEmpty) return fromLinkedProject;

    for (final key in const [
      'project',
      'project_id',
      'x_folder_count_project_id',
    ]) {
      final fromProject = woRefFromProjectLink(item[key]);
      if (fromProject.isNotEmpty) return fromProject;
    }

    return _pick(item, const [
      'wo_ref_no',
      'wo_ref',
      'name',
      'invoice_no_code',
      'invoice_no',
      'ref_no',
      'request_no',
      'title',
    ]);
  }

  /// Read `wo_ref_no` from a `project.project` many2one / embedded map.
  /// Never falls back to project display name.
  static String woRefFromProjectLink(dynamic value) {
    if (value == null || value == false || value == true) return '';

    if (value is Map) {
      final map = Map<dynamic, dynamic>.from(value);
      for (final key in _woRefKeys) {
        final str = _scalar(map[key]);
        if (str.isNotEmpty) return str;
      }
      // Nested project payload under common keys.
      for (final nestedKey in const [
        'project',
        'project_id',
        'x_folder_count_project_id',
      ]) {
        if (!map.containsKey(nestedKey)) continue;
        final nested = woRefFromProjectLink(map[nestedKey]);
        if (nested.isNotEmpty) return nested;
      }
      return '';
    }

    if (value is List) {
      // Prefer an embedded project map over Odoo [id, name] pairs.
      for (final entry in value) {
        if (entry is Map) {
          final nested = woRefFromProjectLink(entry);
          if (nested.isNotEmpty) return nested;
        }
      }
      return '';
    }

    return '';
  }

  static bool shouldHideDraftStatus(Map<dynamic, dynamic> item) {
    final raw = _pick(item, const ['state', 'status'], fallback: '').toUpperCase();
    return raw == 'DRAFT';
  }

  static String _scalar(dynamic value) {
    if (value == null || value == false || value == true) return '';
    if (value is Map || value is List) return '';
    final str = value.toString().trim();
    if (str.isEmpty ||
        str.toLowerCase() == 'null' ||
        str.toLowerCase() == 'false') {
      return '';
    }
    return str;
  }

  static String _pick(
    Map<dynamic, dynamic> item,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final str = _scalar(item[key]);
      if (str.isNotEmpty) return str;
      // Many2one [id, name] only as last-resort sequence fallback.
      final value = item[key];
      if (value is List && value.length >= 2) {
        final name = _scalar(value[1]);
        if (name.isNotEmpty) return name;
      }
    }
    return fallback;
  }
}
