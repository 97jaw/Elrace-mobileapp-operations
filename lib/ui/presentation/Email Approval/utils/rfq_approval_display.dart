import 'package:el_race/ui/presentation/Email%20Approval/utils/approval_display_helpers.dart';

/// Shared field resolvers for RFQ waiting-approval list cards.
class RfqApprovalDisplay {
  RfqApprovalDisplay._();

  static const _dateKeys = [
    'date',
    'request_date',
    'date_planned',
    'create_date',
    'created_date',
    'write_date',
    'requestDate',
  ];

  static String sequence(Map<dynamic, dynamic> item) {
    return _pick(item, const [
      'name',
      'ref_no',
      'request_no',
      'rfq_no',
    ], fallback: 'RFQ');
  }

  /// Waiting-list / detail work order number (ERP: w_o).
  static String workOrderNumber(Map<dynamic, dynamic> item) {
    return _pickDisplay(item, const [
      'w_o',
      'wo_ref_no',
      'wo_ref',
      'wo_ref_number',
      'work_order_no',
      'work_order_number',
      'wo_no',
      'wo',
      'wo_name',
      'work_order',
    ]);
  }

  static String formattedDate(Map<dynamic, dynamic> item) {
    return ApprovalDisplayHelpers.formatFullDateFromItem(item, _dateKeys);
  }

  static bool shouldHideDraftStatus(Map<dynamic, dynamic> item) {
    final raw = _pick(item, const ['state', 'status'], fallback: '').toUpperCase();
    return raw == 'DRAFT';
  }

  static String _displayValue(dynamic value) {
    if (value == null || value == false || value == true) return '';
    if (value is Map) {
      return _pickDisplay(Map<dynamic, dynamic>.from(value), const [
        'w_o',
        'wo_ref_no',
        'wo_ref',
        'name',
        'display_name',
        'ref',
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
