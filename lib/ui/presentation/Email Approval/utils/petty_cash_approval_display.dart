import 'package:el_race/ui/presentation/Email%20Approval/utils/approval_display_helpers.dart';

/// Shared field resolvers for Petty Cash waiting-approval list cards.
class PettyCashApprovalDisplay {
  PettyCashApprovalDisplay._();

  static const _dateKeys = [
    'date',
    'request_date',
    'created_date',
    'create_date',
    'submission_date',
    'write_date',
  ];

  static String sequence(Map<dynamic, dynamic> item) {
    return _pick(item, const [
      'name',
      'request_no',
      'ref_no',
      'reference_no',
      'req_no',
    ]);
  }

  static String holderName(Map<dynamic, dynamic> item) {
    return _pick(item, const [
      'holder_name',
      'pettycash_holder',
      'holder',
      'petty_cash_holder',
      'cash_holder',
      'emp_name',
      'employee_name',
    ]);
  }

  static String formattedDate(Map<dynamic, dynamic> item) {
    return ApprovalDisplayHelpers.formatFullDateFromItem(item, _dateKeys);
  }

  static String amountText(Map<dynamic, dynamic> item) {
    return _pick(item, const [
      'amount_total',
      'total_amount',
      'amount',
      'total',
    ], fallback: '0');
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
