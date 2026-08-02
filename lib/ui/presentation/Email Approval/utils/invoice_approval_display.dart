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

  static String formattedDate(Map<dynamic, dynamic> item) {
    return ApprovalDisplayHelpers.formatFullDateFromItem(item, _dateKeys);
  }

  /// Waiting-list / card reference number (ERP: x_folder_count_project_id).
  static String referenceNumber(Map<dynamic, dynamic> item) {
    return _pickDisplay(item, const [
      'x_folder_count_project_id',
      'name',
      'invoice_no_code',
      'invoice_no',
      'ref_no',
      'request_no',
      'title',
    ]);
  }

  static bool shouldHideDraftStatus(Map<dynamic, dynamic> item) {
    final raw = _pick(item, const ['state', 'status'], fallback: '').toUpperCase();
    return raw == 'DRAFT';
  }

  static String _displayValue(dynamic value) {
    if (value == null || value == false || value == true) return '';
    if (value is Map) {
      return _pickDisplay(Map<dynamic, dynamic>.from(value), const [
        'name',
        'display_name',
        'ref',
        'wo_ref_no',
        'wo_ref',
      ]);
    }
    if (value is List && value.isNotEmpty) {
      if (value.length >= 2) {
        final name = value[1]?.toString().trim() ?? '';
        if (name.isNotEmpty &&
            name.toLowerCase() != 'null' &&
            name.toLowerCase() != 'false') {
          return name;
        }
      }
      return _displayValue(value.first);
    }
    final str = value.toString().trim();
    if (str.isEmpty ||
        str.toLowerCase() == 'null' ||
        str.toLowerCase() == 'false') {
      return '';
    }
    return str;
  }

  static String _pickDisplay(
    Map<dynamic, dynamic> item,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final str = _displayValue(item[key]);
      if (str.isNotEmpty) return str;
    }
    return fallback;
  }

  static String _pick(
    Map<dynamic, dynamic> item,
    List<String> keys, {
    String fallback = '',
  }) {
    return _pickDisplay(item, keys, fallback: fallback);
  }
}
