import 'package:el_race/ui/presentation/Email%20Approval/screens/hr_details_screen.dart';
import 'package:el_race/ui/presentation/Email%20Approval/screens/invoice_details_screen.dart';
import 'package:el_race/ui/presentation/Email%20Approval/screens/pettycash_details_screen.dart';
import 'package:el_race/ui/presentation/Email%20Approval/screens/rfq_details_screen.dart';
import 'package:el_race/ui/presentation/my_actions/data/my_actions_models.dart';
import 'package:el_race/ui/presentation/my_actions/theme/my_actions_module_theme.dart';
import 'package:flutter/material.dart';

abstract final class MyActionsDetailNavigation {
  static void open(
    BuildContext context,
    MyActionsModule module,
    MyActionItem item,
  ) {
    final id = '${item.id}';
    switch (module) {
      case MyActionsModule.hr:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => HrDetailsScreen(
              requestId: id,
              type: item.requestType?.trim().isNotEmpty == true
                  ? item.requestType!.trim().toLowerCase()
                  : 'generic',
              showApprovalActions: false,
            ),
          ),
        );
      case MyActionsModule.rfq:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => RfqDetailsScreen(
              requestId: id,
              type: 'RFQ',
            ),
          ),
        );
      case MyActionsModule.invoice:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => InvoiceDetailsScreen(
              requestId: id,
              type: 'INVOICE',
            ),
          ),
        );
      case MyActionsModule.pettyCash:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PettyCashDetailsScreen(
              requestId: id,
              type: 'PETTY CASH',
            ),
          ),
        );
      case MyActionsModule.signature:
      case MyActionsModule.myRequests:
        break;
    }
  }

  static String? rfqSubtitle(MyActionItem item) {
    final parts = <String>[];
    if (item.project?.trim().isNotEmpty == true) parts.add(item.project!.trim());
    if (item.vendor?.trim().isNotEmpty == true) parts.add(item.vendor!.trim());
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static String? invoiceSubtitle(MyActionItem item) {
    if (item.project?.trim().isNotEmpty == true) return item.project!.trim();
    return item.employeeName.trim().isNotEmpty ? item.employeeName.trim() : null;
  }

  static String? pettyCashSubtitle(MyActionItem item) {
    if (item.amountTotal != null) {
      return '${item.amountTotal!.toStringAsFixed(0)} AED';
    }
    return item.project?.trim().isNotEmpty == true ? item.project!.trim() : null;
  }
}
