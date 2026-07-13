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

  static bool shouldHideDraftStatus(Map<dynamic, dynamic> item) {
    final raw = _pick(item, const ['state', 'status'], fallback: '').toUpperCase();
    return raw == 'DRAFT';
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
